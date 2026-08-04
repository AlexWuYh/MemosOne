import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation_state.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/entities/workspace.dart';
import '../../calendar/presentation/calendar_panel.dart';
import '../../explore/presentation/explore_page.dart';
import '../../memo/presentation/memo_detail_panel.dart';
import '../../memo/presentation/memo_feed_panel.dart';
import '../../memo/presentation/memo_list_panel.dart';
import '../../setting/presentation/settings_page.dart';
import '../../workspace/presentation/workspace_dialogs.dart';
import '../../workspace/presentation/workspace_rail.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _newMemo(WidgetRef ref) async {
    final ws = ref.read(activeWorkspaceProvider);
    if (ws == null) return;
    final visibility = ref.read(defaultVisibilityProvider);
    final memo = await ref.read(memoRepositoryProvider).create(
          ws.localId,
          NewMemo(content: '', visibility: visibility),
        );
    ref.read(selectedMemoIdProvider.notifier).state = memo.localId;
    ref.read(appViewModeProvider.notifier).state = AppViewMode.notes;
    ref.read(memoListCollapsedProvider.notifier).state = false;
  }

  void _showWorkspaces(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.paperElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SizedBox(
        height: 520,
        child: WorkspaceRail(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final active = ref.watch(activeWorkspaceProvider);
    final mode = ref.watch(appViewModeProvider);
    final listCollapsed = ref.watch(memoListCollapsedProvider);
    // true = hide workspace list panel (icon-rail only)
    final workspaceHidden = ref.watch(workspaceRailCollapsedProvider);
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final selectedId = ref.watch(selectedMemoIdProvider);
    final needsLogin = active?.isMemos == true &&
        active?.authState != WorkspaceAuthState.ok;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _newMemo(ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _newMemo(ref),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
            ref.read(searchFocusNodeProvider).requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            ref.read(searchFocusNodeProvider).requestFocus(),
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
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          ref.read(memoListCollapsedProvider.notifier).state = !listCollapsed;
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          ref.read(memoListCollapsedProvider.notifier).state = !listCollapsed;
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.paper,
          body: active == null
              ? Center(
                  child: FilledButton(
                    onPressed: () => _showWorkspaces(context),
                    child: const Text('添加工作区'),
                  ),
                )
              : Row(
                  children: [
                    // —— Primary icon rail (signature navigation) ——
                    _PrimaryRail(
                      mode: mode,
                      onMode: (m) {
                        ref.read(appViewModeProvider.notifier).state = m;
                        // Feed is a browse stream — always start from the list.
                        if (m == AppViewMode.feed) {
                          ref.read(selectedMemoIdProvider.notifier).state =
                              null;
                        }
                      },
                      onToggleWorkspace: isWide
                          ? () {
                              ref
                                  .read(workspaceRailCollapsedProvider.notifier)
                                  .state = !workspaceHidden;
                            }
                          : () => _showWorkspaces(context),
                      workspaceOpen: isWide && !workspaceHidden,
                      onSettings: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      onNew: () => _newMemo(ref),
                    ),
                    // —— Optional workspace list ——
                    if (isWide && !workspaceHidden) ...[
                      const VerticalDivider(width: 1),
                      const SizedBox(width: 240, child: WorkspaceRail()),
                    ],
                    const VerticalDivider(width: 1),
                    // —— Main content ——
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            active: active,
                            sync: sync,
                            needsLogin: needsLogin,
                            mode: mode,
                            listCollapsed: listCollapsed,
                            showListToggle: isWide &&
                                (mode == AppViewMode.notes ||
                                    mode == AppViewMode.calendar),
                            onToggleList: () {
                              ref
                                  .read(memoListCollapsedProvider.notifier)
                                  .state = !listCollapsed;
                            },
                            onLogin: () =>
                                showLoginDialog(context, ref, active),
                            onSync: () {
                              if (active.isMemos) {
                                ref
                                    .read(syncServiceProvider)
                                    .syncNow(active);
                              }
                            },
                            onNew: () => _newMemo(ref),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: isWide
                                ? _WideContent(
                                    mode: mode,
                                    listCollapsed: listCollapsed,
                                  )
                                : _NarrowContent(
                                    mode: mode,
                                    selectedId: selectedId,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          floatingActionButton: (!isWide)
              ? FloatingActionButton(
                  onPressed: () => _newMemo(ref),
                  child: const Icon(Icons.edit_rounded),
                )
              : null,
        ),
      ),
    );
  }
}

class _PrimaryRail extends StatelessWidget {
  const _PrimaryRail({
    required this.mode,
    required this.onMode,
    required this.onToggleWorkspace,
    required this.workspaceOpen,
    required this.onSettings,
    required this.onNew,
  });

  final AppViewMode mode;
  final ValueChanged<AppViewMode> onMode;
  final VoidCallback onToggleWorkspace;
  final bool workspaceOpen;
  final VoidCallback onSettings;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: AppTheme.paperElevated,
        border: Border(right: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            const Tooltip(
              message: 'Memos One',
              child: AppLogo(size: 58),
            ),
            const SizedBox(height: 16),
            _RailItem(
              icon: Icons.folder_outlined,
              selectedIcon: Icons.folder_rounded,
              label: '工作区',
              selected: workspaceOpen,
              onTap: onToggleWorkspace,
            ),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              height: 1,
              color: AppTheme.line,
            ),
            _RailItem(
              icon: Icons.notes_outlined,
              selectedIcon: Icons.notes_rounded,
              label: '笔记',
              selected: mode == AppViewMode.notes,
              onTap: () => onMode(AppViewMode.notes),
            ),
            _RailItem(
              icon: Icons.view_day_outlined,
              selectedIcon: Icons.view_day_rounded,
              label: '信息流',
              selected: mode == AppViewMode.feed,
              onTap: () => onMode(AppViewMode.feed),
            ),
            _RailItem(
              icon: Icons.public_outlined,
              selectedIcon: Icons.public_rounded,
              label: 'Explore',
              selected: mode == AppViewMode.explore,
              onTap: () => onMode(AppViewMode.explore),
            ),
            _RailItem(
              icon: Icons.calendar_today_outlined,
              selectedIcon: Icons.calendar_today_rounded,
              label: '日历',
              selected: mode == AppViewMode.calendar,
              onTap: () => onMode(AppViewMode.calendar),
            ),
            const Spacer(),
            _RailItem(
              icon: Icons.add_circle_outline,
              selectedIcon: Icons.add_circle,
              label: '新建',
              selected: false,
              onTap: onNew,
            ),
            _RailItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: '设置',
              selected: false,
              onTap: onSettings,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: selected
                ? AppTheme.accentSoft
                : _hover
                    ? AppTheme.line.withValues(alpha: 0.45)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: SizedBox(
                height: 44,
                child: Icon(
                  selected ? widget.selectedIcon : widget.icon,
                  size: 22,
                  color: selected ? AppTheme.accent : AppTheme.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.active,
    required this.sync,
    required this.needsLogin,
    required this.mode,
    required this.listCollapsed,
    required this.showListToggle,
    required this.onToggleList,
    required this.onLogin,
    required this.onSync,
    required this.onNew,
  });

  final Workspace active;
  final SyncStatusSnapshot? sync;
  final bool needsLogin;
  final AppViewMode mode;
  final bool listCollapsed;
  final bool showListToggle;
  final VoidCallback onToggleList;
  final VoidCallback onLogin;
  final VoidCallback onSync;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      AppViewMode.notes => '笔记',
      AppViewMode.feed => '信息流',
      AppViewMode.explore => 'Explore',
      AppViewMode.calendar => '日历',
    };

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.paper.withValues(alpha: 0.95),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              active.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.inkMuted,
              ),
            ),
          ),
          const Spacer(),
          if (showListToggle)
            IconButton(
              tooltip: listCollapsed ? '显示列表' : '隐藏列表',
              onPressed: onToggleList,
              icon: Icon(
                listCollapsed
                    ? Icons.vertical_split_outlined
                    : Icons.vertical_split,
                color: AppTheme.inkMuted,
              ),
            ),
          if (active.isMemos) ...[
            _SoftSync(snapshot: sync, onTap: onSync),
            if (needsLogin) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onLogin,
                child: const Text('登录'),
              ),
            ],
          ],
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建'),
          ),
        ],
      ),
    );
  }
}

class _SoftSync extends StatelessWidget {
  const _SoftSync({required this.snapshot, required this.onTap});

  final SyncStatusSnapshot? snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = snapshot ?? const SyncStatusSnapshot.idle();
    final (icon, label) = switch (s.state) {
      GlobalSyncState.syncing => (Icons.sync, '同步中'),
      GlobalSyncState.offline => (Icons.cloud_off_outlined, '离线'),
      GlobalSyncState.authRequired => (Icons.lock_outline, '需登录'),
      GlobalSyncState.error => (Icons.error_outline, '异常'),
      GlobalSyncState.idle => (
          Icons.cloud_done_outlined,
          s.pendingCount > 0 ? '${s.pendingCount} 待同步' : '已同步',
        ),
    };
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: AppTheme.inkMuted),
    );
  }
}

class _WideContent extends StatelessWidget {
  const _WideContent({
    required this.mode,
    required this.listCollapsed,
  });

  final AppViewMode mode;
  final bool listCollapsed;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AppViewMode.notes:
        return Row(
          children: [
            if (!listCollapsed) ...[
              const SizedBox(width: 320, child: MemoListPanel()),
              const VerticalDivider(width: 1),
            ],
            const Expanded(child: MemoDetailPanel()),
          ],
        );
      case AppViewMode.feed:
        // Full-bleed feed; open full note only after tap (no side editor).
        return Consumer(
          builder: (context, ref, _) {
            final id = ref.watch(selectedMemoIdProvider);
            if (id != null) {
              return const MemoDetailPanel(showBack: true);
            }
            return const MemoFeedPanel();
          },
        );
      case AppViewMode.explore:
        return const ExplorePage();
      case AppViewMode.calendar:
        return Row(
          children: [
            const Expanded(flex: 5, child: CalendarPanel()),
            if (!listCollapsed) ...[
              const VerticalDivider(width: 1),
              const SizedBox(width: 300, child: MemoListPanel(compact: true)),
            ],
          ],
        );
    }
  }
}

class _NarrowContent extends StatelessWidget {
  const _NarrowContent({
    required this.mode,
    required this.selectedId,
  });

  final AppViewMode mode;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case AppViewMode.notes:
        return selectedId == null
            ? const MemoListPanel()
            : const MemoDetailPanel(showBack: true);
      case AppViewMode.feed:
        return selectedId == null
            ? const MemoFeedPanel()
            : const MemoDetailPanel(showBack: true);
      case AppViewMode.explore:
        return const ExplorePage();
      case AppViewMode.calendar:
        return const CalendarPanel();
    }
  }
}
