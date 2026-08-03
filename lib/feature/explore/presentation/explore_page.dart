import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
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

/// Explore public memos on the connected instance.
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(activeWorkspaceProvider);
    final async = ref.watch(exploreRemoteProvider);
    final scheme = Theme.of(context).colorScheme;

    if (ws == null || !ws.isMemos) {
      return Center(
        child: Text(
          '连接 Memos 云端工作区后可使用 Explore',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                onPressed: () => ref.invalidate(exploreRemoteProvider),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final url = memosPublicUrl(base, m.name);
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: public link always visible
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.public, size: 16, color: scheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  url,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '复制',
                                icon: Icon(Icons.copy, size: 16, color: scheme.primary),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: url),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已复制公开链接')),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: '打开',
                                icon: Icon(Icons.open_in_new,
                                    size: 16, color: scheme.primary),
                                onPressed: () async {
                                  final uri = Uri.tryParse(url);
                                  if (uri != null) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.updateTime != null
                                    ? DateFormat('yyyy/MM/dd HH:mm')
                                        .format(m.updateTime!)
                                    : m.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              MarkdownBody(
                                data: m.content.isEmpty ? '*空*' : m.content,
                                selectable: true,
                              ),
                            ],
                          ),
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
