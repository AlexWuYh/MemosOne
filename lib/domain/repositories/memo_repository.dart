import '../entities/memo.dart';
import '../entities/sync_models.dart';

abstract class MemoRepository {
  Stream<List<Memo>> watchAll(String workspaceId, {MemoQuery query = const MemoQuery()});

  Future<Memo?> getByLocalId(String localId);

  Future<Memo> create(String workspaceId, NewMemo input);

  Future<Memo> update(String localId, MemoPatch patch);

  Future<void> softDelete(String localId);

  Future<void> pin(String localId, bool pinned);

  Future<void> archive(String localId, bool archived);

  Future<List<Memo>> search(String workspaceId, String query, {MemoQuery filters = const MemoQuery()});

  Future<List<MemoHistoryEntry>> history(String memoLocalId);

  Future<Memo> restoreFromHistory(String historyLocalId);

  Future<List<AttachmentItem>> listAttachments(String memoLocalId);

  Future<AttachmentItem> addLocalAttachment({
    required String memoLocalId,
    required String workspaceId,
    required String localPath,
    required String mimeType,
    required int sizeBytes,
    String? fileName,
  });

  Future<void> removeAttachment(String attachmentLocalId);
}
