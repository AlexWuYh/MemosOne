import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/memo_snippet_card.dart';
import '../../../domain/entities/memo.dart';
import '../../../infrastructure/network/memos/memos_api_client.dart';

final exploreRemoteProvider =
    FutureProvider.autoDispose<List<RemoteMemoDto>>((ref) async {
  final ws = ref.watch(activeWorkspaceProvider);
  if (ws == null || !ws.isMemos || ws.serverBaseUrl == null) {
    return const [];
  }
  final token =
      await ref.watch(authRepositoryProvider).readToken(ws.localId);
  final client = MemosApiClient.forWorkspace(ws, token: token);
  return client.listPublicMemos();
});

/// Selected public memo in Explore (full-bleed after tap).
final exploreSelectedProvider =
    StateProvider.autoDispose<RemoteMemoDto?>((ref) => null);

/// Explore: feed-style short cards → full-bleed detail (like 信息流).
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(activeWorkspaceProvider);
    final async = ref.watch(exploreRemoteProvider);
    final selected = ref.watch(exploreSelectedProvider);

    if (ws == null || !ws.isMemos) {
      return const AppEmptyState(
        title: '连接云端后使用 Explore',
        subtitle: 'Explore 展示当前 Memos 实例上的公开笔记。',
        icon: Icons.public_outlined,
      );
    }

    if (selected != null) {
      return _ExploreDetail(
        memo: selected,
        baseUrl: ws.serverBaseUrl ?? '',
        onBack: () => ref.read(exploreSelectedProvider.notifier).state = null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Text(
                'Explore · 公开笔记',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: () {
                  ref.read(exploreSelectedProvider.notifier).state = null;
                  ref.invalidate(exploreRemoteProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载公开笔记失败：\n$e\n\n可先登录后再试，或确认服务器允许列出 PUBLIC 笔记。',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const AppEmptyState(
                  title: '暂无公开笔记',
                  subtitle: '把笔记可见性设为 PUBLIC 后会出现在这里。',
                  icon: Icons.public_outlined,
                );
              }
              final base = ws.serverBaseUrl ?? '';
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final url = memosPublicUrl(base, m.name);
                  return MemoSnippetCard(
                    preview: MemoSnippetCard.flattenPreview(m.content),
                    timestamp: m.updateTime,
                    isPublic: true,
                    onTap: () =>
                        ref.read(exploreSelectedProvider.notifier).state = m,
                    leadingMeta: Row(
                      children: [
                        const Icon(
                          Icons.public,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m.updateTime != null
                                ? DateFormat('yyyy/MM/dd HH:mm')
                                    .format(m.updateTime!)
                                : m.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '复制公开链接',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.link,
                            size: 16,
                            color: AppTheme.accent,
                          ),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已复制公开链接')),
                              );
                            }
                          },
                        ),
                      ],
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

class _ExploreDetail extends StatelessWidget {
  const _ExploreDetail({
    required this.memo,
    required this.baseUrl,
    required this.onBack,
  });

  final RemoteMemoDto memo;
  final String baseUrl;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = memosPublicUrl(baseUrl, memo.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  memo.updateTime != null
                      ? DateFormat('yyyy/MM/dd HH:mm').format(memo.updateTime!)
                      : '公开笔记',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: '浏览器打开',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
        Material(
          color: AppTheme.accentSoft.withValues(alpha: 0.65),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  '公开链接',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制',
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.accent),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制公开链接')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        Expanded(
          child: ReadingWidth(
            child: Markdown(
              data: memo.content.isEmpty ? '*空笔记*' : memo.content,
              selectable: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      fontSize: 15.5,
                    ),
                h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
