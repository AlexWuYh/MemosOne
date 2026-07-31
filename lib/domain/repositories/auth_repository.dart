import '../entities/workspace.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.username,
    this.userNameResource,
  });

  final String accessToken;
  final String? username;
  final String? userNameResource;
}

abstract class AuthRepository {
  Future<AuthSession> login({
    required Workspace workspace,
    required String username,
    required String password,
  });

  Future<void> logout(Workspace workspace);

  Future<String?> readToken(String workspaceId);

  Future<void> saveToken(String workspaceId, String token);

  Future<AuthSession?> fetchCurrentUser(Workspace workspace);
}
