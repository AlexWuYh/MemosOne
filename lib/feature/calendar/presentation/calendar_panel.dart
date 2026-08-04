import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation_state.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';

final _activityProvider =
    FutureProvider.autoDispose.family<Map<DateTime, int>, ({int y, int m})>(
  (ref, key) async {
    final ws = ref.watch(activeWorkspaceProvider);
    if (ws == null) return {};
    final from = DateTime(key.y, key.m, 1);
    final to = DateTime(key.y, key.m + 1, 0);
    return ref.read(memoRepositoryImplProvider).activityByDay(
          ws.localId,
          from: from,
          to: to,
        );
  },
);

final _yearActivityProvider =
    FutureProvider.autoDispose.family<Map<DateTime, int>, int>((ref, year) async {
  final ws = ref.watch(activeWorkspaceProvider);
  if (ws == null) return {};
  return ref.read(memoRepositoryImplProvider).activityByDay(
        ws.localId,
        from: DateTime(year, 1, 1),
        to: DateTime(year, 12, 31),
      );
});

class CalendarPanel extends ConsumerWidget {
  const CalendarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearMode = ref.watch(calendarYearModeProvider);
    final month = ref.watch(calendarMonthProvider);
    final filter = ref.watch(memoFilterProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Text(
                '日历热力',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('月')),
                  ButtonSegment(value: true, label: Text('年')),
                ],
                selected: {yearMode},
                onSelectionChanged: (s) =>
                    ref.read(calendarYearModeProvider.notifier).state =
                        s.first,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        if (filter.day != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                ),
                deleteIconColor: Theme.of(context).colorScheme.primary,
                label: Text(
                  '已过滤：${DateFormat('yyyy-MM-dd').format(filter.day!)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                onDeleted: () {
                  ref.read(memoFilterProvider.notifier).state =
                      filter.copyWith(clearDay: true);
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: yearMode ? '上一年' : '上一月',
                onPressed: () {
                  final m = ref.read(calendarMonthProvider);
                  ref.read(calendarMonthProvider.notifier).state = yearMode
                      ? DateTime(m.year - 1, m.month)
                      : DateTime(m.year, m.month - 1);
                },
                icon: Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  yearMode
                      ? '${month.year} 年'
                      : DateFormat('yyyy 年 M 月').format(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                tooltip: yearMode ? '下一年' : '下一月',
                onPressed: () {
                  final m = ref.read(calendarMonthProvider);
                  ref.read(calendarMonthProvider.notifier).state = yearMode
                      ? DateTime(m.year + 1, m.month)
                      : DateTime(m.year, m.month + 1);
                },
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () {
                  final n = DateTime.now();
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(n.year, n.month);
                },
                child: const Text('今天'),
              ),
            ],
          ),
        ),
        Expanded(
          child: yearMode
              ? _YearGrid(year: month.year)
              : _MonthHeatmap(year: month.year, month: month.month),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '颜色越深表示当日笔记更新越多；点击日期可在笔记列表中按日过滤。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _MonthHeatmap extends ConsumerWidget {
  const _MonthHeatmap({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activityProvider((y: year, m: month)));
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday-first: weekday 1..7
    final lead = (first.weekday + 6) % 7;
    final cells = lead + daysInMonth;
    final rows = ((cells + 6) ~/ 7);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (activity) {
        final maxC = activity.values.fold<int>(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: ['一', '二', '三', '四', '五', '六', '日']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: rows > 5 ? 1.1 : 1.2,
                  ),
                  itemCount: rows * 7,
                  itemBuilder: (context, index) {
                    final dayNum = index - lead + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final day = DateTime(year, month, dayNum);
                    final now = DateTime.now();
                    final isToday = day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    final count = activity[day] ?? 0;
                    final t = maxC == 0 ? 0.0 : count / maxC;
                    final bg = count == 0
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                        : Color.lerp(
                            scheme.primaryContainer,
                            scheme.primary,
                            t.clamp(0.15, 1.0),
                          )!;
                    // Heat cells with primary fill need light text; empty use ink.
                    final fg = count > 0
                        ? Colors.white
                        : (isToday ? Theme.of(context).colorScheme.primary : scheme.onSurface);
                    final selected = ref.watch(memoFilterProvider).day;
                    final isSel = selected != null &&
                        selected.year == day.year &&
                        selected.month == day.month &&
                        selected.day == day.day;
                    return Material(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final cur = ref.read(memoFilterProvider);
                          if (isSel) {
                            ref.read(memoFilterProvider.notifier).state =
                                cur.copyWith(clearDay: true);
                          } else {
                            ref.read(memoFilterProvider.notifier).state =
                                cur.copyWith(day: day);
                            ref.read(appViewModeProvider.notifier).state =
                                AppViewMode.notes;
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: isSel ? 2.5 : 2,
                                  )
                                : isSel
                                    ? Border.all(
                                        color: AppTheme.ink,
                                        width: 2,
                                      )
                                    : null,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontWeight:
                                        isToday ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13,
                                    color: fg,
                                  ),
                                ),
                                if (count > 0)
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: fg.withValues(alpha: 0.92),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YearGrid extends ConsumerWidget {
  const _YearGrid({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_yearActivityProvider(year));
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (activity) {
        final maxC = activity.values.fold<int>(0, (a, b) => a > b ? a : b);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: 12,
          itemBuilder: (context, mi) {
            final month = mi + 1;
            final days = DateTime(year, month + 1, 0).day;
            return Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(year, month);
                  ref.read(calendarYearModeProvider.notifier).state = false;
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        '$month 月',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          itemCount: days,
                          itemBuilder: (context, di) {
                            final day = DateTime(year, month, di + 1);
                            final c = activity[day] ?? 0;
                            final t = maxC == 0 ? 0.0 : c / maxC;
                            final color = c == 0
                                ? scheme.outlineVariant.withValues(alpha: 0.25)
                                : Color.lerp(
                                    scheme.primaryContainer,
                                    scheme.primary,
                                    t.clamp(0.2, 1.0),
                                  )!;
                            return Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
