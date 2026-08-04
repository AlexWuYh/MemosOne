import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/memo_snippet_card.dart';
import '../../../domain/entities/memo.dart';

/// Full-bleed feed: short previews only; tap opens full note.
class MemoFeedPanel extends ConsumerWidget {
  const MemoFeedPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);

    return memosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (memos) {
        if (memos.isEmpty) {
          return AppEmptyState(
            title: '信息流为空',
            subtitle: '新建一条笔记，或切换到笔记视图浏览全部内容。',
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
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          itemCount: memos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = memos[i];
            return MemoSnippetCard(
              preview: MemoSnippetCard.flattenPreview(m.content),
              timestamp: m.updatedAtLocal,
              pinned: m.pinned,
              dirty: m.dirty,
              isPublic: m.visibility == MemoVisibility.public,
              tags: m.tags,
              onTap: () {
                ref.read(selectedMemoIdProvider.notifier).state = m.localId;
              },
            );
          },
        );
      },
    );
  }
}
