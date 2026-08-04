import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Primary content area mode (desktop / tablet).
enum AppViewMode {
  notes,
  feed,
  explore,
  calendar,
}

final appViewModeProvider =
    StateProvider<AppViewMode>((ref) => AppViewMode.notes);

/// When true, the memo list column is collapsed (wide notes/calendar layout).
final memoListCollapsedProvider = StateProvider<bool>((ref) => false);

/// Calendar currently displayed month (first day of month).
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});

/// Calendar year mode vs month mode.
final calendarYearModeProvider = StateProvider<bool>((ref) => false);
