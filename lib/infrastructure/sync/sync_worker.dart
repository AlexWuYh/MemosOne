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
import '../storage/secure_token_store.dart';
import 'conflict_resolver.dart';
import 'sync_memo_gateway.dart';
import 'sync_queue.dart';

class SyncWorker implements SyncService {
  SyncWorker({
    required AppDatabase db,
    required SecureTokenStore tokens,
    required SyncMemoGateway memos,
    Connectivity? connectivity,
    SyncQueue? queue,
    this.fullPullIntervalResolver,
    this.periodicSyncEnabledResolver,
  })  : _db = db,
        _tokens = tokens,
        _memos = memos,
        _queue = queue ?? SyncQueue(db),
        _connectivity = connectivity ?? Connectivity();

  final AppDatabase _db;
  final SecureTokenStore _tokens;
  final SyncMemoGateway _memos;
  final SyncQueue _queue;
  final Connectivity _connectivity;
  final ConflictResolver _conflicts = ConflictResolver();

  /// When null, uses [AppConstants.fullPullIntervalMinutes].
  final Duration Function()? fullPullIntervalResolver;

  /// When false, timer still drains push queue but skips scheduled full pulls.
  final bool Function()? periodicSyncEnabledResolver;

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
    // Force drain even if a cycle is already running: wait briefly then run.
    await _cycle(workspace, forcePull: true, forceDrain: true);
  }

  @override
  Future<void> pullOnly(Workspace workspace) async {
    await _pull(workspace, reconcileDeletes: true);
  }

  @override
  Future<List<SyncTask>> listDeadTasks(String workspaceId) async {
    await _queue.pruneDuplicateDead(workspaceId);
    return _queue.listDead(workspaceId);
  }

  @override
  Future<void> retryDeadTask(String taskId) {
    return _queue.retryDead(taskId);
  }

  @override
  Future<void> retryAllDeadTasks(String workspaceId) async {
    await _queue.retryAllDead(workspaceId);
    await _emit(workspaceId, _snapshot(workspaceId));
  }

  @override
  Future<void> clearDeadTasks(String workspaceId) async {
    await _queue.clearDead(workspaceId);
    await _emit(workspaceId, _snapshot(workspaceId));
  }

  @override
  Future<int> pruneDeadTasks(String workspaceId) async {
    final n = await _queue.pruneDuplicateDead(workspaceId);
    await _emit(workspaceId, _snapshot(workspaceId));
    return n;
  }

  /// Exposed for tests: whether a full pull should run.
  Future<bool> shouldFullPull(
    String workspaceId, {
    required bool forcePull,
    DateTime? now,
  }) async {
    if (forcePull) return true;
    final ws = await (_db.select(_db.workspaces)
          ..where((t) => t.localId.equals(workspaceId)))
        .getSingleOrNull();
    if (ws == null) return false;
    if (!ws.initialSyncCompleted) return true;

    final cursor = await (_db.select(_db.syncCursors)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.key.equals('memo_pull'),
          ))
        .getSingleOrNull();
    if (cursor == null) return true;
    final last = DateTime.tryParse(cursor.value);
    if (last == null) return true;
    final clock = now ?? DateTime.now();
    final interval = fullPullIntervalResolver?.call() ??
        const Duration(minutes: AppConstants.fullPullIntervalMinutes);
    return clock.difference(last) >= interval;
  }

  Future<void> _cycle(
    Workspace workspace, {
    bool forcePull = false,
    bool forceDrain = false,
  }) async {
    if (!workspace.isMemos) return;

    // Manual sync should not be dropped when a poll cycle is mid-flight.
    if (_running.contains(workspace.localId)) {
      if (!forceDrain) return;
      for (var i = 0; i < 50; i++) {
        if (!_running.contains(workspace.localId)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_running.contains(workspace.localId)) {
        appLogger.w('syncNow: previous cycle still running, skip');
        return;
      }
    }

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
      // Hygiene: collapse duplicate dead letters before counting / drain.
      await _queue.pruneDuplicateDead(workspace.localId);
      // Recover stuck running tasks always; force drain clears backoff too.
      await _queue.recoverStuckRunning(workspace.localId);
      if (forceDrain) {
        await _queue.clearBackoff(workspace.localId);
        await _memos.requeueOrphanDirty(workspace.localId);
      }

      // Drain queue; after first pass requeue orphans once more (race-safe).
      for (var pass = 0; pass < 2; pass++) {
        while (true) {
          final task = await _queue.nextPending(
            workspace.localId,
            ignoreBackoff: forceDrain,
          );
          if (task == null) break;
          await _pushOne(workspace, task);
        }
        if (pass == 0) {
          final orphans = await _memos.requeueOrphanDirty(workspace.localId);
          if (orphans == 0) break;
        }
      }

      final periodicOk = periodicSyncEnabledResolver?.call() ?? true;
      final doPull = forcePull ||
          (periodicOk &&
              await shouldFullPull(
                workspace.localId,
                forcePull: false,
              ));
      if (doPull) {
        await _pull(workspace, reconcileDeletes: true);
        // Remote-delete may requeue creates — drain again.
        while (true) {
          final task = await _queue.nextPending(
            workspace.localId,
            ignoreBackoff: true,
          );
          if (task == null) break;
          await _pushOne(workspace, task);
        }
      }

      final dead = await _queue.countDead(workspace.localId);
      final pending = await _queue.countPending(workspace.localId);
      await _emit(
        workspace.localId,
        _snapshot(workspace.localId).copyWith(
          state: dead > 0 && pending == 0
              ? GlobalSyncState.error
              : GlobalSyncState.idle,
          lastPushAt: DateTime.now(),
          lastPullAt: doPull
              ? DateTime.now()
              : _snapshot(workspace.localId).lastPullAt,
          lastError: dead > 0 ? 'Dead sync tasks: $dead' : null,
          clearError: dead == 0,
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
      // Snapshot version at push start so concurrent edits keep dirty=true.
      final pushedVersion = memo?.version;

      switch (task.action) {
        case SyncAction.create:
          if (memo == null) {
            await _queue.complete(task.id);
            return;
          }
          if (memo.serverName != null) {
            final remote = await client.updateMemo(
              name: memo.serverName!,
              content: memo.content,
              visibility: memo.visibility,
              pinned: memo.pinned,
              archived: memo.archived,
            );
            // Complete queue first so markClean can see remaining tasks.
            await _queue.complete(task.id);
            await _memos.markCleanAfterPush(
              memo.localId,
              updatedAtServer: remote.updateTime,
              expectedVersion: pushedVersion,
            );
            return;
          }
          final remote = await client.createMemo(
            content: memo.content,
            visibility: memo.visibility,
          );
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
          await _memos.bindServerName(
            memo.localId,
            remote.name,
            expectedVersion: pushedVersion,
          );
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
            await _queue.complete(task.id);
            await _memos.bindServerName(
              memo.localId,
              remote.name,
              expectedVersion: pushedVersion,
            );
            return;
          }
          final remote = await client.updateMemo(
            name: memo.serverName!,
            content: memo.content,
            visibility: memo.visibility,
            pinned: memo.pinned,
            archived: memo.archived,
          );
          await _queue.complete(task.id);
          await _memos.markCleanAfterPush(
            memo.localId,
            updatedAtServer: remote.updateTime,
            expectedVersion: pushedVersion,
          );
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
    } on AuthFailure catch (e) {
      await _queue.fail(
        id: task.id,
        retryCount: task.retryCount,
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)),
        error: e.message,
        dead: false,
        workspaceId: workspace.localId,
        entityLocalId: task.entityLocalId,
      );
      rethrow;
    } catch (e) {
      final retry = task.retryCount + 1;
      final dead = retry >= AppConstants.maxSyncRetries;
      final msg = e is AppFailure ? e.message : e.toString();
      await _queue.fail(
        id: task.id,
        retryCount: retry,
        nextAttemptAt: DateTime.now().add(SyncQueue.backoff(retry)),
        error: msg,
        dead: dead,
        workspaceId: workspace.localId,
        entityLocalId: task.entityLocalId,
      );
      await _memos.markError(task.entityLocalId, msg);
    }
  }

  Future<void> _pull(
    Workspace workspace, {
    required bool reconcileDeletes,
  }) async {
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
            // Leave local; orphan requeue runs after pull completes.
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

    if (reconcileDeletes) {
      await _reconcileRemoteDeletes(workspace.localId, seen);
    }

    // Dirty rows that won LWW (or never got a queue task) need push work.
    await _memos.requeueOrphanDirty(workspace.localId);

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

  /// Local rows bound to server names missing from full remote list.
  Future<void> _reconcileRemoteDeletes(
    String workspaceId,
    Set<String> seenRemoteNames,
  ) async {
    final bound = await _memos.listServerBound(workspaceId);
    for (final local in bound) {
      final name = local.serverName;
      if (name == null || name.isEmpty) continue;
      if (seenRemoteNames.contains(name)) continue;

      if (local.dirty) {
        // Spec: re-create on server rather than drop local edits.
        await _memos.prepareRecreateAfterRemoteDelete(local.localId);
      } else {
        await _memos.hardDeleteLocal(local.localId);
      }
    }
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
