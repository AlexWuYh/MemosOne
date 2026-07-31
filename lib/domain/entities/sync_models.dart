import 'package:equatable/equatable.dart';

enum SyncEntityType { memo, attachment }

enum SyncAction { create, update, delete }

enum SyncTaskStatus { pending, running, failed, dead }

enum GlobalSyncState { idle, syncing, offline, authRequired, error }

class SyncTask extends Equatable {
  const SyncTask({
    required this.id,
    required this.workspaceId,
    required this.entityType,
    required this.entityLocalId,
    required this.action,
    required this.status,
    required this.retryCount,
    required this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
    this.payloadJson,
    this.lastError,
  });

  final String id;
  final String workspaceId;
  final SyncEntityType entityType;
  final String entityLocalId;
  final SyncAction action;
  final String? payloadJson;
  final SyncTaskStatus status;
  final int retryCount;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, status, action, entityLocalId, retryCount];
}

class SyncStatusSnapshot extends Equatable {
  const SyncStatusSnapshot({
    required this.state,
    required this.pendingCount,
    required this.deadCount,
    this.lastPullAt,
    this.lastPushAt,
    this.lastError,
  });

  const SyncStatusSnapshot.idle()
      : state = GlobalSyncState.idle,
        pendingCount = 0,
        deadCount = 0,
        lastPullAt = null,
        lastPushAt = null,
        lastError = null;

  final GlobalSyncState state;
  final int pendingCount;
  final int deadCount;
  final DateTime? lastPullAt;
  final DateTime? lastPushAt;
  final String? lastError;

  SyncStatusSnapshot copyWith({
    GlobalSyncState? state,
    int? pendingCount,
    int? deadCount,
    DateTime? lastPullAt,
    DateTime? lastPushAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncStatusSnapshot(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      deadCount: deadCount ?? this.deadCount,
      lastPullAt: lastPullAt ?? this.lastPullAt,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props =>
      [state, pendingCount, deadCount, lastPullAt, lastPushAt, lastError];
}

class AttachmentItem extends Equatable {
  const AttachmentItem({
    required this.localId,
    required this.memoLocalId,
    required this.workspaceId,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAtLocal,
    required this.updatedAtLocal,
    required this.dirty,
    this.serverName,
    this.hashSha256,
    this.localPath,
    this.remoteUrl,
    this.fileName,
  });

  final String localId;
  final String memoLocalId;
  final String workspaceId;
  final String? serverName;
  final String mimeType;
  final int sizeBytes;
  final String? hashSha256;
  final String? localPath;
  final String? remoteUrl;
  final String? fileName;
  final DateTime createdAtLocal;
  final DateTime updatedAtLocal;
  final bool dirty;

  @override
  List<Object?> get props => [localId, memoLocalId, localPath, remoteUrl];
}
