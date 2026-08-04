import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/workspace.dart';
import '../../../infrastructure/network/memos/memos_api_client.dart';
import '../../workspace/presentation/workspace_dialogs.dart';

/// Desktop settings — covers local client prefs + logged-in account surfaces
/// that map sensibly from Memos web (preference / my-account / sync).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static String _visibilityLabel(MemoVisibility v) => switch (v) {
        MemoVisibility.private => '私有 PRIVATE',
        MemoVisibility.protected => '保护 PROTECTED',
        MemoVisibility.public => '公开 PUBLIC',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final syncPrefs = ref.watch(syncPrefsProvider);
    final defaultVis = ref.watch(defaultVisibilityProvider);
    final doubleClick = ref.watch(doubleClickToEditProvider);
    final loggedIn = active?.isMemos == true &&
        active?.authState == WorkspaceAuthState.ok;
    final deadAsync = active == null || !active.isMemos
        ? null
        : ref.watch(syncServiceProvider).listDeadTasks(active.localId);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
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

          // —— Appearance (web: preference.appearance) ——
          const _SectionTitle('外观'),
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
          Text(
            '强调色',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              AppTheme.defaultSeed,
              const Color(0xFF0D9488),
              const Color(0xFFEA580C),
              const Color(0xFFDB2777),
              const Color(0xFF475569),
              const Color(0xFF2F6F5E),
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
          // —— Memo defaults (web: preference.memo-defaults) ——
          const _SectionTitle('笔记偏好'),
          const SizedBox(height: 4),
          Text(
            '对应 Web 设置中的「偏好」：默认可见性、双击编辑等客户端行为。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('新建笔记默认可见性'),
            subtitle: Text(_visibilityLabel(defaultVis)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showModalBottomSheet<MemoVisibility>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final v in MemoVisibility.values)
                        ListTile(
                          title: Text(_visibilityLabel(v)),
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
            contentPadding: EdgeInsets.zero,
            title: const Text('双击预览进入编辑'),
            subtitle: const Text('与 Web「双击编辑」一致；也可点工具栏「编辑」'),
            value: doubleClick,
            onChanged: (v) =>
                ref.read(doubleClickToEditProvider.notifier).setEnabled(v),
          ),

          const SizedBox(height: 24),
          // —— Sync ——
          const _SectionTitle('同步（云端优先 · 离线可写）'),
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
            subtitle: const Text('启动或进入工作区后立即同步'),
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

          const SizedBox(height: 24),
          // —— Workspace ——
          const _SectionTitle('工作区'),
          if (active == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('尚未连接工作区'),
            )
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
            if (active.isMemos && active.serverBaseUrl != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.open_in_browser_rounded),
                title: const Text('在浏览器打开实例'),
                onTap: () async {
                  final uri = Uri.tryParse(active.serverBaseUrl!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            if (active.isMemos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_rounded),
                title: const Text('立即同步'),
                enabled: loggedIn,
                onTap: loggedIn
                    ? () => ref.read(syncServiceProvider).syncNow(active)
                    : null,
              ),
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
                  await ref.read(onboardingDoneProvider.notifier).reset();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],

          // —— Account (web: my-account) — only when Memos + login ——
          if (active?.isMemos == true) ...[
            const SizedBox(height: 24),
            const _SectionTitle('账户'),
            const SizedBox(height: 4),
            if (!loggedIn) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('未登录'),
                subtitle: const Text('登录后可管理账号信息并同步'),
                trailing: FilledButton(
                  onPressed: () => showLoginDialog(context, ref, active!),
                  child: const Text('登录'),
                ),
              ),
            ] else ...[
              _AccountCard(workspace: active!),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login_rounded),
                title: const Text('重新登录 / 更换 Token'),
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
                leading: const Icon(Icons.key_rounded),
                title: const Text('Access Token 说明'),
                subtitle: const Text(
                  '可在服务器 Web 设置 → Access Token 创建，'
                  '然后在本客户端用 Token 登录（推荐）',
                ),
                onTap: () async {
                  final base = active.serverBaseUrl;
                  if (base == null) return;
                  final uri = Uri.tryParse('$base/setting');
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ],

          const SizedBox(height: 24),
          const _SectionTitle('同步失败任务'),
          if (deadAsync == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('仅云端工作区有此列表'),
            )
          else if (!loggedIn)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('登录后可查看与重试失败任务'),
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

          const SizedBox(height: 24),
          const _SectionTitle('快捷键'),
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
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('⌘/Ctrl + B'),
            subtitle: Text('折叠/展开笔记列表'),
          ),

          const SizedBox(height: 24),
          const _SectionTitle('关于'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Memos One'),
            subtitle: const Text(
              'Offline First 桌面客户端 · 兼容 usememos/memos API v1\n'
              '实例管理（成员/存储/SSO/AI）请在服务器 Web 管理端操作',
            ),
            isThreeLine: true,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code_rounded),
            title: const Text('GitHub'),
            subtitle: const Text('AlexWuYh/MemosOne'),
            onTap: () async {
              final uri =
                  Uri.parse('https://github.com/AlexWuYh/MemosOne');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
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
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.workspace.username ?? '已登录'),
        subtitle: Text('无法拉取服务器资料：$_error'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
        ),
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
    final email = (u['email'] ?? '').toString();
    final role = (u['role'] ?? u['userRole'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.accentSoft,
              foregroundColor: AppTheme.accent,
              child: Text(
                display.isNotEmpty
                    ? String.fromCharCode(display.runes.first)
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  if (role.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '复制用户名',
              onPressed: username.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: username));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制用户名')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
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
