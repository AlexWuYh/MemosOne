import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/sync_models.dart';
import 'package:memos_one/infrastructure/database/app_database.dart';
import 'package:memos_one/infrastructure/sync/sync_queue.dart';

void main() {
  late AppDatabase db;
  late SyncQueue queue;

  setUp(() {
    db = AppDatabase.forTesting();
    queue = SyncQueue(db);
  });

  tearDown(() async => db.close());

  test('create then delete before push cancels tasks', () async {
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.create,
    );
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.delete,
    );
    final tasks = await db.select(db.syncTasks).get();
    expect(tasks, isEmpty);
  });

  test('multiple updates coalesce', () async {
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    final tasks = await db.select(db.syncTasks).get();
    expect(tasks.length, 1);
    expect(tasks.first.action, 'update');
  });

  test('create then update keeps create', () async {
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.create,
    );
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    final tasks = await db.select(db.syncTasks).get();
    expect(tasks.length, 1);
    expect(tasks.first.action, 'create');
  });
}
