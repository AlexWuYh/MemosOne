import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';

/// Token storage.
///
/// - **macOS (desktop)**: uses SharedPreferences only. Sandboxed ad-hoc builds
///   cannot use Keychain without a development signing certificate
///   (`errSecMissingEntitlement` -34018).
/// - **iOS/Android**: prefers Keychain/Keystore via [FlutterSecureStorage],
///   with SharedPreferences fallback.
class SecureTokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _prefs = prefs,
        _useKeychain = !kIsWeb && !Platform.isMacOS && !Platform.isLinux && !Platform.isWindows;

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;

  /// Desktop builds skip Keychain (entitlement/signing friction).
  final bool _useKeychain;
  bool _keychainBroken = false;

  String _key(String workspaceId) => 'workspace.$workspaceId.accessToken';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> write(String workspaceId, String token) async {
    final key = _key(workspaceId);
    if (_useKeychain && !_keychainBroken) {
      try {
        await _storage.write(key: key, value: token);
      } on PlatformException catch (e) {
        appLogger.w('Keychain write failed (${e.code}): ${e.message}');
        _keychainBroken = true;
      } catch (e) {
        appLogger.w('Secure storage write failed: $e');
        _keychainBroken = true;
      }
    }
    final prefs = await _ensurePrefs();
    await prefs.setString(key, token);
  }

  Future<String?> read(String workspaceId) async {
    final key = _key(workspaceId);
    if (_useKeychain && !_keychainBroken) {
      try {
        final v = await _storage.read(key: key);
        if (v != null && v.isNotEmpty) return v;
      } on PlatformException catch (e) {
        appLogger.w('Keychain read failed (${e.code}): ${e.message}');
        _keychainBroken = true;
      } catch (_) {
        _keychainBroken = true;
      }
    }
    final prefs = await _ensurePrefs();
    return prefs.getString(key);
  }

  Future<void> delete(String workspaceId) async {
    final key = _key(workspaceId);
    if (_useKeychain) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
    final prefs = await _ensurePrefs();
    await prefs.remove(key);
  }
}
