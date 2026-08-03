import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/tag_parser.dart';
import '../../domain/entities/memo.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/memo_repository.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';
import '../sync/sync_memo_gateway.dart';
import '../sync/sync_queue.dart';

class MemoRepositoryImpl implements MemoRepository, SyncMemoGateway {
  MemoRepositoryImpl(this._db, this._queue, {this.workspaceTypeResolver});

  final AppDatabase _db;
  final SyncQueue _queue;
  final Future<WorkspaceType> Function(String workspaceId)?
      workspaceTypeResolver;
  final _uuid = const Uuid();

  String _contentHash(String content) {
    // Stable, non-crypto fingerprint for idempotency diagnostics (A-6 aid).
    return content.hashCode.toUnsigned(32).toRadixString(16);
  }

  Future<bool> _shouldSync(String workspaceId) async {
    if (workspaceTypeResolver != null) {
      final type = await workspaceTypeResolver!(workspaceId);
      return type == WorkspaceType.memos;
    }
    final ws = await (_db.select(_db.workspaces)
          ..where((t) => t.localId.equals(workspaceId)))
        .getSingleOrNull();
    return ws?.type == WorkspaceType.memos.name;
  }

  Future<List<String>> _tagsForMemo(String memoLocalId) async {
    final q = _db.customSelect(
      'SELECT t.name AS name FROM tags t '
      'INNER JOIN memo_tags mt ON mt.tag_local_id = t.local_id '
      'WHERE mt.memo_local_id = ?',
      variables: [Variable.withString(memoLocalId)],
      readsFrom: {_db.tags, _db.memoTags},
    );
    final rows = await q.get();
    return rows.map((r) => r.read<String>('name')).toList()..sort();
  }

  Future<Memo> _loadMemo(String localId) async {
    final row = await (_db.select(_db.memos)
          ..where((t) => t.localId.equals(localId)))
        .getSingle();
    final tags = await _tagsForMemo(localId);
    return memoFromRow(row, tags: tags);
  }

  Future<void> _rebuildTags({
    required String workspaceId,
    required String memoLocalId,
    required String content,
  }) async {
    await (_db.delete(_db.memoTags)
          ..where((t) => t.memoLocalId.equals(memoLocalId)))
        .go();
    final names = parseTags(content);
    for (final name in names) {
      final existing = await (_db.select(_db.tags)
            ..where(
              (t) => t.workspaceId.equals(workspaceId) & t.name.equals(name),
            ))
          .getSingleOrNull();
      final tagId = existing?.localId ?? _uuid.v4();
      if (existing == null) {
        await _db.into(_db.tags).insert(
              TagsCompanion.insert(
                localId: tagId,
                workspaceId: workspaceId,
                name: name,
              ),
            );
      }
      await _db.into(_db.memoTags).insert(
            MemoTagsCompanion.insert(
              memoLocalId: memoLocalId,
              tagLocalId: tagId,
            ),
          );
    }
  }

  Future<void> _upsertFts({
    required String localId,
    required String workspaceId,
    required String content,
  }) async {
    await _db.customStatement(
      'DELETE FROM memo_fts WHERE local_id = ?',
      [localId],
    );
    await _db.customStatement(
      'INSERT INTO memo_fts(local_id, workspace_id, content) VALUES (?, ?, ?)',
      [localId, workspaceId, content],
    );
  }

  Future<void> _deleteFts(String localId) async {
    await _db.customStatement(
      'DELETE FROM memo_fts WHERE local_id = ?',
      [localId],
    );
  }

  Future<void> _snapshotHistory({
    required String memoLocalId,
    required String content,
    required String reason,
    String? serverName,
  }) async {
    await _db.into(_db.memoHistories).insert(
          MemoHistoriesCompanion.insert(
            localId: _uuid.v4(),
            memoLocalId: memoLocalId,
            content: content,
            capturedAt: DateTime.now(),
            reason: reason,
            serverName: Value(serverName),
          ),
        );
    final rows = await (_db.select(_db.memoHistories)
          ..where((t) => t.memoLocalId.equals(memoLocalId))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
        .get();
    if (rows.length > AppConstants.historyLimitPerMemo) {
      for (final old in rows.skip(AppConstants.historyLimitPerMemo)) {
        await (_db.delete(_db.memoHistories)
              ..where((t) => t.localId.equals(old.localId)))
            .go();
      }
    }
  }

  @override
  Stream<List<Memo>> watchAll(
    String workspaceId, {
    MemoQuery query = const MemoQuery(),
  }) {
    return (_db.select(_db.memos)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAtLocal),
          ]))
        .watch()
        .asyncMap((rows) async {
      final filtered = rows.where((r) {
        if (r.deletedAt != null) return false;
        if (query.onlyPinned && !r.pinned) return false;
        if (query.onlyArchived) return r.archived;
        if (!query.includeArchived && !query.onlyArchived && r.archived) {
          return false;
        }
        return true;
      }).toList();

      final result = <Memo>[];
      for (final row in filtered) {
        final tags = await _tagsForMemo(row.localId);
        if (query.tag != null &&
            !tags.contains(query.tag!.toLowerCase())) {
          continue;
        }
        if (query.searchText != null && query.searchText!.trim().isNotEmpty) {
          final q = query.searchText!.toLowerCase();
          if (!row.content.toLowerCase().contains(q) &&
              !tags.any((t) => t.contains(q))) {
            continue;
          }
        }
        result.add(memoFromRow(row, tags: tags));
      }
      return result;
    });
  }

  @override
  Future<Memo?> getByLocalId(String localId) async {
    final row = await (_db.select(_db.memos)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    if (row == null) return null;
    return memoFromRow(row, tags: await _tagsForMemo(localId));
  }

  @override
  Future<Memo> create(String workspaceId, NewMemo input) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final sync = await _shouldSync(workspaceId);
    await _db.into(_db.memos).insert(
          MemosCompanion.insert(
            localId: id,
            workspaceId: workspaceId,
            content: input.content,
            visibility: Value(input.visibility.name),
            pinned: Value(input.pinned),
            createdAtLocal: now,
            updatedAtLocal: now,
            syncStatus: Value(
              sync ? MemoSyncStatus.dirty.name : MemoSyncStatus.clean.name,
            ),
            dirty: Value(sync),
            version: const Value(1),
            contentHash: Value(_contentHash(input.content)),
          ),
        );
    await _rebuildTags(
      workspaceId: workspaceId,
      memoLocalId: id,
      content: input.content,
    );
    await _upsertFts(
      localId: id,
      workspaceId: workspaceId,
      content: input.content,
    );
    if (sync) {
      await _queue.enqueueMemo(
        workspaceId: workspaceId,
        entityLocalId: id,
        action: SyncAction.create,
      );
    }
    return _loadMemo(id);
  }

  @override
  Future<Memo> update(String localId, MemoPatch patch) async {
    final current = await _loadMemo(localId);
    if (patch.content != null && patch.content != current.content) {
      await _snapshotHistory(
        memoLocalId: localId,
        content: current.content,
        reason: 'user_edit',
        serverName: current.serverName,
      );
    }
    final sync = await _shouldSync(current.workspaceId);
    final now = DateTime.now();
    final nextContent = patch.content ?? current.content;
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        content: Value(nextContent),
        visibility: Value((patch.visibility ?? current.visibility).name),
        pinned: Value(patch.pinned ?? current.pinned),
        archived: Value(patch.archived ?? current.archived),
        updatedAtLocal: Value(now),
        version: Value(current.version + 1),
        dirty: Value(sync ? true : current.dirty),
        syncStatus: Value(
          sync ? MemoSyncStatus.dirty.name : current.syncStatus.name,
        ),
        lastError: const Value(null),
        contentHash: Value(_contentHash(nextContent)),
      ),
    );
    await _rebuildTags(
      workspaceId: current.workspaceId,
      memoLocalId: localId,
      content: nextContent,
    );
    await _upsertFts(
      localId: localId,
      workspaceId: current.workspaceId,
      content: nextContent,
    );
    if (sync) {
      final action =
          current.serverName == null ? SyncAction.create : SyncAction.update;
      await _queue.enqueueMemo(
        workspaceId: current.workspaceId,
        entityLocalId: localId,
        action: action,
      );
    }
    return _loadMemo(localId);
  }

  @override
  Future<void> softDelete(String localId) async {
    final current = await _loadMemo(localId);
    final sync = await _shouldSync(current.workspaceId);
    // Never pushed (or local-only): drop row and cancel any pending queue work.
    if (!sync || current.serverName == null) {
      await _queue.cancelAllForEntity(
        workspaceId: current.workspaceId,
        entityLocalId: localId,
      );
      await hardDeleteLocal(localId);
      return;
    }
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        deletedAt: Value(DateTime.now()),
        dirty: const Value(true),
        syncStatus: Value(MemoSyncStatus.dirty.name),
        updatedAtLocal: Value(DateTime.now()),
      ),
    );
    await _deleteFts(localId);
    await _queue.enqueueMemo(
      workspaceId: current.workspaceId,
      entityLocalId: localId,
      action: SyncAction.delete,
    );
  }

  @override
  Future<void> pin(String localId, bool pinned) async {
    await update(localId, MemoPatch(pinned: pinned));
  }

  @override
  Future<void> archive(String localId, bool archived) async {
    await update(localId, MemoPatch(archived: archived));
  }

  @override
  Future<List<Memo>> search(
    String workspaceId,
    String query, {
    MemoQuery filters = const MemoQuery(),
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return watchAll(workspaceId, query: filters).first;
    }
    List<String> ids;
    try {
      final fts = await _db.customSelect(
        'SELECT local_id FROM memo_fts WHERE workspace_id = ? AND memo_fts MATCH ?',
        variables: [
          Variable.withString(workspaceId),
          Variable.withString(_ftsQuery(q)),
        ],
      ).get();
      ids = fts.map((r) => r.read<String>('local_id')).toList();
    } catch (_) {
      ids = const [];
    }

    final all = await (_db.select(_db.memos)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .get();
    final result = <Memo>[];
    for (final row in all) {
      if (row.deletedAt != null) continue;
      if (filters.onlyPinned && !row.pinned) continue;
      if (filters.onlyArchived && !row.archived) continue;
      if (!filters.includeArchived &&
          !filters.onlyArchived &&
          row.archived) {
        continue;
      }
      final tags = await _tagsForMemo(row.localId);
      final match = ids.contains(row.localId) ||
          row.content.toLowerCase().contains(q.toLowerCase()) ||
          tags.any((t) => t.contains(q.toLowerCase()));
      if (!match) continue;
      if (filters.tag != null && !tags.contains(filters.tag!.toLowerCase())) {
        continue;
      }
      result.add(memoFromRow(row, tags: tags));
    }
    result.sort((Memo a, Memo b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAtLocal.compareTo(a.updatedAtLocal);
    });
    return result;
  }

  String _ftsQuery(String raw) {
    final parts = raw
        .split(RegExp(r'\s+'))
        .map((e) => e.replaceAll(RegExp(r'[^\w\u4e00-\u9fff-]'), ''))
        .where((e) => e.isNotEmpty)
        .map((e) => '"$e"*')
        .toList();
    return parts.isEmpty ? '"$raw"' : parts.join(' ');
  }

  @override
  Future<List<MemoHistoryEntry>> history(String memoLocalId) async {
    final rows = await (_db.select(_db.memoHistories)
          ..where((t) => t.memoLocalId.equals(memoLocalId))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)]))
        .get();
    return rows.map(historyFromRow).toList();
  }

  @override
  Future<Memo> restoreFromHistory(String historyLocalId) async {
    final h = await (_db.select(_db.memoHistories)
          ..where((t) => t.localId.equals(historyLocalId)))
        .getSingle();
    return update(h.memoLocalId, MemoPatch(content: h.content));
  }

  @override
  Future<List<AttachmentItem>> listAttachments(String memoLocalId) async {
    final rows = await (_db.select(_db.attachments)
          ..where((t) => t.memoLocalId.equals(memoLocalId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtLocal)]))
        .get();
    return rows.map(attachmentFromRow).toList();
  }

  @override
  Future<AttachmentItem> addLocalAttachment({
    required String memoLocalId,
    required String workspaceId,
    required String localPath,
    required String mimeType,
    required int sizeBytes,
    String? fileName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final support = await getApplicationSupportDirectory();
    final destDir = Directory(
      p.join(support.path, 'attachments', workspaceId, memoLocalId),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final ext = p.extension(localPath);
    final destPath = p.join(destDir.path, '$id$ext');
    await File(localPath).copy(destPath);
    await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            localId: id,
            memoLocalId: memoLocalId,
            workspaceId: workspaceId,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            localPath: Value(destPath),
            fileName: Value(fileName ?? p.basename(localPath)),
            createdAtLocal: now,
            updatedAtLocal: now,
            dirty: const Value(true),
          ),
        );
    final row = await (_db.select(_db.attachments)
          ..where((t) => t.localId.equals(id)))
        .getSingle();
    return attachmentFromRow(row);
  }

  @override
  Future<void> removeAttachment(String attachmentLocalId) async {
    final row = await (_db.select(_db.attachments)
          ..where((t) => t.localId.equals(attachmentLocalId)))
        .getSingleOrNull();
    if (row?.localPath != null) {
      final f = File(row!.localPath!);
      if (await f.exists()) await f.delete();
    }
    await (_db.delete(_db.attachments)
          ..where((t) => t.localId.equals(attachmentLocalId)))
        .go();
  }

  /// Apply remote memo during pull (used by SyncWorker).
  @override
  Future<void> upsertFromRemote({
    required String workspaceId,
    required String serverName,
    required String content,
    required MemoVisibility visibility,
    required bool pinned,
    required bool archived,
    DateTime? createdAtServer,
    DateTime? updatedAtServer,
  }) async {
    final existing = await (_db.select(_db.memos)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.serverName.equals(serverName),
          ))
        .getSingleOrNull();

    if (existing != null) {
      if (existing.dirty) {
        // Conflict handled by caller generally; if dirty keep local.
        return;
      }
      await (_db.update(_db.memos)
            ..where((t) => t.localId.equals(existing.localId)))
          .write(
        MemosCompanion(
          content: Value(content),
          visibility: Value(visibility.name),
          pinned: Value(pinned),
          archived: Value(archived),
          updatedAtLocal: Value(updatedAtServer ?? DateTime.now()),
          createdAtServer: Value(createdAtServer),
          updatedAtServer: Value(updatedAtServer),
          syncStatus: Value(MemoSyncStatus.clean.name),
          dirty: const Value(false),
          deletedAt: const Value(null),
        ),
      );
      await _rebuildTags(
        workspaceId: workspaceId,
        memoLocalId: existing.localId,
        content: content,
      );
      await _upsertFts(
        localId: existing.localId,
        workspaceId: workspaceId,
        content: content,
      );
      return;
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.memos).insert(
          MemosCompanion.insert(
            localId: id,
            workspaceId: workspaceId,
            serverName: Value(serverName),
            content: content,
            visibility: Value(visibility.name),
            pinned: Value(pinned),
            archived: Value(archived),
            createdAtLocal: createdAtServer ?? now,
            updatedAtLocal: updatedAtServer ?? now,
            createdAtServer: Value(createdAtServer),
            updatedAtServer: Value(updatedAtServer),
            syncStatus: Value(MemoSyncStatus.clean.name),
            dirty: const Value(false),
          ),
        );
    await _rebuildTags(
      workspaceId: workspaceId,
      memoLocalId: id,
      content: content,
    );
    await _upsertFts(
      localId: id,
      workspaceId: workspaceId,
      content: content,
    );
  }

  @override
  Future<void> bindServerName(String localId, String serverName) async {
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        serverName: Value(serverName),
        dirty: const Value(false),
        syncStatus: Value(MemoSyncStatus.clean.name),
        lastError: const Value(null),
        updatedAtServer: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markCleanAfterPush(
    String localId, {
    DateTime? updatedAtServer,
  }) async {
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        dirty: const Value(false),
        syncStatus: Value(MemoSyncStatus.clean.name),
        lastError: const Value(null),
        updatedAtServer: Value(updatedAtServer ?? DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markSyncing(String localId) async {
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(syncStatus: Value(MemoSyncStatus.syncing.name)),
    );
  }

  @override
  Future<void> markError(String localId, String error) async {
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        syncStatus: Value(MemoSyncStatus.error.name),
        lastError: Value(error),
      ),
    );
  }

  @override
  Future<void> hardDeleteLocal(String localId) async {
    await (_db.delete(_db.memoTags)
          ..where((t) => t.memoLocalId.equals(localId)))
        .go();
    await (_db.delete(_db.memos)..where((t) => t.localId.equals(localId))).go();
    await _deleteFts(localId);
  }

  @override
  Future<List<Memo>> listServerBound(String workspaceId) async {
    final rows = await (_db.select(_db.memos)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.serverName.isNotNull() &
                t.deletedAt.isNull(),
          ))
        .get();
    final result = <Memo>[];
    for (final row in rows) {
      result.add(memoFromRow(row, tags: await _tagsForMemo(row.localId)));
    }
    return result;
  }

  @override
  Future<void> prepareRecreateAfterRemoteDelete(String localId) async {
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        serverName: const Value(null),
        dirty: const Value(true),
        syncStatus: Value(MemoSyncStatus.dirty.name),
        updatedAtLocal: Value(DateTime.now()),
        updatedAtServer: const Value(null),
      ),
    );
    final memo = await getByLocalId(localId);
    if (memo == null) return;
    await _queue.enqueueMemo(
      workspaceId: memo.workspaceId,
      entityLocalId: localId,
      action: SyncAction.create,
    );
  }

  @override
  Future<void> applyRemoteOverwriteWithHistory({
    required String localId,
    required String content,
    required MemoVisibility visibility,
    required bool pinned,
    required bool archived,
    DateTime? updatedAtServer,
  }) async {
    final current = await _loadMemo(localId);
    await _snapshotHistory(
      memoLocalId: localId,
      content: current.content,
      reason: 'lww_lost',
      serverName: current.serverName,
    );
    await (_db.update(_db.memos)..where((t) => t.localId.equals(localId)))
        .write(
      MemosCompanion(
        content: Value(content),
        visibility: Value(visibility.name),
        pinned: Value(pinned),
        archived: Value(archived),
        dirty: const Value(false),
        syncStatus: Value(MemoSyncStatus.clean.name),
        updatedAtLocal: Value(updatedAtServer ?? DateTime.now()),
        updatedAtServer: Value(updatedAtServer),
      ),
    );
    await _rebuildTags(
      workspaceId: current.workspaceId,
      memoLocalId: localId,
      content: content,
    );
    await _upsertFts(
      localId: localId,
      workspaceId: current.workspaceId,
      content: content,
    );
  }
}
