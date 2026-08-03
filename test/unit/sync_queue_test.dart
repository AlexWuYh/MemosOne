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

  test('update while running enqueues follow-up', () async {
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    final first = (await db.select(db.syncTasks).get()).single;
    await queue.markRunning(first.id);
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    final tasks = await db.select(db.syncTasks).get();
    expect(tasks.length, 2);
    expect(
      tasks.where((t) => t.status == SyncTaskStatus.running.name).length,
      1,
    );
    expect(
      tasks.where((t) => t.status == SyncTaskStatus.pending.name).length,
      1,
    );
  });

  test('clearBackoff makes failed tasks eligible immediately', () async {
    await queue.enqueueMemo(
      workspaceId: 'w',
      entityLocalId: 'm1',
      action: SyncAction.update,
    );
    final id = (await db.select(db.syncTasks).get()).single.id;
    await queue.fail(
      id: id,
      retryCount: 2,
      nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
      error: 'temp',
      dead: false,
    );
    expect(await queue.nextPending('w'), isNull);
    await queue.clearBackoff('w');
    final next = await queue.nextPending('w', ignoreBackoff: true);
    expect(next, isNotNull);
    expect(next!.entityLocalId, 'm1');
  });
}
