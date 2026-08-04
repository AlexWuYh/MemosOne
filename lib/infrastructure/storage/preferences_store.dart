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
  static const _onboardingDoneKey = 'onboarding_done';
  static const _syncOnLaunchKey = 'sync_on_launch';
  static const _syncOnExitKey = 'sync_on_exit';
  static const _syncOnReconnectKey = 'sync_on_reconnect';
  static const _periodicSyncKey = 'periodic_sync';
  static const _syncIntervalMinKey = 'sync_interval_minutes';
  static const _defaultVisibilityKey = 'default_memo_visibility';
  static const _doubleClickEditKey = 'double_click_to_edit';

  String? get activeWorkspaceId => _prefs.getString(_activeWorkspaceKey);

  Future<void> setActiveWorkspaceId(String? id) async {
    if (id == null) {
      await _prefs.remove(_activeWorkspaceKey);
    } else {
      await _prefs.setString(_activeWorkspaceKey, id);
    }
  }

  bool get onboardingDone => _prefs.getBool(_onboardingDoneKey) ?? false;

  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(_onboardingDoneKey, value);

  /// Sync when app becomes ready / resumes (default on).
  bool get syncOnLaunch => _prefs.getBool(_syncOnLaunchKey) ?? true;

  Future<void> setSyncOnLaunch(bool v) => _prefs.setBool(_syncOnLaunchKey, v);

  /// Sync when window closes / app exits (default on).
  bool get syncOnExit => _prefs.getBool(_syncOnExitKey) ?? true;

  Future<void> setSyncOnExit(bool v) => _prefs.setBool(_syncOnExitKey, v);

  /// Sync when network reconnects (default on).
  bool get syncOnReconnect => _prefs.getBool(_syncOnReconnectKey) ?? true;

  Future<void> setSyncOnReconnect(bool v) =>
      _prefs.setBool(_syncOnReconnectKey, v);

  /// Background periodic full sync (default on).
  bool get periodicSyncEnabled => _prefs.getBool(_periodicSyncKey) ?? true;

  Future<void> setPeriodicSyncEnabled(bool v) =>
      _prefs.setBool(_periodicSyncKey, v);

  /// Minutes between full pulls when periodic sync is on (default 15).
  int get syncIntervalMinutes {
    final v = _prefs.getInt(_syncIntervalMinKey);
    if (v == null || v < 1) return 15;
    return v;
  }

  Future<void> setSyncIntervalMinutes(int minutes) =>
      _prefs.setInt(_syncIntervalMinKey, minutes.clamp(1, 24 * 60));

  /// Default visibility for newly created memos (PRIVATE / PROTECTED / PUBLIC).
  String get defaultMemoVisibility =>
      _prefs.getString(_defaultVisibilityKey) ?? 'private';

  Future<void> setDefaultMemoVisibility(String v) =>
      _prefs.setString(_defaultVisibilityKey, v);

  /// Double-click preview content to enter edit mode (web parity).
  bool get doubleClickToEdit => _prefs.getBool(_doubleClickEditKey) ?? true;

  Future<void> setDoubleClickToEdit(bool v) =>
      _prefs.setBool(_doubleClickEditKey, v);

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
    // Warm indigo — closer to notes / Memos calm aesthetic
    if (value == null) return const Color(0xFF5B6CFF);
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
