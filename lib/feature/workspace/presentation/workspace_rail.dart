import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/entities/workspace.dart';
import '../../setting/presentation/settings_page.dart';
import 'workspace_dialogs.dart';

class WorkspaceRail extends ConsumerWidget {
  const WorkspaceRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: AppTheme.paperElevated,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 10),
              child: Text(
                '工作区',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: workspaces.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '连接 Memos 后，笔记会缓存在本地并可离线编辑。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final ws = list[i];
                      final selected = ws.localId == active?.localId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          selected: selected,
                          selectedTileColor:
                              scheme.primaryContainer.withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(
                            ws.isLocal
                                ? Icons.folder_outlined
                                : Icons.cloud_outlined,
                          ),
                          title: Text(
                            ws.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            ws.isLocal
                                ? '仅本地'
                                : (ws.username ?? ws.serverBaseUrl ?? 'Memos'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            await ref
                                .read(activeWorkspaceIdProvider.notifier)
                                .select(ws.localId);
                            await ref
                                .read(workspaceRepositoryProvider)
                                .markOpened(ws.localId);
                            ref.read(selectedMemoIdProvider.notifier).state =
                                null;
                            if (ws.isMemos) {
                              await ref.read(syncServiceProvider).start(ws);
                              final prefs = ref.read(syncPrefsProvider);
                              if (prefs.syncOnLaunch &&
                                  ws.authState == WorkspaceAuthState.ok) {
                                await ref
                                    .read(syncServiceProvider)
                                    .syncNow(ws);
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (active?.isMemos == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _SyncBadge(snapshot: sync, workspace: active!),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('添加工作区'),
              onTap: () => showCreateWorkspaceDialog(context, ref),
            ),
            if (active?.isMemos == true &&
                active?.authState != WorkspaceAuthState.ok)
              ListTile(
                leading: Icon(
                  Icons.login_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '登录',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('当前未登录，点此输入账号/Token'),
                onTap: () {
                  final ws = active;
                  if (ws == null) return;
                  showLoginDialog(context, ref, ws);
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends ConsumerWidget {
  const _SyncBadge({required this.snapshot, required this.workspace});

  final SyncStatusSnapshot? snapshot;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot ?? const SyncStatusSnapshot.idle();
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (s.state) {
      GlobalSyncState.syncing => (
          Icons.sync_rounded,
          '同步中…',
          scheme.primary
        ),
      GlobalSyncState.offline => (
          Icons.cloud_off_rounded,
          '离线可编辑',
          scheme.outline
        ),
      GlobalSyncState.authRequired => (
          Icons.lock_outline,
          '需要重新登录',
          scheme.error
        ),
      GlobalSyncState.error => (
          Icons.error_outline,
          s.lastError ?? '同步错误',
          scheme.error
        ),
      GlobalSyncState.idle => (
          Icons.cloud_done_outlined,
          s.pendingCount > 0 ? '${s.pendingCount} 条待同步' : '已与云端同步',
          scheme.primary
        ),
    };
    final last = s.lastPullAt;
    final lastLine =
        last == null ? '尚未完成全量同步' : '上次同步 ${_ago(last)}';
    final deadLine = s.deadCount > 0 ? ' · ${s.deadCount} 失败' : '';
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$lastLine$deadLine',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: '立即同步',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () =>
              ref.read(syncServiceProvider).syncNow(workspace),
        ),
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
