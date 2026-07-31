import '../entities/sync_models.dart';
import '../entities/workspace.dart';

abstract class SyncService {
  Stream<SyncStatusSnapshot> watchStatus(String workspaceId);

  Future<void> start(Workspace workspace);

  Future<void> stop(String workspaceId);

  Future<void> syncNow(Workspace workspace);

  Future<void> pullOnly(Workspace workspace);

  Future<List<SyncTask>> listDeadTasks(String workspaceId);

  Future<void> retryDeadTask(String taskId);
}
