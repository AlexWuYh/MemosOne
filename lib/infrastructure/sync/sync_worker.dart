import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/sync_service.dart';
import '../database/app_database.dart';
import '../network/memos/memos_api_client.dart';
import '../repositories/memo_repository_impl.dart';
import '../storage/secure_token_store.dart';
import 'conflict_resolver.dart';
import 'sync_queue.dart';

class SyncWorker implements SyncService {
  SyncWorker({
    required AppDatabase db,
    required SecureTokenStore tokens,
    required MemoRepositoryImpl memos,
    Connectivity? connectivity,
  })  : _db = db,
        _tokens = tokens,
        _memos = memos,
        _queue = SyncQueue(db),
        _connectivity = connectivity ?? Connectivity();

  final AppDatabase _db;
  final SecureTokenStore _tokens;
  final MemoRepositoryImpl _memos;
  final SyncQueue _queue;
  final Connectivity _connectivity;
  final ConflictResolver _conflicts = ConflictResolver();

  final _controllers = <String, StreamController<SyncStatusSnapshot>>{};
  final _timers = <String, Timer>{};
  final _running = <String>{};
  final _snapshots = <String, SyncStatusSnapshot>{};
  final _authBlocked = <String>{};

  StreamController<SyncStatusSnapshot> _controllerFor(String workspaceId) {
    // Controllers are closed in dispose().
    // ignore: close_sinks
    return _controllers.putIfAbsent(
      workspaceId,
      // ignore: close_sinks
      () => StreamController<SyncStatusSnapshot>.broadcast(),
    );
  }

  SyncStatusSnapshot _snapshot(String workspaceId) {
    return _snapshots[workspaceId] ?? const SyncStatusSnapshot.idle();
  }

  Future<void> _emit(String workspaceId, SyncStatusSnapshot snap) async {
    final pending = await _queue.countPending(workspaceId);
    final dead = await _queue.countDead(workspaceId);
    final next = snap.copyWith(pendingCount: pending, deadCount: dead);
    _snapshots[workspaceId] = next;
    final c = _controllers[workspaceId];
    if (c != null && !c.isClosed) c.add(next);
  }

  @override
  Stream<SyncStatusSnapshot> watchStatus(String workspaceId) {
    final c = _controllerFor(workspaceId);
    scheduleMicrotask(() async {
      await _emit(workspaceId, _snapshot(workspaceId));
    });
    return c.stream;
  }

  @override
  Future<void> start(Workspace workspace) async {
    if (!workspace.isMemos) return;
    _timers[workspace.localId]?.cancel();
    _timers[workspace.localId] = Timer.periodic(
      const Duration(seconds: AppConstants.syncPollSeconds),
      (_) => unawaited(_cycle(workspace)),
    );
    unawaited(_cycle(workspace));
  }

  @override
  Future<void> stop(String workspaceId) async {
    _timers.remove(workspaceId)?.cancel();
  }

  @override
  Future<void> syncNow(Workspace workspace) async {
    await _cycle(workspace, forcePull: true);
  }

  @override
  Future<void> pullOnly(Workspace workspace) async {
    await _pull(workspace);
  }

  @override
  Future<List<SyncTask>> listDeadTasks(String workspaceId) {
    return _queue.listDead(workspaceId);
  }

  @override
  Future<void> retryDeadTask(String taskId) {
    return _queue.retryDead(taskId);
  }

  Future<void> _cycle(Workspace workspace, {bool forcePull = false}) async {
    if (!workspace.isMemos) return;
    if (_running.contains(workspace.localId)) return;
    if (_authBlocked.contains(workspace.localId)) {
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(
          state: GlobalSyncState.authRequired,
        ),
      );
      return;
    }

    final net = await _connectivity.checkConnectivity();
    final offline = net.every((e) => e == ConnectivityResult.none);
    if (offline) {
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(state: GlobalSyncState.offline),
      );
      return;
    }

    _running.add(workspace.localId);
    await _emit(
      workspace.localId,
      _snapshot(workspace.localId)
          .copyWith(state: GlobalSyncState.syncing, clearError: true),
    );

    try {
      // Push drain
      while (true) {
        final task = await _queue.nextPending(workspace.localId);
        if (task == null) break;
        await _pushOne(workspace, task);
      }
      // Pull
      if (forcePull || true) {
        await _pull(workspace);
      }
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(
          state: GlobalSyncState.idle,
          lastPushAt: DateTime.now(),
          lastPullAt: DateTime.now(),
          clearError: true,
        ),
      );
    } on AuthFailure catch (e) {
      _authBlocked.add(workspace.localId);
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(
          state: GlobalSyncState.authRequired,
          lastError: e.message,
        ),
      );
    } catch (e, st) {
      appLogger.e('sync cycle failed', error: e, stackTrace: st);
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(
          state: GlobalSyncState.error,
          lastError: e.toString(),
        ),
      );
    } finally {
      _running.remove(workspace.localId);
    }
  }

  Future<MemosApiClient> _client(Workspace workspace) async {
    final token = await _tokens.read(workspace.localId);
    if (token == null || token.isEmpty) {
      throw const AuthFailure('Not authenticated');
    }
    return MemosApiClient.forWorkspace(workspace, token: token);
  }

  Future<void> _pushOne(Workspace workspace, SyncTask task) async {
    await _queue.markRunning(task.id);
    await _memos.markSyncing(task.entityLocalId);
    try {
      final client = await _client(workspace);
      final memo = await _memos.getByLocalId(task.entityLocalId);

      switch (task.action) {
        case SyncAction.create:
          if (memo == null) {
            await _queue.complete(task.id);
            return;
          }
          if (memo.serverName != null) {
            // already bound — treat as update
            final remote = await client.updateMemo(
              name: memo.serverName!,
              content: memo.content,
              visibility: memo.visibility,
              pinned: memo.pinned,
              archived: memo.archived,
            );
            await _memos.markCleanAfterPush(
              memo.localId,
              updatedAtServer: remote.updateTime,
            );
            await _queue.complete(task.id);
            return;
          }
          final remote = await client.createMemo(
            content: memo.content,
            visibility: memo.visibility,
          );
          await _memos.bindServerName(memo.localId, remote.name);
          if (memo.pinned || memo.archived) {
            await client.updateMemo(
              name: remote.name,
              content: memo.content,
              visibility: memo.visibility,
              pinned: memo.pinned,
              archived: memo.archived,
            );
          }
          await _queue.complete(task.id);
          break;
        case SyncAction.update:
          if (memo == null) {
            await _queue.complete(task.id);
            return;
          }
          if (memo.serverName == null) {
            final remote = await client.createMemo(
              content: memo.content,
              visibility: memo.visibility,
            );
            await _memos.bindServerName(memo.localId, remote.name);
            await _queue.complete(task.id);
            return;
          }
          final remote = await client.updateMemo(
            name: memo.serverName!,
            content: memo.content,
            visibility: memo.visibility,
            pinned: memo.pinned,
            archived: memo.archived,
          );
          await _memos.markCleanAfterPush(
            memo.localId,
            updatedAtServer: remote.updateTime,
          );
          await _queue.complete(task.id);
          break;
        case SyncAction.delete:
          if (memo?.serverName != null) {
            await client.deleteMemo(memo!.serverName!);
          }
          if (memo != null) {
            await _memos.hardDeleteLocal(memo.localId);
          }
          await _queue.complete(task.id);
          break;
      }
    } on AuthFailure {
      await _queue.fail(
        id: task.id,
        retryCount: task.retryCount,
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)),
        error: 'Unauthorized',
        dead: false,
      );
      rethrow;
    } catch (e) {
      final retry = task.retryCount + 1;
      final dead = retry >= AppConstants.maxSyncRetries;
      await _queue.fail(
        id: task.id,
        retryCount: retry,
        nextAttemptAt: DateTime.now().add(SyncQueue.backoff(retry)),
        error: e.toString(),
        dead: dead,
      );
      await _memos.markError(task.entityLocalId, e.toString());
    }
  }

  Future<void> _pull(Workspace workspace) async {
    final client = await _client(workspace);
    String? pageToken;
    final seen = <String>{};
    do {
      final page = await client.listMemosPage(pageToken: pageToken);
      for (final remote in page.memos) {
        seen.add(remote.name);
        final existing = await (_db.select(_db.memos)
              ..where(
                (t) =>
                    t.workspaceId.equals(workspace.localId) &
                    t.serverName.equals(remote.name),
              ))
            .getSingleOrNull();

        if (existing == null) {
          await _memos.upsertFromRemote(
            workspaceId: workspace.localId,
            serverName: remote.name,
            content: remote.content,
            visibility: remote.visibility,
            pinned: remote.pinned,
            archived: remote.archived,
            createdAtServer: remote.createTime,
            updatedAtServer: remote.updateTime,
          );
          continue;
        }

        final local = await _memos.getByLocalId(existing.localId);
        if (local == null) continue;

        if (local.dirty) {
          final winner = _conflicts.decide(
            local: local,
            remoteUpdatedAt: remote.updateTime,
          );
          if (winner == ConflictWinner.local) {
            // keep local; push will handle
            continue;
          }
          await _memos.applyRemoteOverwriteWithHistory(
            localId: local.localId,
            content: remote.content,
            visibility: remote.visibility,
            pinned: remote.pinned,
            archived: remote.archived,
            updatedAtServer: remote.updateTime,
          );
        } else {
          await _memos.upsertFromRemote(
            workspaceId: workspace.localId,
            serverName: remote.name,
            content: remote.content,
            visibility: remote.visibility,
            pinned: remote.pinned,
            archived: remote.archived,
            createdAtServer: remote.createTime,
            updatedAtServer: remote.updateTime,
          );
        }
      }
      pageToken = page.nextPageToken;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
    } while (pageToken != null);

    // Mark initial sync
    await (_db.update(_db.workspaces)
          ..where((t) => t.localId.equals(workspace.localId)))
        .write(
      WorkspacesCompanion(
        initialSyncCompleted: const Value(true),
        authState: Value(WorkspaceAuthState.ok.name),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _db.into(_db.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            key: 'memo_pull',
            workspaceId: workspace.localId,
            value: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now(),
          ),
        );

    _authBlocked.remove(workspace.localId);
  }

  void clearAuthBlock(String workspaceId) => _authBlocked.remove(workspaceId);

  Future<void> dispose() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }
}
