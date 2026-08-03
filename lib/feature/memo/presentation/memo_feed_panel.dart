import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/memo.dart';

/// Full-bleed feed: short previews only; tap opens full note.
class MemoFeedPanel extends ConsumerWidget {
  const MemoFeedPanel({super.key});

  static String _preview(String content, {int maxChars = 160}) {
    final flat = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[#>*_`\[\]!]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (flat.isEmpty) return '空笔记';
    if (flat.length <= maxChars) return flat;
    return '${flat.substring(0, maxChars).trimRight()}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);
    final scheme = Theme.of(context).colorScheme;

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          itemCount: memos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = memos[i];
            return Material(
              color: AppTheme.paperElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
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
                          if (m.pinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm')
                                .format(m.updatedAtLocal),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (m.dirty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '待同步',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          if (m.visibility == MemoVisibility.public) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.public,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _preview(m.content),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (m.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: m.tags
                              .take(6)
                              .map(
                                (t) => Text(
                                  '#$t',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '查看全文 →',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
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
