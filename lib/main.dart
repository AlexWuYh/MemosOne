import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'domain/entities/workspace.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/storage/preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final prefStore = PreferencesStore(prefs);

  if (!kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    final size = prefStore.windowSize ?? const Size(1240, 820);
    final offset = prefStore.windowOffset;
    final options = WindowOptions(
      size: size,
      center: offset == null,
      minimumSize: const Size(420, 640),
      title: 'Memos One',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (offset != null) {
        await windowManager.setPosition(offset);
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final db = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const _AppRoot(),
    ),
  );
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> with WindowListener {
  var _exiting = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMoved() => _saveWindow();

  @override
  void onWindowResized() => _saveWindow();

  Future<void> _saveWindow() async {
    final prefs = ref.read(preferencesStoreProvider);
    final size = await windowManager.getSize();
    final offset = await windowManager.getPosition();
    await prefs.saveWindow(size: size, offset: offset);
  }

  @override
  Future<void> onWindowClose() async {
    if (_exiting) return;
    _exiting = true;
    try {
      final prefs = ref.read(syncPrefsProvider);
      if (prefs.syncOnExit) {
        final ws = ref.read(activeWorkspaceProvider);
        if (ws != null &&
            ws.isMemos &&
            ws.authState == WorkspaceAuthState.ok) {
          try {
            await ref.read(syncServiceProvider).syncNow(ws);
          } catch (_) {
            // Don't block exit forever on network failure.
          }
        }
      }
      await _saveWindow();
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MemosOneApp();
  }
}
