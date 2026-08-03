import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/core/constants/app_constants.dart';
import 'package:memos_one/domain/entities/workspace.dart';
import 'package:memos_one/infrastructure/database/app_database.dart';
import 'package:memos_one/infrastructure/repositories/memo_repository_impl.dart';
import 'package:memos_one/infrastructure/storage/secure_token_store.dart';
import 'package:memos_one/infrastructure/sync/sync_queue.dart';
import 'package:memos_one/infrastructure/sync/sync_worker.dart';

class _MemStorage extends FlutterSecureStorage {
  _MemStorage() : super();
  final map = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      map[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    map.remove(key);
  }
}

void main() {
  late AppDatabase db;
  late MemoRepositoryImpl memos;
  late SyncWorker worker;

  setUp(() {
    db = AppDatabase.forTesting();
    memos = MemoRepositoryImpl(
      db,
      SyncQueue(db),
      workspaceTypeResolver: (_) async => WorkspaceType.memos,
    );
    worker = SyncWorker(
      db: db,
      tokens: SecureTokenStore(storage: _MemStorage()),
      memos: memos,
    );
  });

  tearDown(() async {
    await worker.dispose();
    await db.close();
  });

  Future<void> seedWorkspace({
    required bool initialSyncCompleted,
    DateTime? lastPull,
  }) async {
    final now = DateTime.now();
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            localId: 'ws',
            name: 'M',
            type: WorkspaceType.memos.name,
            databasePath: ':memory:',
            createdAt: now,
            updatedAt: now,
            initialSyncCompleted: Value(initialSyncCompleted),
          ),
        );
    if (lastPull != null) {
      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              key: 'memo_pull',
              workspaceId: 'ws',
              value: lastPull.toIso8601String(),
              updatedAt: lastPull,
            ),
          );
    }
  }

  test('forcePull always true', () async {
    await seedWorkspace(initialSyncCompleted: true, lastPull: DateTime.now());
    expect(
      await worker.shouldFullPull('ws', forcePull: true),
      isTrue,
    );
  });

  test('first sync incomplete triggers full pull', () async {
    await seedWorkspace(initialSyncCompleted: false);
    expect(
      await worker.shouldFullPull('ws', forcePull: false),
      isTrue,
    );
  });

  test('recent pull skips full pull', () async {
    await seedWorkspace(
      initialSyncCompleted: true,
      lastPull: DateTime.now(),
    );
    expect(
      await worker.shouldFullPull('ws', forcePull: false),
      isFalse,
    );
  });

  test('stale pull triggers full pull', () async {
    final stale = DateTime.now().subtract(
      const Duration(minutes: AppConstants.fullPullIntervalMinutes + 1),
    );
    await seedWorkspace(initialSyncCompleted: true, lastPull: stale);
    expect(
      await worker.shouldFullPull('ws', forcePull: false),
      isTrue,
    );
  });

  test('listServerBound and hard delete remove ghost candidates', () async {
    await seedWorkspace(initialSyncCompleted: true, lastPull: DateTime.now());
    final now = DateTime.now();
    await db.into(db.memos).insert(
          MemosCompanion.insert(
            localId: 'm1',
            workspaceId: 'ws',
            serverName: const Value('memos/1'),
            content: 'a',
            createdAtLocal: now,
            updatedAtLocal: now,
            syncStatus: const Value('clean'),
            dirty: const Value(false),
          ),
        );
    await db.into(db.memos).insert(
          MemosCompanion.insert(
            localId: 'm2',
            workspaceId: 'ws',
            serverName: const Value('memos/2'),
            content: 'b',
            createdAtLocal: now,
            updatedAtLocal: now,
            syncStatus: const Value('clean'),
            dirty: const Value(false),
          ),
        );

    final bound = await memos.listServerBound('ws');
    expect(bound.map((m) => m.serverName).toSet(), {'memos/1', 'memos/2'});

    // Simulate reconcile: remote only has memos/1
    final seen = {'memos/1'};
    for (final local in bound) {
      if (!seen.contains(local.serverName)) {
        if (local.dirty) {
          await memos.prepareRecreateAfterRemoteDelete(local.localId);
        } else {
          await memos.hardDeleteLocal(local.localId);
        }
      }
    }

    final after = await memos.listServerBound('ws');
    expect(after.map((m) => m.serverName).toList(), ['memos/1']);
    expect(await memos.getByLocalId('m2'), isNull);
  });

  test('dirty remote-delete prepares recreate', () async {
    await seedWorkspace(initialSyncCompleted: true, lastPull: DateTime.now());
    final now = DateTime.now();
    await db.into(db.memos).insert(
          MemosCompanion.insert(
            localId: 'm3',
            workspaceId: 'ws',
            serverName: const Value('memos/9'),
            content: 'local edit',
            createdAtLocal: now,
            updatedAtLocal: now,
            syncStatus: const Value('dirty'),
            dirty: const Value(true),
          ),
        );
    await memos.prepareRecreateAfterRemoteDelete('m3');
    final m = await memos.getByLocalId('m3');
    expect(m, isNotNull);
    expect(m!.serverName, isNull);
    expect(m.dirty, isTrue);
    final tasks = await db.select(db.syncTasks).get();
    expect(tasks.any((t) => t.action == 'create'), isTrue);
  });
}
