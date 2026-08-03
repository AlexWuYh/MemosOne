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

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final worker = SyncWorker(
    db: ref.watch(appDatabaseProvider),
    tokens: ref.watch(secureTokenStoreProvider),
    // MemoRepositoryImpl implements SyncMemoGateway (sync port).
    memos: ref.watch(memoRepositoryImplProvider),
  );
  ref.onDispose(worker.dispose);
  return worker;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return ref.watch(syncWorkerProvider);
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
  final ws = ref.watch(activeWorkspaceProvider);
  if (ws == null || !ws.isMemos) {
    return Stream.value(const SyncStatusSnapshot.idle());
  }
  final sync = ref.watch(syncServiceProvider);
  // ensure worker started
  ref.listen<Workspace?>(activeWorkspaceProvider, (prev, next) {
    if (next != null && next.isMemos) {
      sync.start(next);
    }
    if (prev != null && prev.localId != next?.localId) {
      sync.stop(prev.localId);
    }
  });
  if (ws.isMemos) {
    Future.microtask(() => sync.start(ws));
  }
  return sync.watchStatus(ws.localId);
});
