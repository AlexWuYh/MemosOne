import '../../domain/entities/memo.dart' as domain;
import '../../domain/entities/sync_models.dart' as domain;
import '../../domain/entities/workspace.dart' as domain;
import 'app_database.dart';

domain.Workspace workspaceFromRow(WorkspaceRow row) {
  return domain.Workspace(
    localId: row.localId,
    name: row.name,
    type: domain.WorkspaceType.values.firstWhere(
      (e) => e.name == row.type,
      orElse: () => domain.WorkspaceType.local,
    ),
    serverBaseUrl: row.serverBaseUrl,
    databasePath: row.databasePath,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastOpenedAt: row.lastOpenedAt,
    initialSyncCompleted: row.initialSyncCompleted,
    authState: domain.WorkspaceAuthState.values.firstWhere(
      (e) => e.name == row.authState,
      orElse: () => domain.WorkspaceAuthState.none,
    ),
    serverVersion: row.serverVersion,
    username: row.username,
    allowInsecureTls: row.allowInsecureTls,
  );
}

domain.Memo memoFromRow(MemoRow row, {List<String> tags = const []}) {
  return domain.Memo(
    localId: row.localId,
    workspaceId: row.workspaceId,
    serverName: row.serverName,
    content: row.content,
    visibility: domain.MemoVisibility.values.firstWhere(
      (e) => e.name == row.visibility,
      orElse: () => domain.MemoVisibility.private,
    ),
    pinned: row.pinned,
    archived: row.archived,
    deletedAt: row.deletedAt,
    createdAtLocal: row.createdAtLocal,
    updatedAtLocal: row.updatedAtLocal,
    createdAtServer: row.createdAtServer,
    updatedAtServer: row.updatedAtServer,
    syncStatus: domain.MemoSyncStatus.values.firstWhere(
      (e) => e.name == row.syncStatus,
      orElse: () => domain.MemoSyncStatus.clean,
    ),
    dirty: row.dirty,
    contentHash: row.contentHash,
    lastError: row.lastError,
    version: row.version,
    tags: tags,
  );
}

domain.SyncTask syncTaskFromRow(SyncTaskRow row) {
  return domain.SyncTask(
    id: row.id,
    workspaceId: row.workspaceId,
    entityType: domain.SyncEntityType.values.firstWhere(
      (e) => e.name == row.entityType,
      orElse: () => domain.SyncEntityType.memo,
    ),
    entityLocalId: row.entityLocalId,
    action: domain.SyncAction.values.firstWhere(
      (e) => e.name == row.action,
      orElse: () => domain.SyncAction.update,
    ),
    payloadJson: row.payloadJson,
    status: domain.SyncTaskStatus.values.firstWhere(
      (e) => e.name == row.status,
      orElse: () => domain.SyncTaskStatus.pending,
    ),
    retryCount: row.retryCount,
    nextAttemptAt: row.nextAttemptAt,
    lastError: row.lastError,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

domain.AttachmentItem attachmentFromRow(AttachmentRow row) {
  return domain.AttachmentItem(
    localId: row.localId,
    memoLocalId: row.memoLocalId,
    workspaceId: row.workspaceId,
    serverName: row.serverName,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
    hashSha256: row.hashSha256,
    localPath: row.localPath,
    remoteUrl: row.remoteUrl,
    fileName: row.fileName,
    createdAtLocal: row.createdAtLocal,
    updatedAtLocal: row.updatedAtLocal,
    dirty: row.dirty,
  );
}

domain.MemoHistoryEntry historyFromRow(MemoHistoryRow row) {
  return domain.MemoHistoryEntry(
    localId: row.localId,
    memoLocalId: row.memoLocalId,
    content: row.content,
    capturedAt: row.capturedAt,
    reason: row.reason,
    serverName: row.serverName,
  );
}
