import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';
import '../storage/secure_token_store.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  WorkspaceRepositoryImpl(this._db, this._tokens);

  final AppDatabase _db;
  final SecureTokenStore _tokens;
  final _uuid = const Uuid();

  @override
  Stream<List<Workspace>> watchAll() {
    return (_db.select(_db.workspaces)
          ..orderBy([(t) => OrderingTerm.desc(t.lastOpenedAt)]))
        .watch()
        .map((rows) => rows.map(workspaceFromRow).toList());
  }

  @override
  Future<List<Workspace>> list() async {
    final rows = await _db.select(_db.workspaces).get();
    return rows.map(workspaceFromRow).toList();
  }

  @override
  Future<Workspace?> get(String localId) async {
    final row = await (_db.select(_db.workspaces)
          ..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
    return row == null ? null : workspaceFromRow(row);
  }

  @override
  Future<Workspace> createLocal({required String name}) async {
    return _create(
      name: name,
      type: WorkspaceType.local,
    );
  }

  @override
  Future<Workspace> createMemos({
    required String name,
    required String serverBaseUrl,
    bool allowInsecureTls = false,
  }) {
    return _create(
      name: name,
      type: WorkspaceType.memos,
      serverBaseUrl: serverBaseUrl.trim(),
      allowInsecureTls: allowInsecureTls,
    );
  }

  Future<Workspace> _create({
    required String name,
    required WorkspaceType type,
    String? serverBaseUrl,
    bool allowInsecureTls = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final support = await getApplicationSupportDirectory();
    final dbPath = p.join(support.path, 'workspaces', id, 'notes.sqlite');
    await _db.into(_db.workspaces).insert(
          WorkspacesCompanion.insert(
            localId: id,
            name: name.trim().isEmpty ? 'Workspace' : name.trim(),
            type: type.name,
            serverBaseUrl: Value(serverBaseUrl),
            databasePath: dbPath,
            createdAt: now,
            updatedAt: now,
            lastOpenedAt: Value(now),
            allowInsecureTls: Value(allowInsecureTls),
          ),
        );
    final created = await get(id);
    return created!;
  }

  @override
  Future<void> update(Workspace workspace) async {
    await (_db.update(_db.workspaces)
          ..where((t) => t.localId.equals(workspace.localId)))
        .write(
      WorkspacesCompanion(
        name: Value(workspace.name),
        serverBaseUrl: Value(workspace.serverBaseUrl),
        updatedAt: Value(DateTime.now()),
        lastOpenedAt: Value(workspace.lastOpenedAt),
        initialSyncCompleted: Value(workspace.initialSyncCompleted),
        authState: Value(workspace.authState.name),
        serverVersion: Value(workspace.serverVersion),
        username: Value(workspace.username),
        allowInsecureTls: Value(workspace.allowInsecureTls),
      ),
    );
  }

  @override
  Future<void> delete(String localId, {bool wipeData = false}) async {
    await (_db.delete(_db.memos)..where((t) => t.workspaceId.equals(localId)))
        .go();
    await (_db.delete(_db.tags)..where((t) => t.workspaceId.equals(localId)))
        .go();
    await (_db.delete(_db.syncTasks)
          ..where((t) => t.workspaceId.equals(localId)))
        .go();
    await (_db.delete(_db.attachments)
          ..where((t) => t.workspaceId.equals(localId)))
        .go();
    await (_db.delete(_db.workspaces)..where((t) => t.localId.equals(localId)))
        .go();
    await _tokens.delete(localId);
  }

  @override
  Future<void> markOpened(String localId) async {
    await (_db.update(_db.workspaces)..where((t) => t.localId.equals(localId)))
        .write(
      WorkspacesCompanion(
        lastOpenedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
