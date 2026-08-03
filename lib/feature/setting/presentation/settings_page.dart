import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/workspace.dart';
import '../../workspace/presentation/workspace_dialogs.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final syncPrefs = ref.watch(syncPrefsProvider);
    final deadAsync = active == null || !active.isMemos
        ? null
        : ref.watch(syncServiceProvider).listDeadTasks(active.localId);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            AppConstants.appTagline,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('外观'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setMode(s.first),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              AppTheme.defaultSeed,
              const Color(0xFF0D9488),
              const Color(0xFFEA580C),
              const Color(0xFFDB2777),
              const Color(0xFF475569),
            ]
                .map(
                  (c) => ChoiceChip(
                    label: const SizedBox(width: 14, height: 14),
                    selected: accent.toARGB32() == c.toARGB32(),
                    selectedColor: c,
                    backgroundColor: c.withValues(alpha: 0.35),
                    onSelected: (_) =>
                        ref.read(accentColorProvider.notifier).setColor(c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          _SectionTitle('同步（云端优先 · 离线可写）'),
          const SizedBox(height: 4),
          Text(
            '本地缓存为阅读/编辑入口；网络可用时按策略与 Memos 服务器同步。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('打开时自动同步'),
            subtitle: const Text('启动或进入工作区后立即全量同步'),
            value: syncPrefs.syncOnLaunch,
            onChanged: (v) =>
                ref.read(syncPrefsProvider.notifier).setSyncOnLaunch(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('退出时自动同步'),
            subtitle: const Text('关闭窗口前尽量推送本地更改并拉取'),
            value: syncPrefs.syncOnExit,
            onChanged: (v) =>
                ref.read(syncPrefsProvider.notifier).setSyncOnExit(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('网络恢复后自动同步'),
            value: syncPrefs.syncOnReconnect,
            onChanged: (v) =>
                ref.read(syncPrefsProvider.notifier).setSyncOnReconnect(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('定时同步'),
            subtitle: Text('每隔 ${syncPrefs.syncIntervalMinutes} 分钟全量拉取'),
            value: syncPrefs.periodicSyncEnabled,
            onChanged: (v) => ref
                .read(syncPrefsProvider.notifier)
                .setPeriodicSyncEnabled(v),
          ),
          if (syncPrefs.periodicSyncEnabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('同步间隔（分钟）'),
              subtitle: Slider(
                value: syncPrefs.syncIntervalMinutes.toDouble().clamp(1, 120),
                min: 1,
                max: 120,
                divisions: 23,
                label: '${syncPrefs.syncIntervalMinutes}',
                onChanged: (v) => ref
                    .read(syncPrefsProvider.notifier)
                    .setSyncIntervalMinutes(v.round()),
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle('工作区'),
          if (active == null)
            const ListTile(title: Text('尚未连接'))
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(active.name),
              subtitle: Text(
                active.isLocal
                    ? '纯本地 · 不会上传'
                    : '${active.serverBaseUrl}\n${active.username ?? '未登录'}',
              ),
              isThreeLine: !active.isLocal,
            ),
            if (active.isMemos) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login_rounded),
                title: const Text('重新登录'),
                onTap: () => showLoginDialog(context, ref, active),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('退出登录'),
                onTap: () async {
                  await ref.read(authRepositoryProvider).logout(active);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已退出登录')),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_rounded),
                title: const Text('立即同步'),
                onTap: () => ref.read(syncServiceProvider).syncNow(active),
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('删除工作区'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除工作区？'),
                    content: const Text('本地缓存将被清除，无法撤销。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(workspaceRepositoryProvider)
                      .delete(active.localId, wipeData: true);
                  await ref
                      .read(activeWorkspaceIdProvider.notifier)
                      .select(null);
                  await ref
                      .read(preferencesStoreProvider)
                      .setOnboardingDone(false);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
          const SizedBox(height: 20),
          _SectionTitle('同步失败任务'),
          if (deadAsync == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('仅云端工作区有此列表'),
            )
          else
            FutureBuilder(
              future: deadAsync,
              builder: (context, snap) {
                final tasks = snap.data ?? const [];
                if (tasks.isEmpty) {
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('无失败任务'),
                  );
                }
                return Column(
                  children: tasks
                      .map(
                        (t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${t.action.name} ${t.entityLocalId}'),
                          subtitle: Text(t.lastError ?? ''),
                          trailing: TextButton(
                            onPressed: () async {
                              final ws = active;
                              if (ws == null) return;
                              await ref
                                  .read(syncServiceProvider)
                                  .retryDeadTask(t.id);
                              if (ws.authState == WorkspaceAuthState.ok) {
                                await ref
                                    .read(syncServiceProvider)
                                    .syncNow(ws);
                              }
                            },
                            child: const Text('重试'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 20),
          _SectionTitle('快捷键'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('⌘/Ctrl + N'),
            subtitle: Text('新建笔记'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('⌘/Ctrl + F'),
            subtitle: Text('聚焦搜索'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('⌘/Ctrl + S'),
            subtitle: Text('立即同步'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
