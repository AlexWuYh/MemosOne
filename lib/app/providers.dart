import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/memo.dart';
import '../domain/entities/sync_models.dart';
import '../domain/entities/workspace.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/memo_repository.dart';
import '../domain/repositories/sync_service.dart';
import '../domain/repositories/workspace_repository.dart';
import '../infrastructure/database/app_database.dart';
import '../infrastructure/repositories/auth_repository_impl.dart';
import '../infrastructure/repositories/memo_repository_impl.dart';
import '../infrastructure/repositories/workspace_repository_impl.dart';
import '../infrastructure/storage/preferences_store.dart';
import '../infrastructure/storage/secure_token_store.dart';
import '../infrastructure/sync/sync_queue.dart';
import '../infrastructure/sync/sync_worker.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final preferencesStoreProvider = Provider<PreferencesStore>((ref) {
  return PreferencesStore(ref.watch(sharedPreferencesProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden in main');
});

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore();
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(secureTokenStoreProvider),
  );
});

final syncQueueProvider = Provider<SyncQueue>((ref) {
  return SyncQueue(ref.watch(appDatabaseProvider));
});

final memoRepositoryImplProvider = Provider<MemoRepositoryImpl>((ref) {
  return MemoRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueProvider),
  );
});

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return ref.watch(memoRepositoryImplProvider);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(secureTokenStoreProvider),
    ref.watch(workspaceRepositoryProvider),
  );
});

final syncPrefsProvider =
    StateNotifierProvider<SyncPrefsController, SyncPrefs>((ref) {
  return SyncPrefsController(ref.watch(preferencesStoreProvider));
});

class SyncPrefs {
  const SyncPrefs({
    required this.syncOnLaunch,
    required this.syncOnExit,
    required this.syncOnReconnect,
    required this.periodicSyncEnabled,
    required this.syncIntervalMinutes,
  });

  final bool syncOnLaunch;
  final bool syncOnExit;
  final bool syncOnReconnect;
  final bool periodicSyncEnabled;
  final int syncIntervalMinutes;
}

class SyncPrefsController extends StateNotifier<SyncPrefs> {
  SyncPrefsController(this._prefs)
      : super(
          SyncPrefs(
            syncOnLaunch: _prefs.syncOnLaunch,
            syncOnExit: _prefs.syncOnExit,
            syncOnReconnect: _prefs.syncOnReconnect,
            periodicSyncEnabled: _prefs.periodicSyncEnabled,
            syncIntervalMinutes: _prefs.syncIntervalMinutes,
          ),
        );

  final PreferencesStore _prefs;

  Future<void> setSyncOnLaunch(bool v) async {
    await _prefs.setSyncOnLaunch(v);
    state = SyncPrefs(
      syncOnLaunch: v,
      syncOnExit: state.syncOnExit,
      syncOnReconnect: state.syncOnReconnect,
      periodicSyncEnabled: state.periodicSyncEnabled,
      syncIntervalMinutes: state.syncIntervalMinutes,
    );
  }

  Future<void> setSyncOnExit(bool v) async {
    await _prefs.setSyncOnExit(v);
    state = SyncPrefs(
      syncOnLaunch: state.syncOnLaunch,
      syncOnExit: v,
      syncOnReconnect: state.syncOnReconnect,
      periodicSyncEnabled: state.periodicSyncEnabled,
      syncIntervalMinutes: state.syncIntervalMinutes,
    );
  }

  Future<void> setSyncOnReconnect(bool v) async {
    await _prefs.setSyncOnReconnect(v);
    state = SyncPrefs(
      syncOnLaunch: state.syncOnLaunch,
      syncOnExit: state.syncOnExit,
      syncOnReconnect: v,
      periodicSyncEnabled: state.periodicSyncEnabled,
      syncIntervalMinutes: state.syncIntervalMinutes,
    );
  }

  Future<void> setPeriodicSyncEnabled(bool v) async {
    await _prefs.setPeriodicSyncEnabled(v);
    state = SyncPrefs(
      syncOnLaunch: state.syncOnLaunch,
      syncOnExit: state.syncOnExit,
      syncOnReconnect: state.syncOnReconnect,
      periodicSyncEnabled: v,
      syncIntervalMinutes: state.syncIntervalMinutes,
    );
  }

  Future<void> setSyncIntervalMinutes(int minutes) async {
    await _prefs.setSyncIntervalMinutes(minutes);
    state = SyncPrefs(
      syncOnLaunch: state.syncOnLaunch,
      syncOnExit: state.syncOnExit,
      syncOnReconnect: state.syncOnReconnect,
      periodicSyncEnabled: state.periodicSyncEnabled,
      syncIntervalMinutes: minutes,
    );
  }
}

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final prefs = ref.watch(preferencesStoreProvider);
  final worker = SyncWorker(
    db: ref.watch(appDatabaseProvider),
    tokens: ref.watch(secureTokenStoreProvider),
    memos: ref.watch(memoRepositoryImplProvider),
    fullPullIntervalResolver: () =>
        Duration(minutes: prefs.syncIntervalMinutes),
    periodicSyncEnabledResolver: () => prefs.periodicSyncEnabled,
  );
  ref.onDispose(worker.dispose);
  return worker;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return ref.watch(syncWorkerProvider);
});

/// Starts connectivity listener for auto-sync on reconnect.
final connectivitySyncBootstrapProvider = Provider<void>((ref) {
  final sub = Connectivity().onConnectivityChanged.listen((results) async {
    final offline = results.every((e) => e == ConnectivityResult.none);
    if (offline) return;
    final prefs = ref.read(syncPrefsProvider);
    if (!prefs.syncOnReconnect) return;
    final ws = ref.read(activeWorkspaceProvider);
    if (ws == null || !ws.isMemos) return;
    if (ws.authState != WorkspaceAuthState.ok) return;
    await ref.read(syncServiceProvider).syncNow(ws);
  });
  ref.onDispose(sub.cancel);
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(preferencesStoreProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_prefs.themeMode);

  final PreferencesStore _prefs;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode);
  }
}

final accentColorProvider =
    StateNotifierProvider<AccentColorController, Color>((ref) {
  return AccentColorController(ref.watch(preferencesStoreProvider));
});

class AccentColorController extends StateNotifier<Color> {
  AccentColorController(this._prefs) : super(_prefs.accentColor);

  final PreferencesStore _prefs;

  Future<void> setColor(Color color) async {
    state = color;
    await _prefs.setAccentColor(color);
  }
}

final workspacesProvider = StreamProvider<List<Workspace>>((ref) {
  return ref.watch(workspaceRepositoryProvider).watchAll();
});

final activeWorkspaceIdProvider =
    StateNotifierProvider<ActiveWorkspaceController, String?>((ref) {
  return ActiveWorkspaceController(ref.watch(preferencesStoreProvider));
});

class ActiveWorkspaceController extends StateNotifier<String?> {
  ActiveWorkspaceController(this._prefs) : super(_prefs.activeWorkspaceId);

  final PreferencesStore _prefs;

  Future<void> select(String? id) async {
    state = id;
    await _prefs.setActiveWorkspaceId(id);
  }
}

final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  final id = ref.watch(activeWorkspaceIdProvider);
  final list = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
  if (list.isEmpty) return null;
  if (id == null) return list.first;
  for (final w in list) {
    if (w.localId == id) return w;
  }
  return list.first;
});

/// True when there is no workspace yet (failed login should not leave orphans).
final needsOnboardingProvider = Provider<bool>((ref) {
  final workspaces = ref.watch(workspacesProvider);
  if (workspaces.isLoading) return false;
  final list = workspaces.valueOrNull ?? const [];
  return list.isEmpty;
});

final memoFilterProvider =
    StateProvider<MemoQuery>((ref) => const MemoQuery());

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedMemoIdProvider = StateProvider<String?>((ref) => null);

final memosProvider = StreamProvider<List<Memo>>((ref) {
  final ws = ref.watch(activeWorkspaceProvider);
  if (ws == null) return Stream.value(const []);
  final filter = ref.watch(memoFilterProvider);
  final search = ref.watch(searchQueryProvider).trim();
  final repo = ref.watch(memoRepositoryProvider);
  if (search.isEmpty) {
    return repo.watchAll(ws.localId, query: filter);
  }
  return Stream.fromFuture(
    repo.search(ws.localId, search, filters: filter),
  );
});

final selectedMemoProvider = Provider<Memo?>((ref) {
  final id = ref.watch(selectedMemoIdProvider);
  final memos = ref.watch(memosProvider).valueOrNull ?? const [];
  if (id == null) return null;
  for (final m in memos) {
    if (m.localId == id) return m;
  }
  return null;
});

final syncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) {
  // Ensure reconnect listener is active.
  ref.watch(connectivitySyncBootstrapProvider);

  final ws = ref.watch(activeWorkspaceProvider);
  if (ws == null || !ws.isMemos) {
    return Stream.value(const SyncStatusSnapshot.idle());
  }
  final sync = ref.watch(syncServiceProvider);
  ref.listen<Workspace?>(activeWorkspaceProvider, (prev, next) {
    if (next != null && next.isMemos) {
      sync.start(next);
    }
    if (prev != null && prev.localId != next?.localId) {
      sync.stop(prev.localId);
    }
  });
  if (ws.isMemos) {
    Future.microtask(() async {
      await sync.start(ws);
      final prefs = ref.read(syncPrefsProvider);
      if (prefs.syncOnLaunch && ws.authState == WorkspaceAuthState.ok) {
        await sync.syncNow(ws);
      }
    });
  }
  return sync.watchStatus(ws.localId);
});
