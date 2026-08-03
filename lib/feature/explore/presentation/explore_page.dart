import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
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
    final ws = ref.watch(activeWorkspaceProvider);
    final async = ref.watch(exploreRemoteProvider);
    final selected = ref.watch(exploreSelectedProvider);
    final scheme = Theme.of(context).colorScheme;

    if (ws == null || !ws.isMemos) {
      return Center(
        child: Text(
          '连接 Memos 云端工作区后可使用 Explore',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
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
                return Center(
                  child: Text(
                    '暂无公开笔记',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
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
                  return Material(
                    color: AppTheme.paperElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          ref.read(exploreSelectedProvider.notifier).state = m,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.updateTime != null
                                      ? DateFormat('yyyy/MM/dd HH:mm')
                                          .format(m.updateTime!)
                                      : m.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: '复制公开链接',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.link,
                                    size: 16,
                                    color: scheme.primary,
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: url),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制公开链接'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _preview(m.content),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    height: 1.45,
                                    color: AppTheme.ink,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
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
          child: Markdown(
            data: memo.content.isEmpty ? '*空笔记*' : memo.content,
            selectable: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
              h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
