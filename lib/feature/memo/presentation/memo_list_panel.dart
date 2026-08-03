import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
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

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memosProvider);
    final selectedId = ref.watch(selectedMemoIdProvider);
    final search = ref.watch(searchQueryProvider);
    final filter = ref.watch(memoFilterProvider);
    final searchFocus = ref.watch(searchFocusNodeProvider);
    final scheme = Theme.of(context).colorScheme;

    if (search.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _FilterPill(
                label: '全部',
                selected: !filter.onlyArchived && !filter.onlyPinned,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    const MemoQuery(),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '置顶',
                selected: filter.onlyPinned,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    const MemoQuery(onlyPinned: true),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '归档',
                selected: filter.onlyArchived,
                onTap: () => ref.read(memoFilterProvider.notifier).state =
                    const MemoQuery(onlyArchived: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: memosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('错误: $e')),
            data: (memos) {
              if (memos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 48,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          search.isEmpty ? '还没有笔记' : '没有匹配结果',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          search.isEmpty ? '点击右上角 + 快速记录' : '试试其他关键词',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
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
                        ? scheme.primaryContainer.withValues(alpha: 0.55)
                        : scheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.35)
                            : scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        ref.read(selectedMemoIdProvider.notifier).state =
                            memo.localId;
                        widget.onSelect?.call(memo);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (memo.pinned)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.push_pin_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    memo.snippet,
                                    maxLines: widget.compact ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                  ),
                                ),
                                if (memo.dirty)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '待同步',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: scheme.onTertiaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
    );
  }
}
