import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Single-cloud shell — AppFlowy-like workspace chrome.
/// Soft sidebar, flat content, calm dividers. No floating brutal panels.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final active = ref.watch(activeWorkspaceProvider);
    final mode = ref.watch(appViewModeProvider);
    final listCollapsed = ref.watch(memoListCollapsedProvider);
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
              ? _NoConnection(
                  onConnect: () async {
                    await showConnectMemosDialog(context, ref);
                  },
                )
              : Row(
                  children: [
                    _PrimaryRail(
                      mode: mode,
                      onMode: (m) {
                        ref.read(appViewModeProvider.notifier).state = m;
                        if (m == AppViewMode.feed) {
                          ref.read(selectedMemoIdProvider.notifier).state =
                              null;
                        }
                      },
                      onSettings: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      onNew: () => _newMemo(ref),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: ColoredBox(
                        color: AppTheme.paperElevated,
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
                            const Divider(height: 1, thickness: 1),
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
                    ),
                  ],
                ),
          floatingActionButton: (!isWide && active != null)
              ? FloatingActionButton(
                  onPressed: () => _newMemo(ref),
                  child: const Icon(Icons.add_rounded),
                )
              : null,
        ),
      ),
    );
  }
}

class _NoConnection extends StatelessWidget {
  const _NoConnection({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 72),
              const SizedBox(height: 24),
              Text(
                '连接你的 Memos',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '一个云端实例，本地自动缓存。离线也能写，联网再同步。',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.inkMuted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onConnect,
                child: const Text('去连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryRail extends StatelessWidget {
  const _PrimaryRail({
    required this.mode,
    required this.onMode,
    required this.onSettings,
    required this.onNew,
  });

  final AppViewMode mode;
  final ValueChanged<AppViewMode> onMode;
  final VoidCallback onSettings;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: ColoredBox(
        color: AppTheme.paper,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const AppLogo(size: 36, showBorder: false),
              const SizedBox(height: 16),
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
                icon: Icons.add_rounded,
                selectedIcon: Icons.add_rounded,
                label: '新建',
                selected: false,
                accent: true,
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
    this.accent = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = widget.accent
        ? Theme.of(context).colorScheme.primary
        : selected
            ? Theme.of(context).colorScheme.primaryContainer
            : _hover
                ? AppTheme.surfaceHover
                : Colors.transparent;
    final fg = widget.accent
        ? AppTheme.onAccent
        : selected
            ? Theme.of(context).colorScheme.primary
            : AppTheme.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: widget.onTap,
              child: SizedBox(
                height: 40,
                child: Icon(
                  selected ? widget.selectedIcon : widget.icon,
                  size: 20,
                  color: fg,
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.paperElevated,
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                active.serverBaseUrl?.replaceFirst(RegExp(r'^https?://'), '') ??
                    active.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (showListToggle)
            IconButton(
              tooltip: listCollapsed ? '显示列表' : '隐藏列表',
              visualDensity: VisualDensity.compact,
              onPressed: onToggleList,
              icon: Icon(
                listCollapsed
                    ? Icons.vertical_split_outlined
                    : Icons.vertical_split,
                size: 20,
                color: AppTheme.inkMuted,
              ),
            ),
          if (active.isMemos) ...[
            _SoftSync(snapshot: sync, onTap: onSync),
            if (needsLogin) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onLogin,
                child: const Text('登录'),
              ),
            ],
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 16),
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
    final (IconData icon, String label, Color fg, Color bg) = switch (s.state) {
      GlobalSyncState.syncing => (
          Icons.sync,
          '同步中',
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primaryContainer,
        ),
      GlobalSyncState.offline => (
          Icons.cloud_off_outlined,
          '离线',
          AppTheme.inkMuted,
          AppTheme.surfaceMuted,
        ),
      GlobalSyncState.authRequired => (
          Icons.lock_outline,
          '需登录',
          AppTheme.danger,
          AppTheme.dangerSoft,
        ),
      GlobalSyncState.error => (
          Icons.error_outline,
          s.deadCount > 0 ? '${s.deadCount} 失败' : '异常',
          AppTheme.danger,
          AppTheme.dangerSoft,
        ),
      GlobalSyncState.idle => s.pendingCount > 0
          ? (
              Icons.cloud_queue_outlined,
              '${s.pendingCount} 待同步',
              AppTheme.warning,
              AppTheme.warningSoft,
            )
          : (
              Icons.cloud_done_outlined,
              '已同步',
              const Color(0xFF0D9488),
              const Color(0xFFCCFBF1),
            ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
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
              const SizedBox(width: 300, child: MemoListPanel()),
              const VerticalDivider(width: 1, thickness: 1),
            ],
            const Expanded(child: MemoDetailPanel()),
          ],
        );
      case AppViewMode.feed:
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
              const VerticalDivider(width: 1, thickness: 1),
              const SizedBox(width: 280, child: MemoListPanel(compact: true)),
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
