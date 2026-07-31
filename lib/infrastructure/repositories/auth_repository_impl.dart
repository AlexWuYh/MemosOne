import '../../core/errors/app_failure.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../network/memos/memos_api_client.dart';
import '../storage/secure_token_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._tokens, this._workspaces);

  final SecureTokenStore _tokens;
  final WorkspaceRepository _workspaces;

  @override
  Future<AuthSession> login({
    required Workspace workspace,
    required String username,
    required String password,
  }) async {
    if (workspace.serverBaseUrl == null || workspace.serverBaseUrl!.isEmpty) {
      throw const ValidationFailure('Server URL is required');
    }
    final client = MemosApiClient(
      baseUrl: workspace.serverBaseUrl!,
      allowInsecureTls: workspace.allowInsecureTls,
    );
    final token = await client.login(username: username, password: password);
    await _tokens.write(workspace.localId, token);
    final authed = MemosApiClient(
      baseUrl: workspace.serverBaseUrl!,
      accessToken: token,
      allowInsecureTls: workspace.allowInsecureTls,
    );
    String? displayName = username;
    String? resource;
    try {
      final me = await authed.getCurrentUser();
      displayName = me['username'] as String? ??
          me['name'] as String? ??
          me['displayName'] as String? ??
          username;
      resource = me['name'] as String?;
    } catch (_) {
      // Some servers may not expose /users/me; keep login success.
    }
    await _workspaces.update(
      workspace.copyWith(
        authState: WorkspaceAuthState.ok,
        username: displayName,
        updatedAt: DateTime.now(),
      ),
    );
    return AuthSession(
      accessToken: token,
      username: displayName,
      userNameResource: resource,
    );
  }

  @override
  Future<void> logout(Workspace workspace) async {
    await _tokens.delete(workspace.localId);
    await _workspaces.update(
      workspace.copyWith(
        authState: WorkspaceAuthState.none,
        username: null,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<String?> readToken(String workspaceId) => _tokens.read(workspaceId);

  @override
  Future<void> saveToken(String workspaceId, String token) =>
      _tokens.write(workspaceId, token);

  @override
  Future<AuthSession?> fetchCurrentUser(Workspace workspace) async {
    final token = await _tokens.read(workspace.localId);
    if (token == null || workspace.serverBaseUrl == null) return null;
    final client = MemosApiClient(
      baseUrl: workspace.serverBaseUrl!,
      accessToken: token,
      allowInsecureTls: workspace.allowInsecureTls,
    );
    try {
      final me = await client.getCurrentUser();
      return AuthSession(
        accessToken: token,
        username: me['username'] as String? ?? me['name'] as String?,
        userNameResource: me['name'] as String?,
      );
    } on AuthFailure {
      await _workspaces.update(
        workspace.copyWith(authState: WorkspaceAuthState.needsReauth),
      );
      rethrow;
    }
  }
}
