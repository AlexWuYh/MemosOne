import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/memo_snippet_card.dart';
import '../../../domain/entities/memo.dart';
import 'feed_timeline.dart';

/// Timeline feed — medium-width cards + continuous animated spine.
/// Wide layout also has a scrollable day axis navigator on the right.
class MemoFeedPanel extends ConsumerStatefulWidget {
  const MemoFeedPanel({super.key});

  static const int previewMaxChars = 380;
  static const int previewMaxLines = 8;

  /// Card column max width (not full page, not tiny).
  static const double feedMaxWidth = 580;

  /// Spine column width (continuous axis body).
  static const double spineWidth = 48;

  @override
  ConsumerState<MemoFeedPanel> createState() => _MemoFeedPanelState();
}

class _MemoFeedPanelState extends ConsumerState<MemoFeedPanel> {
  final _scroll = ScrollController();
  final _dayKeys = <DateTime, GlobalKey>{};

  List<FeedRow> _rows = const [];
  Map<DateTime, int> _dayIndex = const {};

  /// Cancels in-flight jump loops when user picks another day.
  int _jumpGen = 0;

  @override
  void dispose() {
    _jumpGen++;
    _scroll.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  GlobalKey _keyForDay(DateTime day) {
    final d = _dateOnly(day);
    return _dayKeys.putIfAbsent(d, GlobalKey.new);
  }

  void _syncIndex(List<FeedRow> rows) {
    _rows = rows;
    _dayIndex = FeedTimeline.dayIndexMap(rows);
    // Drop keys for days that no longer exist.
    final keep = _dayIndex.keys.toSet();
    _dayKeys.removeWhere((k, _) => !keep.contains(k));
  }

  Future<void> _jumpToDay(DateTime day) async {
    final d = _dateOnly(day);
    final index = _dayIndex[d];
    if (index == null || !_scroll.hasClients) return;

    final gen = ++_jumpGen;
    bool stillMine() => mounted && gen == _jumpGen && _scroll.hasClients;

    double maxExtent() => _scroll.position.maxScrollExtent;

    // Prefer short estimate first, then overshoot if needed (variable heights).
    var desired = FeedTimeline.estimateOffset(index, _rows);
    await _scroll.animateTo(
      FeedTimeline.clampOffset(desired, maxExtent()),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    if (!stillMine()) return;

    // Binary-ish search: alternate low/high nudges until key mounts.
    var low = 0.0;
    var high = maxExtent();
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!stillMine()) return;

      final ctx = _dayKeys[d]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: Duration(milliseconds: attempt == 0 ? 180 : 140),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
        return;
      }

      // Refresh extent — list may grow as children build.
      high = maxExtent();
      desired = FeedTimeline.estimateOffset(index, _rows);

      // Alternate: go toward estimate, then past it (undershoot recovery).
      final step = 140.0 * (attempt + 1);
      final candidate = attempt.isEven
          ? FeedTimeline.clampOffset(desired + step * 0.35, high)
          : FeedTimeline.clampOffset(desired - step * 0.25, high);
      // Expand search window gradually if stuck.
      if (attempt > 4) {
        low = FeedTimeline.clampOffset(desired - step, high);
        final mid = FeedTimeline.clampOffset((low + high) / 2, high);
        _scroll.jumpTo(attempt.isEven ? mid : FeedTimeline.clampOffset(desired + step, high));
      } else {
        _scroll.jumpTo(candidate);
      }

      await Future<void>.delayed(const Duration(milliseconds: 40));
      // Wait a frame for lazy children.
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!stillMine()) return;
    // Best-effort final scroll to estimate with live max.
    await _scroll.animateTo(
      FeedTimeline.clampOffset(
        FeedTimeline.estimateOffset(index, _rows),
        maxExtent(),
      ),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memosProvider);
    final active = ref.watch(activeWorkspaceProvider);

    return ColoredBox(
      color: AppTheme.paper,
      child: memosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (memos) {
          if (memos.isEmpty) {
            return AppEmptyState(
              title: '信息流还是空的',
              subtitle: '写一条笔记，它会出现在这条时间线上。',
              actionLabel: '新建笔记',
              onAction: () async {
                final ws = ref.read(activeWorkspaceProvider);
                if (ws == null) return;
                final visibility = ref.read(defaultVisibilityProvider);
                final memo = await ref.read(memoRepositoryProvider).create(
                      ws.localId,
                      NewMemo(content: '', visibility: visibility),
                    );
                ref.read(selectedMemoIdProvider.notifier).state = memo.localId;
              },
            );
          }

          final groups = FeedTimeline.groupByDay(memos);
          final days = groups.keys.toList();
          final rows = FeedTimeline.buildRows(groups);
          // Cache for jump-to-day (no setState — pure map refresh).
          _syncIndex(rows);

          return LayoutBuilder(
            builder: (context, constraints) {
              final showNavigator = constraints.maxWidth >= 1000;
              const totalW =
                  MemoFeedPanel.feedMaxWidth + MemoFeedPanel.spineWidth + 24;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: totalW,
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: MemoFeedPanel.spineWidth,
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            '信息流',
                                            style: GoogleFonts.inter(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.3,
                                              color: AppTheme.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceMuted,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${memos.length}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.inkMuted,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (active != null)
                                            Text(
                                              active.username?.isNotEmpty ==
                                                      true
                                                  ? '@${active.username}'
                                                  : active.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppTheme.inkSubtle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Continuous track + content as one list
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 48),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final row = rows[index];
                                final isFirst = index == 0;
                                final isLast = index == rows.length - 1;

                                if (row.isDay) {
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: totalW,
                                      child: KeyedSubtree(
                                        key: _keyForDay(row.day!),
                                        child: _SpineDayMarker(
                                          day: row.day!,
                                          count: row.dayCount!,
                                          showLineAbove: !isFirst,
                                          showLineBelow: !isLast,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final m = row.memo!;
                                final excerpt = _FeedPreview.build(
                                  m.content,
                                  maxChars: MemoFeedPanel.previewMaxChars,
                                );
                                return Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: totalW,
                                    child: _SpineMemoRow(
                                      showLineAbove: true,
                                      showLineBelow: !isLast,
                                      child: _FeedPostCard(
                                        memo: m,
                                        excerpt: excerpt.text,
                                        truncated: excerpt.truncated,
                                        displayName: active?.username ??
                                            active?.name ??
                                            '我',
                                        onTap: () {
                                          ref
                                              .read(
                                                selectedMemoIdProvider
                                                    .notifier,
                                              )
                                              .state = m.localId;
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: rows.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showNavigator) ...[
                    const VerticalDivider(width: 1, thickness: 1),
                    SizedBox(
                      width: 176,
                      child: _DayAxisNavigator(
                        days: days,
                        groups: groups,
                        onSelect: _jumpToDay,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

}

// ─── Continuous spine pieces ────────────────────────────────────────────────

/// Shared continuous rail: soft track + accent core.
class _SpineTrack extends StatelessWidget {
  const _SpineTrack({this.highlight = false});

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final core = highlight ? Theme.of(context).colorScheme.primary : const Color(0xFFC5D0DB);
    final glow = highlight
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
        : Colors.transparent;

    return AnimatedContainer(
      duration: AppTheme.motionFast,
      curve: Curves.easeOutCubic,
      width: 4,
      decoration: BoxDecoration(
        color: core,
        borderRadius: BorderRadius.circular(99),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: glow,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _SpineNode extends StatelessWidget {
  const _SpineNode({
    required this.hovered,
    this.large = false,
  });

  final bool hovered;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large
        ? (hovered ? 18.0 : 14.0)
        : (hovered ? 14.0 : 10.0);

    return AnimatedContainer(
      duration: AppTheme.motionFast,
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hovered ? Theme.of(context).colorScheme.primary : AppTheme.paperElevated,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: hovered ? 0 : 2.5,
        ),
        boxShadow: [
          if (hovered)
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: hovered
          ? Center(
              child: AnimatedScale(
                scale: 1,
                duration: AppTheme.motionFast,
                child: Container(
                  width: large ? 6 : 4,
                  height: large ? 6 : 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _SpineDayMarker extends StatefulWidget {
  const _SpineDayMarker({
    required this.day,
    required this.count,
    required this.showLineAbove,
    required this.showLineBelow,
  });

  final DateTime day;
  final int count;
  final bool showLineAbove;
  final bool showLineBelow;

  @override
  State<_SpineDayMarker> createState() => _SpineDayMarkerState();
}

class _SpineDayMarkerState extends State<_SpineDayMarker> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: MemoFeedPanel.spineWidth,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Continuous vertical track
                  Column(
                    children: [
                      Expanded(
                        child: widget.showLineAbove
                            ? _SpineTrack(highlight: _hover)
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: widget.showLineBelow
                            ? _SpineTrack(highlight: _hover)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  _SpineNode(hovered: _hover, large: true),
                ],
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: AppTheme.motionFast,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _hover ? Theme.of(context).colorScheme.primaryContainer : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _hover
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                ),
                transform: Matrix4.translationValues(_hover ? 4 : 0, 0, 0),
                child: Row(
                  children: [
                    Text(
                      _dayTitle(widget.day),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _hover ? Theme.of(context).colorScheme.primary : AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MM/dd').format(widget.day),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    AnimatedDefaultTextStyle(
                      duration: AppTheme.motionFast,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _hover ? Theme.of(context).colorScheme.primary : AppTheme.inkMuted,
                      ),
                      child: Text('${widget.count} 条'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpineMemoRow extends StatefulWidget {
  const _SpineMemoRow({
    required this.child,
    required this.showLineAbove,
    required this.showLineBelow,
  });

  final Widget child;
  final bool showLineAbove;
  final bool showLineBelow;

  @override
  State<_SpineMemoRow> createState() => _SpineMemoRowState();
}

class _SpineMemoRowState extends State<_SpineMemoRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    // Stack sizes to the card; spine is position-filled — no IntrinsicHeight.
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MemoFeedPanel.spineWidth,
            child: Column(
              children: [
                Expanded(
                  child: widget.showLineAbove
                      ? _SpineTrack(highlight: _hover)
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: widget.showLineBelow
                      ? _SpineTrack(highlight: _hover)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Positioned(
            left: (MemoFeedPanel.spineWidth - 14) / 2,
            top: 18,
            child: _SpineNode(hovered: _hover),
          ),
          AnimatedPadding(
            duration: AppTheme.motionFast,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              MemoFeedPanel.spineWidth + (_hover ? 6 : 2),
              6,
              8,
              10,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ─── Right-side continuous day axis ─────────────────────────────────────────

class _DayAxisNavigator extends StatefulWidget {
  const _DayAxisNavigator({
    required this.days,
    required this.groups,
    required this.onSelect,
  });

  final List<DateTime> days;
  final Map<DateTime, List<Memo>> groups;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayAxisNavigator> createState() => _DayAxisNavigatorState();
}

class _DayAxisNavigatorState extends State<_DayAxisNavigator> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.paperElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '时间轴',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '悬停高亮 · 点击跳转',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.inkMuted,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
              itemCount: widget.days.length,
              itemBuilder: (context, i) {
                final day = widget.days[i];
                final count = widget.groups[day]!.length;
                final hovered = _hoverIndex == i;
                final isFirst = i == 0;
                final isLast = i == widget.days.length - 1;

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverIndex = i),
                  onExit: (_) => setState(() => _hoverIndex = null),
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onSelect(day),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      hoverColor: Colors.transparent,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            // Continuous axis body
                            SizedBox(
                              width: 28,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Column(
                                    children: [
                                      Expanded(
                                        child: isFirst
                                            ? const SizedBox.shrink()
                                            : _SpineTrack(
                                                highlight: hovered ||
                                                    _hoverIndex == i - 1,
                                              ),
                                      ),
                                      Expanded(
                                        child: isLast
                                            ? const SizedBox.shrink()
                                            : _SpineTrack(
                                                highlight: hovered ||
                                                    _hoverIndex == i + 1,
                                              ),
                                      ),
                                    ],
                                  ),
                                  _SpineNode(hovered: hovered, large: true),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AnimatedContainer(
                                duration: AppTheme.motionFast,
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: hovered
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                transform: Matrix4.translationValues(
                                  hovered ? 3 : 0,
                                  0,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _dayTitle(day),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: hovered
                                            ? Theme.of(context).colorScheme.primary
                                            : AppTheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${DateFormat('yyyy/MM/dd').format(day)} · $count',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
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
  }
}

String _dayTitle(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return '今天';
  if (day == yesterday) return '昨天';
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final wd = weekdays[day.weekday - 1];
  if (day.year == now.year) return '${day.month}月${day.day}日 $wd';
  return '${day.year}年${day.month}月${day.day}日';
}

// ─── Preview + card ─────────────────────────────────────────────────────────

class _FeedPreview {
  const _FeedPreview({required this.text, required this.truncated});

  final String text;
  final bool truncated;

  static _FeedPreview build(String content, {int maxChars = 380}) {
    final text = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), '〔代码〕')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'🖼 $1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~`]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (text.isEmpty) {
      return const _FeedPreview(text: '（空笔记）', truncated: false);
    }
    if (text.length <= maxChars) {
      return _FeedPreview(text: text, truncated: false);
    }

    final head = text.substring(0, maxChars);
    final para = head.lastIndexOf('\n\n');
    final sentence = head.lastIndexOf(RegExp(r'[。！？.!?]'));
    final breakAt = para > maxChars * 0.55
        ? para
        : (sentence > maxChars * 0.55 ? sentence + 1 : maxChars);
    final cut = text.substring(0, breakAt).trimRight();
    return _FeedPreview(text: '$cut…', truncated: true);
  }
}

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({
    required this.memo,
    required this.excerpt,
    required this.truncated,
    required this.displayName,
    required this.onTap,
  });

  final Memo memo;
  final String excerpt;
  final bool truncated;
  final String displayName;
  final VoidCallback onTap;

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.memo;
    final visLabel = switch (m.visibility) {
      MemoVisibility.public => '公开',
      MemoVisibility.protected => '保护',
      MemoVisibility.private => '私有',
    };
    final visIcon = switch (m.visibility) {
      MemoVisibility.public => Icons.public_outlined,
      MemoVisibility.protected => Icons.lock_open_outlined,
      MemoVisibility.private => Icons.lock_outline,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppTheme.paperElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: _hover
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : AppTheme.line,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(name: widget.displayName, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ),
                                if (m.pinned) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _relativeTime(m.updatedAtLocal),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(visIcon, size: 14, color: AppTheme.inkSubtle),
                      const SizedBox(width: 3),
                      Text(
                        visLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.inkSubtle,
                        ),
                      ),
                      if (m.dirty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningSoft,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            '待同步',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.excerpt,
                    maxLines: MemoFeedPanel.previewMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      height: 1.55,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (m.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in m.tags.take(6))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              '#$t',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (widget.truncated) ...[
                    const SizedBox(height: 8),
                    Text(
                      '查看全文',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) {
      return '昨天 ${DateFormat('HH:mm').format(time)}';
    }
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    if (time.year == now.year) {
      return DateFormat('M月d日 HH:mm').format(time);
    }
    return DateFormat('yyyy/M/d HH:mm').format(time);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? 'M'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.line),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.inter(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
