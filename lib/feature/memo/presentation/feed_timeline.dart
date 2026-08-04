import '../../../domain/entities/memo.dart';

/// Pure helpers for the feed timeline (testable without Flutter widgets).
abstract final class FeedTimeline {
  /// Newest day first.
  static Map<DateTime, List<Memo>> groupByDay(List<Memo> memos) {
    final map = <DateTime, List<Memo>>{};
    for (final m in memos) {
      final t = m.updatedAtLocal;
      final day = DateTime(t.year, t.month, t.day);
      (map[day] ??= []).add(m);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  /// Flatten day groups into day-marker + memo rows.
  static List<FeedRow> buildRows(Map<DateTime, List<Memo>> groups) {
    final days = groups.keys.toList();
    final rows = <FeedRow>[];
    for (final day in days) {
      final list = groups[day]!;
      rows.add(FeedRow.day(day, list.length));
      for (final m in list) {
        rows.add(FeedRow.memo(m));
      }
    }
    return rows;
  }

  /// day (date-only) → index in [rows]
  static Map<DateTime, int> dayIndexMap(List<FeedRow> rows) {
    final map = <DateTime, int>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isDay && row.day != null) {
        map[DateTime(row.day!.year, row.day!.month, row.day!.day)] = i;
      }
    }
    return map;
  }

  static const double headerExtent = 64;
  static const double dayExtent = 44;

  /// Conservative default card height for jump estimation.
  static const double memoExtent = 172;

  /// Estimated scroll offset for a row index (variable-height list).
  static double estimateOffset(
    int rowIndex,
    List<FeedRow> rows, {
    double headerExtent = headerExtent,
    double dayExtent = dayExtent,
    double memoExtent = memoExtent,
  }) {
    var offset = headerExtent;
    for (var i = 0; i < rowIndex && i < rows.length; i++) {
      offset += rows[i].isDay ? dayExtent : memoExtent;
    }
    return offset;
  }

  /// Clamp [desired] into [0, maxExtent], refreshing when max grows.
  static double clampOffset(double desired, double maxExtent) {
    if (maxExtent < 0) return 0;
    if (desired < 0) return 0;
    if (desired > maxExtent) return maxExtent;
    return desired;
  }
}

class FeedRow {
  FeedRow.day(this.day, this.dayCount)
      : memo = null,
        isDay = true;

  FeedRow.memo(this.memo)
      : day = null,
        dayCount = null,
        isDay = false;

  final bool isDay;
  final DateTime? day;
  final int? dayCount;
  final Memo? memo;
}
