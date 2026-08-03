import '../../domain/entities/memo.dart';

/// Port used by [SyncWorker] so it does not depend on the full repository surface.
abstract interface class SyncMemoGateway {
  Future<Memo?> getByLocalId(String localId);

  Future<void> markSyncing(String localId);

  Future<void> markError(String localId, String error);

  Future<void> markCleanAfterPush(String localId, {DateTime? updatedAtServer});

  Future<void> bindServerName(String localId, String serverName);

  Future<void> hardDeleteLocal(String localId);

  Future<void> upsertFromRemote({
    required String workspaceId,
    required String serverName,
    required String content,
    required MemoVisibility visibility,
    required bool pinned,
    required bool archived,
    DateTime? createdAtServer,
    DateTime? updatedAtServer,
  });

  Future<void> applyRemoteOverwriteWithHistory({
    required String localId,
    required String content,
    required MemoVisibility visibility,
    required bool pinned,
    required bool archived,
    DateTime? updatedAtServer,
  });

  /// Memos that already have a server resource name (candidates for remote-delete).
  Future<List<Memo>> listServerBound(String workspaceId);

  /// Remote gone + local dirty → clear server binding and re-queue create.
  Future<void> prepareRecreateAfterRemoteDelete(String localId);
}
