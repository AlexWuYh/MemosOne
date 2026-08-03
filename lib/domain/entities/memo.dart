import 'package:equatable/equatable.dart';

enum MemoVisibility { private, protected, public }

enum MemoSyncStatus { clean, dirty, syncing, error }

class Memo extends Equatable {
  const Memo({
    required this.localId,
    required this.workspaceId,
    required this.content,
    required this.visibility,
    required this.pinned,
    required this.archived,
    required this.createdAtLocal,
    required this.updatedAtLocal,
    required this.syncStatus,
    required this.dirty,
    required this.version,
    this.serverName,
    this.deletedAt,
    this.createdAtServer,
    this.updatedAtServer,
    this.contentHash,
    this.lastError,
    this.tags = const [],
  });

  final String localId;
  final String workspaceId;
  final String? serverName;
  final String content;
  final MemoVisibility visibility;
  final bool pinned;
  final bool archived;
  final DateTime? deletedAt;
  final DateTime createdAtLocal;
  final DateTime updatedAtLocal;
  final DateTime? createdAtServer;
  final DateTime? updatedAtServer;
  final MemoSyncStatus syncStatus;
  final bool dirty;
  final String? contentHash;
  final String? lastError;
  final int version;
  final List<String> tags;

  bool get isDeleted => deletedAt != null;

  String get snippet {
    final line = content
        .replaceAll(RegExp(r'[#>*_`\[\]!]'), ' ')
        .split('\n')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => 'Empty memo');
    return line.length > 120 ? '${line.substring(0, 120)}…' : line;
  }

  Memo copyWith({
    String? content,
    MemoVisibility? visibility,
    bool? pinned,
    bool? archived,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAtLocal,
    DateTime? createdAtServer,
    DateTime? updatedAtServer,
    String? serverName,
    MemoSyncStatus? syncStatus,
    bool? dirty,
    String? contentHash,
    String? lastError,
    bool clearLastError = false,
    int? version,
    List<String>? tags,
  }) {
    return Memo(
      localId: localId,
      workspaceId: workspaceId,
      serverName: serverName ?? this.serverName,
      content: content ?? this.content,
      visibility: visibility ?? this.visibility,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAtLocal: createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      createdAtServer: createdAtServer ?? this.createdAtServer,
      updatedAtServer: updatedAtServer ?? this.updatedAtServer,
      syncStatus: syncStatus ?? this.syncStatus,
      dirty: dirty ?? this.dirty,
      contentHash: contentHash ?? this.contentHash,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      version: version ?? this.version,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        localId,
        workspaceId,
        serverName,
        content,
        visibility,
        pinned,
        archived,
        deletedAt,
        syncStatus,
        dirty,
        version,
        tags,
      ];
}

class NewMemo {
  const NewMemo({
    required this.content,
    this.visibility = MemoVisibility.private,
    this.pinned = false,
  });

  final String content;
  final MemoVisibility visibility;
  final bool pinned;
}

class MemoPatch {
  const MemoPatch({
    this.content,
    this.visibility,
    this.pinned,
    this.archived,
  });

  final String? content;
  final MemoVisibility? visibility;
  final bool? pinned;
  final bool? archived;
}

class MemoQuery {
  const MemoQuery({
    this.includeArchived = false,
    this.onlyPinned = false,
    this.onlyArchived = false,
    this.onlyPublic = false,
    this.tag,
    this.searchText,
    this.day,
  });

  final bool includeArchived;
  final bool onlyPinned;
  final bool onlyArchived;
  final bool onlyPublic;
  final String? tag;
  final String? searchText;

  /// Filter by local calendar day of [Memo.updatedAtLocal] (date only).
  final DateTime? day;

  MemoQuery copyWith({
    bool? includeArchived,
    bool? onlyPinned,
    bool? onlyArchived,
    bool? onlyPublic,
    String? tag,
    String? searchText,
    DateTime? day,
    bool clearDay = false,
    bool clearTag = false,
    bool clearSearch = false,
  }) {
    return MemoQuery(
      includeArchived: includeArchived ?? this.includeArchived,
      onlyPinned: onlyPinned ?? this.onlyPinned,
      onlyArchived: onlyArchived ?? this.onlyArchived,
      onlyPublic: onlyPublic ?? this.onlyPublic,
      tag: clearTag ? null : (tag ?? this.tag),
      searchText: clearSearch ? null : (searchText ?? this.searchText),
      day: clearDay ? null : (day ?? this.day),
    );
  }
}

/// Build a public explore URL for a memo on a Memos instance.
String memosPublicUrl(String serverBaseUrl, String? serverName) {
  final base = serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
  if (serverName == null || serverName.isEmpty) return base;
  final id = serverName.contains('/')
      ? serverName.split('/').last
      : serverName;
  return '$base/m/$id';
}

class MemoHistoryEntry {
  const MemoHistoryEntry({
    required this.localId,
    required this.memoLocalId,
    required this.content,
    required this.capturedAt,
    required this.reason,
    this.serverName,
  });

  final String localId;
  final String memoLocalId;
  final String content;
  final DateTime capturedAt;
  final String reason;
  final String? serverName;
}
