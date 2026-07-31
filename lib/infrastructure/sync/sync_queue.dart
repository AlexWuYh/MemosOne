import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/sync_models.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// Durable queue with coalescing rules from sync-spec.
class SyncQueue {
  SyncQueue(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<void> enqueueMemo({
    required String workspaceId,
    required String entityLocalId,
    required SyncAction action,
  }) async {
    final existing = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.entityType.equals(SyncEntityType.memo.name) &
                t.entityLocalId.equals(entityLocalId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                ]),
          ))
        .get();

    // Coalesce rules
    if (action == SyncAction.delete) {
      final hasCreate = existing.any((e) => e.action == SyncAction.create.name);
      if (hasCreate) {
        for (final e in existing) {
          await (_db.delete(_db.syncTasks)..where((t) => t.id.equals(e.id))).go();
        }
        // never pushed — nothing to delete remotely
        return;
      }
      for (final e in existing) {
        await (_db.delete(_db.syncTasks)..where((t) => t.id.equals(e.id))).go();
      }
      await _insert(
        workspaceId: workspaceId,
        entityLocalId: entityLocalId,
        action: SyncAction.delete,
      );
      return;
    }

    if (action == SyncAction.create) {
      final hasCreate =
          existing.any((e) => e.action == SyncAction.create.name);
      if (hasCreate) return;
      await _insert(
        workspaceId: workspaceId,
        entityLocalId: entityLocalId,
        action: SyncAction.create,
      );
      return;
    }

    // update
    final hasCreate = existing.any((e) => e.action == SyncAction.create.name);
    if (hasCreate) {
      // keep create with latest payload (payload optional)
      return;
    }
    final hasUpdate = existing.any((e) => e.action == SyncAction.update.name);
    if (hasUpdate) {
      final task = existing.firstWhere((e) => e.action == SyncAction.update.name);
      await (_db.update(_db.syncTasks)..where((t) => t.id.equals(task.id)))
          .write(
        SyncTasksCompanion(
          status: Value(SyncTaskStatus.pending.name),
          nextAttemptAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          lastError: const Value(null),
        ),
      );
      return;
    }
    await _insert(
      workspaceId: workspaceId,
      entityLocalId: entityLocalId,
      action: SyncAction.update,
    );
  }

  Future<void> _insert({
    required String workspaceId,
    required String entityLocalId,
    required SyncAction action,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.syncTasks).insert(
          SyncTasksCompanion.insert(
            id: _uuid.v4(),
            workspaceId: workspaceId,
            entityType: SyncEntityType.memo.name,
            entityLocalId: entityLocalId,
            action: action.name,
            status: SyncTaskStatus.pending.name,
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<SyncTask?> nextPending(String workspaceId) async {
    final now = DateTime.now();
    final row = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                ]) &
                t.nextAttemptAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : syncTaskFromRow(row);
  }

  Future<void> markRunning(String id) async {
    await (_db.update(_db.syncTasks)..where((t) => t.id.equals(id))).write(
      SyncTasksCompanion(
        status: Value(SyncTaskStatus.running.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> complete(String id) async {
    await (_db.delete(_db.syncTasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> fail({
    required String id,
    required int retryCount,
    required DateTime nextAttemptAt,
    required String error,
    required bool dead,
  }) async {
    await (_db.update(_db.syncTasks)..where((t) => t.id.equals(id))).write(
      SyncTasksCompanion(
        status: Value(
          dead ? SyncTaskStatus.dead.name : SyncTaskStatus.failed.name,
        ),
        retryCount: Value(retryCount),
        nextAttemptAt: Value(nextAttemptAt),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countPending(String workspaceId) async {
    final rows = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                  SyncTaskStatus.running.name,
                ]),
          ))
        .get();
    return rows.length;
  }

  Future<int> countDead(String workspaceId) async {
    final rows = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.dead.name),
          ))
        .get();
    return rows.length;
  }

  Future<List<SyncTask>> listDead(String workspaceId) async {
    final rows = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.dead.name),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(syncTaskFromRow).toList();
  }

  Future<void> retryDead(String taskId) async {
    await (_db.update(_db.syncTasks)..where((t) => t.id.equals(taskId))).write(
      SyncTasksCompanion(
        status: Value(SyncTaskStatus.pending.name),
        retryCount: const Value(0),
        nextAttemptAt: Value(DateTime.now()),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static Duration backoff(int retryCount) {
    const delays = [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 300),
    ];
    if (retryCount <= 0) return delays.first;
    if (retryCount >= delays.length) return delays.last;
    return delays[retryCount];
  }
}
