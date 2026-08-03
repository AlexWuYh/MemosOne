import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/memo.dart';

/// Timeline / feed view similar to Memos web home stream.
class MemoFeedPanel extends ConsumerWidget {
  const MemoFeedPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);
    final scheme = Theme.of(context).colorScheme;
    final selectedId = ref.watch(selectedMemoIdProvider);

    return memosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (memos) {
        if (memos.isEmpty) {
          return Center(
            child: Text(
              '信息流为空',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: memos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final m = memos[i];
            final selected = m.localId == selectedId;
            return Material(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : scheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ref.read(selectedMemoIdProvider.notifier).state = m.localId;
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (m.pinned)
                            Icon(Icons.push_pin, size: 14, color: scheme.primary),
                          if (m.pinned) const SizedBox(width: 6),
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm')
                                .format(m.updatedAtLocal),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          if (m.dirty)
                            Chip(
                              label: const Text('待同步'),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: scheme.onTertiaryContainer,
                              ),
                              backgroundColor: scheme.tertiaryContainer,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            m.visibility.name.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: m.content.isEmpty ? '*空笔记*' : m.content,
                        shrinkWrap: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                          p: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.45),
                        ),
                      ),
                      if (m.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: m.tags
                              .map(
                                (t) => ActionChip(
                                  label: Text('#$t'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    ref
                                        .read(memoFilterProvider.notifier)
                                        .state = MemoQuery(tag: t);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
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
