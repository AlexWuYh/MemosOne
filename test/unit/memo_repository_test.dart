import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/memo.dart';
import 'package:memos_one/domain/entities/workspace.dart';
import 'package:memos_one/infrastructure/database/app_database.dart';
import 'package:memos_one/infrastructure/repositories/memo_repository_impl.dart';
import 'package:memos_one/infrastructure/sync/sync_queue.dart';

void main() {
  late AppDatabase db;
  late MemoRepositoryImpl memos;
  setUp(() {
    db = AppDatabase.forTesting();
    memos = MemoRepositoryImpl(
      db,
      SyncQueue(db),
      workspaceTypeResolver: (_) async => WorkspaceType.local,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('local create update delete and tags', () async {
    // Workspace create uses path_provider; insert workspace row directly.
    final now = DateTime.now();
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            localId: 'ws1',
            name: 'Test',
            type: WorkspaceType.local.name,
            databasePath: ':memory:',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final created = await memos.create(
      'ws1',
      const NewMemo(content: 'Hello #tagA world'),
    );
    expect(created.content, contains('#tagA'));
    expect(created.tags, contains('taga'));
    expect(created.dirty, isFalse);

    final updated = await memos.update(
      created.localId,
      const MemoPatch(content: 'Updated #tagB'),
    );
    expect(updated.content, 'Updated #tagB');
    expect(updated.tags, contains('tagb'));
    expect(updated.version, greaterThan(created.version));

    final history = await memos.history(created.localId);
    expect(history, isNotEmpty);

    await memos.pin(created.localId, true);
    final pinned = await memos.getByLocalId(created.localId);
    expect(pinned!.pinned, isTrue);

    await memos.softDelete(created.localId);
    final gone = await memos.getByLocalId(created.localId);
    expect(gone, isNull);

    final search = await memos.search('ws1', 'Updated');
    // deleted memo should not appear
    expect(
      search.where((Memo m) => m.localId == created.localId),
      isEmpty,
    );
  });

  test('sync queue coalesces updates for memos workspace', () async {
    final now = DateTime.now();
    await db.into(db.workspaces).insert(
          WorkspacesCompanion.insert(
            localId: 'ws2',
            name: 'Remote',
            type: WorkspaceType.memos.name,
            databasePath: ':memory:',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = MemoRepositoryImpl(
      db,
      SyncQueue(db),
      workspaceTypeResolver: (_) async => WorkspaceType.memos,
    );
    final memo = await repo.create('ws2', const NewMemo(content: 'A'));
    expect(memo.dirty, isTrue);
    await repo.update(memo.localId, const MemoPatch(content: 'B'));
    await repo.update(memo.localId, const MemoPatch(content: 'C'));

    final tasks = await db.select(db.syncTasks).get();
    expect(tasks.length, 1);
    expect(tasks.first.action, 'create');
  });
}
