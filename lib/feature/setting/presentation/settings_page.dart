import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/entities/workspace.dart';
import '../../../infrastructure/network/memos/memos_api_client.dart';
import '../../workspace/presentation/workspace_dialogs.dart';

enum _SettingsSection {
  appearance,
  memo,
  sync,
  workspace,
  account,
  about,
}

/// Redesigned settings: sectioned shell, card surfaces, sync health compact.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.appearance;

  static String _visibilityLabel(MemoVisibility v) => switch (v) {
        MemoVisibility.private => '私有',
        MemoVisibility.protected => '保护',
        MemoVisibility.public => '公开',
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final syncPrefs = ref.watch(syncPrefsProvider);
    final defaultVis = ref.watch(defaultVisibilityProvider);
    final doubleClick = ref.watch(doubleClickToEditProvider);
    final syncSnap = ref.watch(syncStatusProvider).valueOrNull;
    final loggedIn = active?.isMemos == true &&
        active?.authState == WorkspaceAuthState.ok;

    final nav = _SettingsNav(
      section: _section,
      onSelect: (s) => setState(() => _section = s),
      showAccount: active?.isMemos == true,
      deadCount: syncSnap?.deadCount ?? 0,
    );

    final body = switch (_section) {
      _SettingsSection.appearance => _AppearancePane(
          themeMode: themeMode,
          accent: accent,
        ),
      _SettingsSection.memo => _MemoPrefsPane(
          defaultVis: defaultVis,
          doubleClick: doubleClick,
          visibilityLabel: _visibilityLabel,
        ),
      _SettingsSection.sync => _SyncPane(
          syncPrefs: syncPrefs,
          snap: syncSnap,
          workspace: active,
          loggedIn: loggedIn,
        ),
      _SettingsSection.workspace => _WorkspacePane(active: active),
      _SettingsSection.account => _AccountPane(
          workspace: active,
          loggedIn: loggedIn,
        ),
      _SettingsSection.about => const _AboutPane(),
    };

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: AppTheme.paper,
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 220, child: nav),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: body,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 52, child: nav),
                const Divider(height: 1),
                Expanded(child: body),
              ],
            ),
    );
  }
}

// ─── Nav ─────────────────────────────────────────────────────────────────────

class _SettingsNav extends StatelessWidget {
  const _SettingsNav({
    required this.section,
    required this.onSelect,
    required this.showAccount,
    required this.deadCount,
  });

  final _SettingsSection section;
  final ValueChanged<_SettingsSection> onSelect;
  final bool showAccount;
  final int deadCount;

  @override
  Widget build(BuildContext context) {
    final items = <(_SettingsSection, IconData, String)>[
      (_SettingsSection.appearance, Icons.palette_outlined, '外观'),
      (_SettingsSection.memo, Icons.edit_note_rounded, '笔记'),
      (_SettingsSection.sync, Icons.sync_rounded, '同步'),
      (_SettingsSection.workspace, Icons.folder_outlined, '工作区'),
      if (showAccount) (_SettingsSection.account, Icons.person_outline, '账户'),
      (_SettingsSection.about, Icons.info_outline, '关于'),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 860;
    if (!isWide) {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final (s, icon, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(icon, size: 16),
                label: Text(
                  s == _SettingsSection.sync && deadCount > 0
                      ? '$label · $deadCount'
                      : label,
                ),
                selected: section == s,
                onSelected: (_) => onSelect(s),
              ),
            ),
        ],
      );
    }

    return Material(
      color: AppTheme.paperElevated,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
          for (final (s, icon, label) in items)
            _NavTile(
              icon: icon,
              label: label,
              selected: section == s,
              badge: s == _SettingsSection.sync && deadCount > 0
                  ? '$deadCount'
                  : null,
              onTap: () => onSelect(s),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppTheme.accent : AppTheme.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.accent : AppTheme.ink,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared chrome ───────────────────────────────────────────────────────────

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.inkMuted,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.title, this.child, this.children});

  final String title;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.paperElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
                color: AppTheme.inkMuted,
              ),
            ),
          ),
          if (child != null) child!,
          if (children != null) ...children!,
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── Panes ───────────────────────────────────────────────────────────────────

class _AppearancePane extends ConsumerWidget {
  const _AppearancePane({required this.themeMode, required this.accent});

  final ThemeMode themeMode;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pane(
      title: '外观',
      subtitle: '主题与强调色。仅影响本机客户端，不会改服务器设置。',
      child: Column(
        children: [
          _CardBlock(
            title: '主题',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('系统'),
                    icon: Icon(Icons.brightness_auto, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('浅色'),
                    icon: Icon(Icons.light_mode_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('深色'),
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).setMode(s.first),
              ),
            ),
          ),
          _CardBlock(
            title: '强调色',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppTheme.defaultSeed,
                  AppTheme.accent,
                  const Color(0xFF0D9488),
                  const Color(0xFFEA580C),
                  const Color(0xFFDB2777),
                  const Color(0xFF475569),
                ].map((c) {
                  final selected = accent.toARGB32() == c.toARGB32();
                  return InkWell(
                    onTap: () =>
                        ref.read(accentColorProvider.notifier).setColor(c),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppTheme.ink : AppTheme.line,
                          width: selected ? 2.5 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoPrefsPane extends ConsumerWidget {
  const _MemoPrefsPane({
    required this.defaultVis,
    required this.doubleClick,
    required this.visibilityLabel,
  });

  final MemoVisibility defaultVis;
  final bool doubleClick;
  final String Function(MemoVisibility) visibilityLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pane(
      title: '笔记',
      subtitle: '对应 Web「偏好」中的新建默认项与编辑手势。',
      child: _CardBlock(
        title: '默认行为',
        children: [
          ListTile(
            title: const Text('新建笔记可见性'),
            subtitle: Text(visibilityLabel(defaultVis)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showModalBottomSheet<MemoVisibility>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final v in MemoVisibility.values)
                        ListTile(
                          title: Text(visibilityLabel(v)),
                          subtitle: Text(v.name.toUpperCase()),
                          trailing: v == defaultVis
                              ? const Icon(Icons.check, color: AppTheme.accent)
                              : null,
                          onTap: () => Navigator.pop(ctx, v),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null) {
                await ref
                    .read(defaultVisibilityProvider.notifier)
                    .setVisibility(picked);
              }
            },
          ),
          SwitchListTile(
            title: const Text('双击预览进入编辑'),
            subtitle: const Text('也可使用工具栏「编辑」按钮'),
            value: doubleClick,
            onChanged: (v) =>
                ref.read(doubleClickToEditProvider.notifier).setEnabled(v),
          ),
        ],
      ),
    );
  }
}

class _SyncPane extends ConsumerWidget {
  const _SyncPane({
    required this.syncPrefs,
    required this.snap,
    required this.workspace,
    required this.loggedIn,
  });

  final SyncPrefs syncPrefs;
  final SyncStatusSnapshot? snap;
  final Workspace? workspace;
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = snap?.pendingCount ?? 0;
    final dead = snap?.deadCount ?? 0;
    final state = snap?.state ?? GlobalSyncState.idle;
    final err = snap?.lastError;

    return _Pane(
      title: '同步',
      subtitle: '本地优先写入；联网后按策略与 Memos 对齐。',
      child: Column(
        children: [
          // Health summary — not a wall of tasks
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.paperElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dead > 0
                    ? AppTheme.danger.withValues(alpha: 0.35)
                    : AppTheme.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      dead > 0
                          ? Icons.error_outline
                          : state == GlobalSyncState.syncing
                              ? Icons.sync
                              : Icons.cloud_done_outlined,
                      color: dead > 0 ? AppTheme.danger : AppTheme.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dead > 0
                            ? '$dead 条同步失败'
                            : pending > 0
                                ? '$pending 条待推送'
                                : state == GlobalSyncState.offline
                                    ? '离线 · 可继续编辑'
                                    : state == GlobalSyncState.authRequired
                                        ? '需要重新登录'
                                        : state == GlobalSyncState.syncing
                                            ? '同步中…'
                                            : '已与云端同步',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (workspace?.isMemos == true)
                      FilledButton.tonal(
                        onPressed: !loggedIn
                            ? null
                            : () => ref
                                .read(syncServiceProvider)
                                .syncNow(workspace!),
                        child: const Text('立即同步'),
                      ),
                  ],
                ),
                if (err != null && err.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    err,
                    style: TextStyle(
                      color: AppTheme.danger.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (snap?.lastPullAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '上次拉取：${snap!.lastPullAt}',
                    style: const TextStyle(
                      color: AppTheme.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (dead > 0 && workspace != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: !loggedIn
                            ? null
                            : () async {
                                await ref
                                    .read(syncServiceProvider)
                                    .retryAllDeadTasks(workspace!.localId);
                                await ref
                                    .read(syncServiceProvider)
                                    .syncNow(workspace!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已重试失败任务'),
                                    ),
                                  );
                                }
                              },
                        child: const Text('全部重试'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(syncServiceProvider)
                              .clearDeadTasks(workspace!.localId);
                          // Force status refresh via sync emit
                          if (loggedIn) {
                            await ref
                                .read(syncServiceProvider)
                                .syncNow(workspace!);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已清空失败列表')),
                            );
                          }
                        },
                        child: const Text('清空列表'),
                      ),
                      TextButton(
                        onPressed: () => _showDeadSheet(context, ref),
                        child: const Text('查看详情'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _CardBlock(
            title: '自动同步',
            children: [
              SwitchListTile(
                title: const Text('打开时同步'),
                value: syncPrefs.syncOnLaunch,
                onChanged: (v) =>
                    ref.read(syncPrefsProvider.notifier).setSyncOnLaunch(v),
              ),
              SwitchListTile(
                title: const Text('退出时同步'),
                value: syncPrefs.syncOnExit,
                onChanged: (v) =>
                    ref.read(syncPrefsProvider.notifier).setSyncOnExit(v),
              ),
              SwitchListTile(
                title: const Text('网络恢复后同步'),
                value: syncPrefs.syncOnReconnect,
                onChanged: (v) =>
                    ref.read(syncPrefsProvider.notifier).setSyncOnReconnect(v),
              ),
              SwitchListTile(
                title: const Text('定时全量拉取'),
                subtitle: Text('每 ${syncPrefs.syncIntervalMinutes} 分钟'),
                value: syncPrefs.periodicSyncEnabled,
                onChanged: (v) => ref
                    .read(syncPrefsProvider.notifier)
                    .setPeriodicSyncEnabled(v),
              ),
              if (syncPrefs.periodicSyncEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Text('间隔'),
                      Expanded(
                        child: Slider(
                          value: syncPrefs.syncIntervalMinutes
                              .toDouble()
                              .clamp(1, 120),
                          min: 1,
                          max: 120,
                          divisions: 23,
                          label: '${syncPrefs.syncIntervalMinutes} 分',
                          onChanged: (v) => ref
                              .read(syncPrefsProvider.notifier)
                              .setSyncIntervalMinutes(v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDeadSheet(BuildContext context, WidgetRef ref) async {
    final ws = workspace;
    if (ws == null) return;
    final tasks =
        await ref.read(syncServiceProvider).listDeadTasks(ws.localId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '失败任务（${tasks.length}）',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('无失败任务'))
                    : ListView.separated(
                        itemCount: tasks.length.clamp(0, 50),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final t = tasks[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${t.action.name} · ${t.entityLocalId.substring(0, 8)}…',
                            ),
                            subtitle: Text(
                              t.lastError ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(syncServiceProvider)
                                    .retryDeadTask(t.id);
                                if (loggedIn) {
                                  await ref
                                      .read(syncServiceProvider)
                                      .syncNow(ws);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('重试'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspacePane extends ConsumerWidget {
  const _WorkspacePane({required this.active});

  final Workspace? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pane(
      title: '工作区',
      subtitle: '当前连接与本地缓存管理。',
      child: active == null
          ? const _CardBlock(
              title: '状态',
              child: ListTile(title: Text('尚未连接工作区')),
            )
          : Column(
              children: [
                _CardBlock(
                  title: '当前工作区',
                  children: [
                    ListTile(
                      title: Text(active!.name),
                      subtitle: Text(
                        active!.isLocal
                            ? '纯本地 · 不会上传'
                            : '${active!.serverBaseUrl}\n${active!.username ?? '未登录'}',
                      ),
                      isThreeLine: !active!.isLocal,
                    ),
                    if (active!.isMemos && active!.serverBaseUrl != null)
                      ListTile(
                        leading: const Icon(Icons.open_in_browser_rounded),
                        title: const Text('在浏览器打开'),
                        onTap: () async {
                          final uri = Uri.tryParse(active!.serverBaseUrl!);
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
                _CardBlock(
                  title: '危险操作',
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppTheme.danger,
                      ),
                      title: const Text('删除工作区'),
                      subtitle: const Text('清除本地缓存，不可撤销'),
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
                              .delete(active!.localId, wipeData: true);
                          await ref
                              .read(activeWorkspaceIdProvider.notifier)
                              .select(null);
                          await ref
                              .read(onboardingDoneProvider.notifier)
                              .reset();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AccountPane extends ConsumerWidget {
  const _AccountPane({required this.workspace, required this.loggedIn});

  final Workspace? workspace;
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspace == null || !workspace!.isMemos) {
      return const _Pane(
        title: '账户',
        subtitle: '连接 Memos 云端工作区后可管理账户。',
        child: _CardBlock(
          title: '提示',
          child: ListTile(title: Text('当前不是云端工作区')),
        ),
      );
    }

    return _Pane(
      title: '账户',
      subtitle: '登录后可查看服务器资料；改密与 Access Token 请在 Web 设置中操作。',
      child: !loggedIn
          ? _CardBlock(
              title: '未登录',
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppTheme.danger),
                  title: const Text('需要登录才能同步'),
                  trailing: FilledButton(
                    onPressed: () =>
                        showLoginDialog(context, ref, workspace!),
                    child: const Text('登录'),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _AccountCard(workspace: workspace!),
                _CardBlock(
                  title: '会话',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.login_rounded),
                      title: const Text('重新登录 / 更换 Token'),
                      onTap: () => showLoginDialog(context, ref, workspace!),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('退出登录'),
                      onTap: () async {
                        await ref
                            .read(authRepositoryProvider)
                            .logout(workspace!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已退出登录')),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.key_rounded),
                      title: const Text('管理 Access Token'),
                      subtitle: const Text('在服务器 Web 设置中创建，再回客户端登录'),
                      onTap: () async {
                        final base = workspace!.serverBaseUrl;
                        if (base == null) return;
                        final uri = Uri.tryParse('$base/setting');
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
              ],
            ),
    );
  }
}

class _AboutPane extends StatelessWidget {
  const _AboutPane();

  @override
  Widget build(BuildContext context) {
    return _Pane(
      title: '关于',
      subtitle: 'Memos One · Offline First 客户端',
      child: Column(
        children: [
          _CardBlock(
            title: '应用',
            children: [
              const ListTile(
                title: Text(AppConstants.appName),
                subtitle: Text(AppConstants.appTagline),
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('GitHub'),
                subtitle: const Text('AlexWuYh/MemosOne'),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/AlexWuYh/MemosOne'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const _CardBlock(
            title: '快捷键',
            children: [
              ListTile(
                dense: true,
                title: Text('⌘/Ctrl + N'),
                subtitle: Text('新建笔记'),
              ),
              ListTile(
                dense: true,
                title: Text('⌘/Ctrl + F'),
                subtitle: Text('聚焦搜索'),
              ),
              ListTile(
                dense: true,
                title: Text('⌘/Ctrl + S'),
                subtitle: Text('立即同步'),
              ),
              ListTile(
                dense: true,
                title: Text('⌘/Ctrl + B'),
                subtitle: Text('折叠列表'),
              ),
            ],
          ),
          const _CardBlock(
            title: '说明',
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                '实例管理（成员 / 存储 / SSO / AI）请在服务器 Web 管理端完成。'
                '本客户端聚焦个人笔记的离线编辑与同步。',
                style: TextStyle(color: AppTheme.inkMuted, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  Map<String, dynamic>? _user;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .readToken(widget.workspace.localId);
      final client =
          MemosApiClient.forWorkspace(widget.workspace, token: token);
      final user = await client.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _CardBlock(
        title: '资料',
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }
    if (_error != null) {
      return _CardBlock(
        title: '资料',
        children: [
          ListTile(
            title: Text(widget.workspace.username ?? '已登录'),
            subtitle: Text('无法拉取：$_error'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ),
        ],
      );
    }
    final u = _user ?? const {};
    final display = (u['displayName'] ??
            u['display_name'] ??
            u['nickname'] ??
            u['username'] ??
            widget.workspace.username ??
            '用户')
        .toString();
    final username =
        (u['username'] ?? u['name'] ?? widget.workspace.username ?? '')
            .toString();

    return _CardBlock(
      title: '资料',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentSoft,
          foregroundColor: AppTheme.accent,
          child: Text(
            display.isNotEmpty
                ? String.fromCharCode(display.runes.first)
                : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: username.isEmpty ? null : Text('@$username'),
        trailing: IconButton(
          tooltip: '复制用户名',
          onPressed: username.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: username));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制')),
                    );
                  }
                },
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
      ),
    );
  }
}
