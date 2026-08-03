import '../../domain/entities/memo.dart';

/// Port used by [SyncWorker] so it does not depend on the full repository surface.
abstract interface class SyncMemoGateway {
  Future<Memo?> getByLocalId(String localId);

  Future<void> markSyncing(String localId);

  Future<void> markError(String localId, String error);

  /// Marks clean only when [expectedVersion] still matches (or is null).
  /// Returns false if local advanced during push (stays dirty / re-queued).
  Future<bool> markCleanAfterPush(
    String localId, {
    DateTime? updatedAtServer,
    int? expectedVersion,
  });

  Future<void> bindServerName(
    String localId,
    String serverName, {
    int? expectedVersion,
  });

  /// Dirty memos with no open queue task — re-enqueue so "立即同步" can drain.
  Future<int> requeueOrphanDirty(String workspaceId);

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
