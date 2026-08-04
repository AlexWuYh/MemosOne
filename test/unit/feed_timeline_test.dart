import 'package:flutter_test/flutter_test.dart';
import 'package:memos_one/domain/entities/memo.dart';
import 'package:memos_one/feature/memo/presentation/feed_timeline.dart';

Memo _memo({
  required String id,
  required DateTime updated,
  String content = 'hello',
}) {
  return Memo(
    localId: id,
    workspaceId: 'ws',
    content: content,
    visibility: MemoVisibility.private,
    pinned: false,
    archived: false,
    createdAtLocal: updated,
    updatedAtLocal: updated,
    syncStatus: MemoSyncStatus.clean,
    dirty: false,
    version: 1,
  );
}

void main() {
  group('FeedTimeline.groupByDay', () {
    test('groups by calendar day newest first', () {
      final a = _memo(id: 'a', updated: DateTime(2026, 8, 4, 10));
      final b = _memo(id: 'b', updated: DateTime(2026, 8, 4, 18));
      final c = _memo(id: 'c', updated: DateTime(2026, 8, 2, 9));
      final map = FeedTimeline.groupByDay([a, c, b]);
      expect(map.keys.toList(), [
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 2),
      ]);
      expect(map[DateTime(2026, 8, 4)]!.map((m) => m.localId).toList(),
          ['a', 'b']);
      expect(map[DateTime(2026, 8, 2)]!.single.localId, 'c');
    });
  });

  group('FeedTimeline.buildRows / dayIndexMap', () {
    test('day markers then memos; index points at day rows', () {
      final groups = FeedTimeline.groupByDay([
        _memo(id: '1', updated: DateTime(2026, 8, 3)),
        _memo(id: '2', updated: DateTime(2026, 8, 1)),
        _memo(id: '3', updated: DateTime(2026, 8, 3, 12)),
      ]);
      final rows = FeedTimeline.buildRows(groups);
      // day(8/3), m1, m3, day(8/1), m2
      expect(rows.length, 5);
      expect(rows[0].isDay, isTrue);
      expect(rows[0].dayCount, 2);
      expect(rows[1].memo?.localId, '1');
      expect(rows[2].memo?.localId, '3');
      expect(rows[3].isDay, isTrue);
      expect(rows[4].memo?.localId, '2');

      final idx = FeedTimeline.dayIndexMap(rows);
      expect(idx[DateTime(2026, 8, 3)], 0);
      expect(idx[DateTime(2026, 8, 1)], 3);
    });
  });

  group('FeedTimeline.estimateOffset / clampOffset', () {
    test('sums header + day/memo extents', () {
      final rows = FeedTimeline.buildRows(
        FeedTimeline.groupByDay([
          _memo(id: '1', updated: DateTime(2026, 8, 4)),
          _memo(id: '2', updated: DateTime(2026, 8, 3)),
        ]),
      );
      // index 0 day: just header
      expect(
        FeedTimeline.estimateOffset(0, rows),
        FeedTimeline.headerExtent,
      );
      // index 1 first memo: header + day
      expect(
        FeedTimeline.estimateOffset(1, rows),
        FeedTimeline.headerExtent + FeedTimeline.dayExtent,
      );
      // index 2 day for older: header + day + memo
      expect(
        FeedTimeline.estimateOffset(2, rows),
        FeedTimeline.headerExtent +
            FeedTimeline.dayExtent +
            FeedTimeline.memoExtent,
      );
    });

    test('clampOffset bounds', () {
      expect(FeedTimeline.clampOffset(-10, 100), 0);
      expect(FeedTimeline.clampOffset(50, 100), 50);
      expect(FeedTimeline.clampOffset(150, 100), 100);
      expect(FeedTimeline.clampOffset(10, -1), 0);
    });
  });
}
