import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/memo_snippet_card.dart';
import '../../../domain/entities/memo.dart';

/// Focus node for Ctrl/Cmd+F from [HomeShell].
final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'memoSearch');
  ref.onDispose(node.dispose);
  return node;
});

class MemoListPanel extends ConsumerStatefulWidget {
  const MemoListPanel({
    super.key,
    this.onSelect,
    this.compact = false,
  });

  final ValueChanged<Memo>? onSelect;
  final bool compact;

  @override
  ConsumerState<MemoListPanel> createState() => _MemoListPanelState();
}

class _MemoListPanelState extends ConsumerState<MemoListPanel> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        if (!mounted) return;
        ref.read(searchQueryProvider.notifier).state = value;
      },
    );
  }

  Future<void> _openTagPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.paperElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => const _TagFilterSheet(),
    );
    if (!mounted) return;
    if (selected == null) return;
    if (selected.isEmpty) {
      ref.read(memoFilterProvider.notifier).state =
          ref.read(memoFilterProvider).copyWith(clearTag: true);
    } else {
      final cur = ref.read(memoFilterProvider);
      ref.read(memoFilterProvider.notifier).state = cur.copyWith(tag: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memosProvider);
    final selectedId = ref.watch(selectedMemoIdProvider);
    final search = ref.watch(searchQueryProvider);
    final filter = ref.watch(memoFilterProvider);
    final searchFocus = ref.watch(searchFocusNodeProvider);
    final tags = ref.watch(workspaceTagsProvider).valueOrNull ?? const [];

    if (search.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    // Status filters keep day/tag when possible.
    MemoQuery baseStatus() => MemoQuery(
          tag: filter.tag,
          day: filter.day,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: TextField(
            focusNode: searchFocus,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索笔记…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.isEmpty && _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        // Status filters only (tags live in dedicated control below).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _FilterPill(
                label: '全部',
                selected: !filter.onlyArchived &&
                    !filter.onlyPinned &&
                    !filter.onlyPublic,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    MemoQuery(tag: filter.tag, day: filter.day),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '置顶',
                selected: filter.onlyPinned,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    baseStatus().copyWith(onlyPinned: true),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '公开',
                selected: filter.onlyPublic,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    baseStatus().copyWith(onlyPublic: true),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '归档',
                selected: filter.onlyArchived,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    baseStatus().copyWith(onlyArchived: true),
              ),
            ],
          ),
        ),
        // Dedicated tag filter — searchable sheet when many tags.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: filter.tag == null
                    ? OutlinedButton.icon(
                        onPressed: tags.isEmpty
                            ? null
                            : () => _openTagPicker(context),
                        icon: const Icon(Icons.sell_outlined, size: 18),
                        label: Text(
                          tags.isEmpty ? '暂无标签' : '按标签筛选（${tags.length}）',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: AppTheme.ink,
                          side: const BorderSide(color: AppTheme.line),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      )
                    : InputChip(
                        backgroundColor: AppTheme.accentSoft,
                        side: BorderSide(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                        ),
                        deleteIconColor: AppTheme.accent,
                        avatar: const Icon(
                          Icons.sell_rounded,
                          size: 16,
                          color: AppTheme.accent,
                        ),
                        label: Text(
                          '#${filter.tag}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _openTagPicker(context),
                        onDeleted: () {
                          ref.read(memoFilterProvider.notifier).state =
                              filter.copyWith(clearTag: true);
                        },
                      ),
              ),
              if (filter.tag != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: '更换标签',
                  onPressed: () => _openTagPicker(context),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ],
          ),
        ),
        if (filter.day != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                backgroundColor: AppTheme.accentSoft,
                side: BorderSide(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                ),
                deleteIconColor: AppTheme.accent,
                label: Text(
                  '日期 ${filter.day!.year}-${filter.day!.month.toString().padLeft(2, '0')}-${filter.day!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppTheme.accent,
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
        const SizedBox(height: 4),
        Expanded(
          child: memosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('错误: $e')),
            data: (memos) {
              if (memos.isEmpty) {
                return AppEmptyState(
                  title: search.isEmpty ? '还没有笔记' : '没有匹配结果',
                  subtitle:
                      search.isEmpty ? '点击右上角「新建」快速记录' : '试试其他关键词或清除筛选',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: memos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final memo = memos[index];
                  final selected = memo.localId == selectedId;
                  return Material(
                    color: selected
                        ? AppTheme.accentSoft
                        : AppTheme.paperElevated,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      hoverColor: AppTheme.surfaceHover,
                      onTap: () {
                        ref.read(selectedMemoIdProvider.notifier).state =
                            memo.localId;
                        widget.onSelect?.call(memo);
                      },
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedContainer(
                              duration: AppTheme.motionFast,
                              width: 3,
                              color: selected
                                  ? AppTheme.accent
                                  : Colors.transparent,
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (memo.pinned)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: Icon(
                                              Icons.push_pin_outlined,
                                              size: 13,
                                              color: AppTheme.accent,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            memo.snippet,
                                            maxLines: widget.compact ? 2 : 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  height: 1.4,
                                                  color: AppTheme.ink,
                                                ),
                                          ),
                                        ),
                                        if (memo.dirty)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.warningSoft,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppTheme.radiusSm,
                                              ),
                                            ),
                                            child: const Text(
                                              '待同步',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.warning,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm')
                                              .format(memo.updatedAtLocal) +
                                          (memo.tags.isEmpty
                                              ? ''
                                              : '  ·  ${memo.tags.map((t) => '#$t').join(' ')}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: AppTheme.inkMuted),
                                    ),
                                  ],
                                ),
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
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.accentSoft,
      backgroundColor: AppTheme.surfaceMuted,
      side: BorderSide(
        color: selected ? AppTheme.accent.withValues(alpha: 0.35) : AppTheme.line,
      ),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 12,
        color: selected ? AppTheme.accent : AppTheme.inkMuted,
      ),
    );
  }
}

/// Searchable tag picker sheet. Returns selected tag name, empty string to clear,
/// or null if dismissed without choice.
class _TagFilterSheet extends ConsumerStatefulWidget {
  const _TagFilterSheet();

  @override
  ConsumerState<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends ConsumerState<_TagFilterSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(workspaceTagsProvider).valueOrNull ?? const [];
    final current = ref.watch(memoFilterProvider).tag;
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((t) => t.contains(q)).toList(growable: false);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Text(
                    '按标签筛选',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  if (current != null)
                    TextButton(
                      onPressed: () => Navigator.pop(context, ''),
                      child: const Text('清除'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索标签…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: all.isEmpty
                  ? const Center(child: Text('笔记中还没有 #标签'))
                  : filtered.isEmpty
                      ? const Center(child: Text('没有匹配的标签'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final t = filtered[i];
                            final selected = t == current;
                            return ListTile(
                              leading: Icon(
                                selected
                                    ? Icons.sell_rounded
                                    : Icons.sell_outlined,
                                color: selected
                                    ? AppTheme.accent
                                    : AppTheme.inkMuted,
                              ),
                              title: Text(
                                '#$t',
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.accent
                                      : AppTheme.ink,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: AppTheme.accent,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, t),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
