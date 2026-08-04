import '../entities/workspace.dart';

abstract class WorkspaceRepository {
  Stream<List<Workspace>> watchAll();

  Future<List<Workspace>> list();

  Future<Workspace?> get(String localId);

  Future<Workspace> createLocal({required String name});

  Future<Workspace> createMemos({
    required String name,
    required String serverBaseUrl,
    bool allowInsecureTls = false,
  });

  /// Promote an existing local workspace to a Memos connection (keeps localId + notes).
  Future<Workspace> bindMemosServer({
    required String localId,
    required String serverBaseUrl,
    bool allowInsecureTls = false,
    String? name,
  });

  Future<void> update(Workspace workspace);

  Future<void> delete(String localId, {bool wipeData = false});

  Future<void> markOpened(String localId);
}
