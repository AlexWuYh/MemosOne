import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';

/// Token storage with Keychain primary + SharedPreferences fallback.
///
/// On macOS sandbox, Keychain requires `keychain-access-groups` entitlement.
/// If Keychain returns -34018 (missing entitlement) or other platform errors,
/// we fall back to SharedPreferences so login still works for local desktop use.
class SecureTokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
                synchronizable: false,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _prefs = prefs;

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;
  bool _preferPrefs = false;

  String _key(String workspaceId) => 'workspace.$workspaceId.accessToken';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> write(String workspaceId, String token) async {
    final key = _key(workspaceId);
    if (!_preferPrefs) {
      try {
        await _storage.write(key: key, value: token);
        // Mirror into prefs as backup for migration / reinstall edge cases.
        final prefs = await _ensurePrefs();
        await prefs.setString(key, token);
        return;
      } on PlatformException catch (e) {
        appLogger.w(
          'Keychain write failed (${e.code}): ${e.message}. '
          'Falling back to SharedPreferences.',
        );
        _preferPrefs = true;
      } catch (e) {
        appLogger.w('Secure storage write failed: $e. Using prefs fallback.');
        _preferPrefs = true;
      }
    }
    final prefs = await _ensurePrefs();
    await prefs.setString(key, token);
  }

  Future<String?> read(String workspaceId) async {
    final key = _key(workspaceId);
    if (!_preferPrefs) {
      try {
        final v = await _storage.read(key: key);
        if (v != null && v.isNotEmpty) return v;
      } on PlatformException catch (e) {
        appLogger.w('Keychain read failed (${e.code}): ${e.message}');
        _preferPrefs = true;
      } catch (_) {
        _preferPrefs = true;
      }
    }
    final prefs = await _ensurePrefs();
    return prefs.getString(key);
  }

  Future<void> delete(String workspaceId) async {
    final key = _key(workspaceId);
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // ignore
    }
    final prefs = await _ensurePrefs();
    await prefs.remove(key);
  }
}
