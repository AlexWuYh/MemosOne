import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/memo.dart';
import 'package:memos_one/infrastructure/sync/conflict_resolver.dart';

Memo _memo({
  required bool dirty,
  required DateTime updated,
}) {
  return Memo(
    localId: 'a',
    workspaceId: 'w',
    content: 'x',
    visibility: MemoVisibility.private,
    pinned: false,
    archived: false,
    createdAtLocal: updated,
    updatedAtLocal: updated,
    syncStatus: dirty ? MemoSyncStatus.dirty : MemoSyncStatus.clean,
    dirty: dirty,
    version: 1,
  );
}

void main() {
  final resolver = ConflictResolver();

  test('clean local always takes remote', () {
    final local = _memo(dirty: false, updated: DateTime(2024, 1, 2));
    final winner = resolver.decide(
      local: local,
      remoteUpdatedAt: DateTime(2024, 1, 1),
    );
    expect(winner, ConflictWinner.remote);
  });

  test('dirty local wins when newer', () {
    final local = _memo(dirty: true, updated: DateTime(2024, 1, 3));
    final winner = resolver.decide(
      local: local,
      remoteUpdatedAt: DateTime(2024, 1, 2),
    );
    expect(winner, ConflictWinner.local);
  });

  test('dirty local loses when remote newer', () {
    final local = _memo(dirty: true, updated: DateTime(2024, 1, 1));
    final winner = resolver.decide(
      local: local,
      remoteUpdatedAt: DateTime(2024, 1, 2),
    );
    expect(winner, ConflictWinner.remote);
  });
}
