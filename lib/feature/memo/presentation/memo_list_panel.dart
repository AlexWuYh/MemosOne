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

    // Keep field in sync when cleared externally.
    if (search.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            focusNode: searchFocus,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search memos…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isEmpty && _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Active'),
                selected: !filter.onlyArchived && !filter.onlyPinned,
                onSelected: (_) {
                  ref.read(memoFilterProvider.notifier).state =
                      const MemoQuery();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Pinned'),
                selected: filter.onlyPinned,
                onSelected: (_) {
                  ref.read(memoFilterProvider.notifier).state =
                      const MemoQuery(onlyPinned: true);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Archived'),
                selected: filter.onlyArchived,
                onSelected: (_) {
                  ref.read(memoFilterProvider.notifier).state =
                      const MemoQuery(onlyArchived: true);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: memosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (memos) {
              if (memos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      search.isEmpty
                          ? 'No memos yet.\nTap + to create one.'
                          : 'No matches.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: memos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final memo = memos[index];
                  final selected = memo.localId == selectedId;
                  return ListTile(
                    selected: selected,
                    leading: Icon(
                      memo.pinned ? Icons.push_pin : Icons.notes_outlined,
                      size: 20,
                    ),
                    title: Text(
                      memo.snippet,
                      maxLines: widget.compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DateFormat.yMMMd().add_Hm().format(memo.updatedAtLocal) +
                          (memo.dirty ? ' · pending sync' : '') +
                          (memo.tags.isEmpty
                              ? ''
                              : ' · ${memo.tags.map((String t) => '#$t').join(' ')}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      ref.read(selectedMemoIdProvider.notifier).state =
                          memo.localId;
                      widget.onSelect?.call(memo);
                    },
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
