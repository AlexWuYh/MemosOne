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
    // Include running so we don't spawn duplicate tasks mid-push.
    final existing = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.entityType.equals(SyncEntityType.memo.name) &
                t.entityLocalId.equals(entityLocalId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                  SyncTaskStatus.running.name,
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
      // keep create with latest payload (loaded from DB at push time)
      return;
    }
    final openUpdates = existing
        .where((e) => e.action == SyncAction.update.name)
        .toList();
    if (openUpdates.isNotEmpty) {
      // Prefer reactivating a non-running update; if only running exists,
      // insert a follow-up so edits made during push are not lost.
      final waiting = openUpdates
          .where((e) => e.status != SyncTaskStatus.running.name)
          .toList();
      if (waiting.isNotEmpty) {
        final task = waiting.first;
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
      // Only a running update — queue one follow-up.
      if (openUpdates.length == 1) {
        await _insert(
          workspaceId: workspaceId,
          entityLocalId: entityLocalId,
          action: SyncAction.update,
        );
      }
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

  Future<SyncTask?> nextPending(
    String workspaceId, {
    bool ignoreBackoff = false,
  }) async {
    final now = DateTime.now();
    final query = _db.select(_db.syncTasks)
      ..where(
        (t) {
          final base = t.workspaceId.equals(workspaceId) &
              t.status.isIn([
                SyncTaskStatus.pending.name,
                SyncTaskStatus.failed.name,
              ]);
          if (ignoreBackoff) return base;
          return base & t.nextAttemptAt.isSmallerOrEqualValue(now);
        },
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : syncTaskFromRow(row);
  }

  /// Recover tasks stuck in `running` after crash / interrupted push.
  Future<void> recoverStuckRunning(String workspaceId) async {
    final now = DateTime.now();
    await (_db.update(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.running.name),
          ))
        .write(
      SyncTasksCompanion(
        status: Value(SyncTaskStatus.pending.name),
        nextAttemptAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Clear backoff on pending/failed so "立即同步" drains immediately.
  Future<void> clearBackoff(String workspaceId) async {
    final now = DateTime.now();
    await (_db.update(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                ]),
          ))
        .write(
      SyncTasksCompanion(
        status: Value(SyncTaskStatus.pending.name),
        nextAttemptAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> prepareForceDrain(String workspaceId) async {
    await recoverStuckRunning(workspaceId);
    await clearBackoff(workspaceId);
  }

  /// True if this entity still has unfinished queue work.
  Future<bool> hasOpenTask({
    required String workspaceId,
    required String entityLocalId,
    bool includeDead = false,
  }) async {
    final statuses = [
      SyncTaskStatus.pending.name,
      SyncTaskStatus.failed.name,
      SyncTaskStatus.running.name,
      if (includeDead) SyncTaskStatus.dead.name,
    ];
    final rows = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.entityLocalId.equals(entityLocalId) &
                t.status.isIn(statuses),
          )
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// Keep at most one dead task per entity (prevents settings-page floods).
  Future<int> pruneDuplicateDead(String workspaceId) async {
    final rows = await (_db.select(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.dead.name),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    final seen = <String>{};
    var removed = 0;
    for (final row in rows) {
      if (seen.contains(row.entityLocalId)) {
        await (_db.delete(_db.syncTasks)..where((t) => t.id.equals(row.id)))
            .go();
        removed++;
      } else {
        seen.add(row.entityLocalId);
      }
    }
    return removed;
  }

  Future<int> clearDead(String workspaceId) async {
    return (_db.delete(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.dead.name),
          ))
        .go();
  }

  Future<int> retryAllDead(String workspaceId) async {
    final now = DateTime.now();
    // First collapse duplicates so we don't retry 200 identical creates.
    await pruneDuplicateDead(workspaceId);
    return (_db.update(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.status.equals(SyncTaskStatus.dead.name),
          ))
        .write(
      SyncTasksCompanion(
        status: Value(SyncTaskStatus.pending.name),
        retryCount: const Value(0),
        nextAttemptAt: Value(now),
        lastError: const Value(null),
        updatedAt: Value(now),
      ),
    );
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
    String? workspaceId,
    String? entityLocalId,
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
    // When a task dies, drop older dead clones for the same memo.
    if (dead && workspaceId != null && entityLocalId != null) {
      final others = await (_db.select(_db.syncTasks)
            ..where(
              (t) =>
                  t.workspaceId.equals(workspaceId) &
                  t.entityLocalId.equals(entityLocalId) &
                  t.status.equals(SyncTaskStatus.dead.name) &
                  t.id.isNotValue(id),
            ))
          .get();
      for (final o in others) {
        await (_db.delete(_db.syncTasks)..where((t) => t.id.equals(o.id))).go();
      }
    }
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

  /// Drop all unfinished tasks for an entity (e.g. never-synced local delete).
  Future<void> cancelAllForEntity({
    required String workspaceId,
    required String entityLocalId,
  }) async {
    await (_db.delete(_db.syncTasks)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) &
                t.entityLocalId.equals(entityLocalId) &
                t.status.isIn([
                  SyncTaskStatus.pending.name,
                  SyncTaskStatus.failed.name,
                  SyncTaskStatus.running.name,
                  SyncTaskStatus.dead.name,
                ]),
          ))
        .go();
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
