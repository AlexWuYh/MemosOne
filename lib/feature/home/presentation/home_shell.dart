import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/entities/workspace.dart';
import '../../memo/presentation/memo_detail_panel.dart';
import '../../memo/presentation/memo_list_panel.dart';
import '../../workspace/presentation/workspace_rail.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _newMemo(WidgetRef ref) async {
    final ws = ref.read(activeWorkspaceProvider);
    if (ws == null) return;
    final memo = await ref.read(memoRepositoryProvider).create(
          ws.localId,
          const NewMemo(content: ''),
        );
    ref.read(selectedMemoIdProvider.notifier).state = memo.localId;
  }

  void _openWorkspaces(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SizedBox(
        height: 520,
        child: WorkspaceRail(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final isMedium = width >= 700 && width < 960;
    final selectedId = ref.watch(selectedMemoIdProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _newMemo(ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _newMemo(ref),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          ref.read(searchFocusNodeProvider).requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          ref.read(searchFocusNodeProvider).requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          final ws = ref.read(activeWorkspaceProvider);
          if (ws != null && ws.isMemos) {
            ref.read(syncServiceProvider).syncNow(ws);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          final ws = ref.read(activeWorkspaceProvider);
          if (ws != null && ws.isMemos) {
            ref.read(syncServiceProvider).syncNow(ws);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active?.name ?? 'Memos One'),
                if (active != null)
                  Text(
                    active.isMemos
                        ? (active.serverBaseUrl ?? 'Memos')
                        : '本地工作区',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            leading: (!isWide && active != null)
                ? IconButton(
                    tooltip: '工作区',
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => _openWorkspaces(context),
                  )
                : null,
            actions: [
              if (active?.isMemos == true) ...[
                _SyncChip(snapshot: sync, workspace: active!),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: '新建笔记',
                onPressed: active == null ? null : () => _newMemo(ref),
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          floatingActionButton: (!isWide && active != null)
              ? FloatingActionButton.extended(
                  onPressed: () => _newMemo(ref),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('写笔记'),
                )
              : null,
          body: active == null
              ? const Center(child: Text('请在工作区中连接 Memos'))
              : isWide
                  ? const Row(
                      children: [
                        SizedBox(width: 268, child: WorkspaceRail()),
                        VerticalDivider(width: 1),
                        SizedBox(width: 340, child: MemoListPanel()),
                        VerticalDivider(width: 1),
                        Expanded(child: MemoDetailPanel()),
                      ],
                    )
                  : isMedium
                      ? Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Material(
                                color: scheme.surfaceContainerLowest,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    IconButton(
                                      tooltip: '工作区',
                                      icon: const Icon(Icons.workspaces_outline),
                                      onPressed: () => _openWorkspaces(context),
                                    ),
                                    IconButton(
                                      tooltip: '搜索',
                                      icon: const Icon(Icons.search_rounded),
                                      onPressed: () => ref
                                          .read(searchFocusNodeProvider)
                                          .requestFocus(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            const SizedBox(
                              width: 300,
                              child: MemoListPanel(compact: true),
                            ),
                            const VerticalDivider(width: 1),
                            const Expanded(child: MemoDetailPanel()),
                          ],
                        )
                      : selectedId == null
                          ? const MemoListPanel()
                          : const MemoDetailPanel(showBack: true),
        ),
      ),
    );
  }
}

class _SyncChip extends ConsumerWidget {
  const _SyncChip({required this.snapshot, required this.workspace});

  final SyncStatusSnapshot? snapshot;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot ?? const SyncStatusSnapshot.idle();
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (s.state) {
      GlobalSyncState.syncing => (Icons.sync_rounded, '同步中'),
      GlobalSyncState.offline => (Icons.cloud_off_rounded, '离线'),
      GlobalSyncState.authRequired => (Icons.lock_outline, '需登录'),
      GlobalSyncState.error => (Icons.error_outline, '同步异常'),
      GlobalSyncState.idle => (
          Icons.cloud_done_outlined,
          s.pendingCount > 0 ? '${s.pendingCount} 待同步' : '已同步',
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: scheme.primary),
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.read(syncServiceProvider).syncNow(workspace),
        tooltip: s.lastPullAt == null
            ? '点击立即同步'
            : '上次同步 ${_ago(s.lastPullAt!)} · 点击立即同步',
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    return '${d.inDays} 天前';
  }
}
