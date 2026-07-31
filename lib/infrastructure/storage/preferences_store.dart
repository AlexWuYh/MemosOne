import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _activeWorkspaceKey = 'active_workspace_id';
  static const _themeModeKey = 'theme_mode';
  static const _accentKey = 'accent_color';
  static const _windowWidthKey = 'window_width';
  static const _windowHeightKey = 'window_height';
  static const _windowXKey = 'window_x';
  static const _windowYKey = 'window_y';

  String? get activeWorkspaceId => _prefs.getString(_activeWorkspaceKey);

  Future<void> setActiveWorkspaceId(String? id) async {
    if (id == null) {
      await _prefs.remove(_activeWorkspaceKey);
    } else {
      await _prefs.setString(_activeWorkspaceKey, id);
    }
  }

  ThemeMode get themeMode {
    final raw = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  Color get accentColor {
    final value = _prefs.getInt(_accentKey);
    if (value == null) return const Color(0xFF4F46E5);
    return Color(value);
  }

  Future<void> setAccentColor(Color color) {
    return _prefs.setInt(_accentKey, color.toARGB32());
  }

  Size? get windowSize {
    final w = _prefs.getDouble(_windowWidthKey);
    final h = _prefs.getDouble(_windowHeightKey);
    if (w == null || h == null) return null;
    return Size(w, h);
  }

  Offset? get windowOffset {
    final x = _prefs.getDouble(_windowXKey);
    final y = _prefs.getDouble(_windowYKey);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Future<void> saveWindow({required Size size, Offset? offset}) async {
    await _prefs.setDouble(_windowWidthKey, size.width);
    await _prefs.setDouble(_windowHeightKey, size.height);
    if (offset != null) {
      await _prefs.setDouble(_windowXKey, offset.dx);
      await _prefs.setDouble(_windowYKey, offset.dy);
    }
  }
}
