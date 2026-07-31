import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  String _key(String workspaceId) => 'workspace.$workspaceId.accessToken';

  Future<void> write(String workspaceId, String token) {
    return _storage.write(key: _key(workspaceId), value: token);
  }

  Future<String?> read(String workspaceId) {
    return _storage.read(key: _key(workspaceId));
  }

  Future<void> delete(String workspaceId) {
    return _storage.delete(key: _key(workspaceId));
  }
}
