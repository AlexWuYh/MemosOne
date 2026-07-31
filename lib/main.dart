import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/storage/preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final prefStore = PreferencesStore(prefs);

  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    final size = prefStore.windowSize ?? const Size(1200, 800);
    final offset = prefStore.windowOffset;
    final options = WindowOptions(
      size: size,
      center: offset == null,
      minimumSize: const Size(400, 600),
      title: 'Memos One',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (offset != null) {
        await windowManager.setPosition(offset);
      }
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(_WindowPersistence(prefStore));
  }

  final db = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const MemosOneApp(),
    ),
  );
}

class _WindowPersistence with WindowListener {
  _WindowPersistence(this._prefs);

  final PreferencesStore _prefs;

  @override
  void onWindowMoved() => _save();

  @override
  void onWindowResized() => _save();

  Future<void> _save() async {
    final size = await windowManager.getSize();
    final offset = await windowManager.getPosition();
    await _prefs.saveWindow(size: size, offset: offset);
  }
}
