import 'package:equatable/equatable.dart';

enum WorkspaceType { local, memos, cloud }

enum WorkspaceAuthState { none, ok, needsReauth }

class Workspace extends Equatable {
  const Workspace({
    required this.localId,
    required this.name,
    required this.type,
    required this.databasePath,
    required this.createdAt,
    required this.updatedAt,
    this.serverBaseUrl,
    this.lastOpenedAt,
    this.initialSyncCompleted = false,
    this.authState = WorkspaceAuthState.none,
    this.serverVersion,
    this.username,
    this.allowInsecureTls = false,
  });

  final String localId;
  final String name;
  final WorkspaceType type;
  final String? serverBaseUrl;
  final String databasePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final bool initialSyncCompleted;
  final WorkspaceAuthState authState;
  final String? serverVersion;
  final String? username;
  final bool allowInsecureTls;

  bool get isMemos => type == WorkspaceType.memos;
  bool get isLocal => type == WorkspaceType.local;

  Workspace copyWith({
    String? name,
    String? serverBaseUrl,
    DateTime? lastOpenedAt,
    bool? initialSyncCompleted,
    WorkspaceAuthState? authState,
    String? serverVersion,
    String? username,
    bool? allowInsecureTls,
    DateTime? updatedAt,
  }) {
    return Workspace(
      localId: localId,
      name: name ?? this.name,
      type: type,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
      databasePath: databasePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      initialSyncCompleted: initialSyncCompleted ?? this.initialSyncCompleted,
      authState: authState ?? this.authState,
      serverVersion: serverVersion ?? this.serverVersion,
      username: username ?? this.username,
      allowInsecureTls: allowInsecureTls ?? this.allowInsecureTls,
    );
  }

  @override
  List<Object?> get props => [
        localId,
        name,
        type,
        serverBaseUrl,
        databasePath,
        initialSyncCompleted,
        authState,
        username,
        allowInsecureTls,
      ];
}
