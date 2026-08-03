import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation_state.dart';
import '../../../app/providers.dart';
import '../../../domain/entities/memo.dart';
import '../../../domain/entities/sync_models.dart';
import '../../../domain/entities/workspace.dart';
import '../../calendar/presentation/calendar_panel.dart';
import '../../explore/presentation/explore_page.dart';
import '../../memo/presentation/memo_detail_panel.dart';
import '../../memo/presentation/memo_feed_panel.dart';
import '../../memo/presentation/memo_list_panel.dart';
import '../../workspace/presentation/workspace_dialogs.dart';
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
    ref.read(appViewModeProvider.notifier).state = AppViewMode.notes;
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
    final selectedId = ref.watch(selectedMemoIdProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final sync = ref.watch(syncStatusProvider).valueOrNull;
    final mode = ref.watch(appViewModeProvider);
    final railCollapsed = ref.watch(workspaceRailCollapsedProvider);
    final listCollapsed = ref.watch(memoListCollapsedProvider);
    final scheme = Theme.of(context).colorScheme;
    final needsLogin = active?.isMemos == true &&
        active?.authState != WorkspaceAuthState.ok;

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
            titleSpacing: 8,
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
            leading: !isWide
                ? IconButton(
                    tooltip: '工作区',
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => _openWorkspaces(context),
                  )
                : null,
            actions: [
              if (isWide) ...[
                IconButton(
                  tooltip: railCollapsed ? '展开工作区' : '折叠工作区',
                  onPressed: () {
                    ref.read(workspaceRailCollapsedProvider.notifier).state =
                        !railCollapsed;
                  },
                  icon: Icon(
                    railCollapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                  ),
                ),
                if (mode == AppViewMode.notes)
                  IconButton(
                    tooltip: listCollapsed ? '展开列表' : '折叠列表',
                    onPressed: () {
                      ref.read(memoListCollapsedProvider.notifier).state =
                          !listCollapsed;
                    },
                    icon: Icon(
                      listCollapsed
                          ? Icons.view_sidebar_outlined
                          : Icons.view_sidebar,
                    ),
                  ),
              ],
              if (active?.isMemos == true) ...[
                _SyncChip(snapshot: sync, workspace: active!),
                if (needsLogin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          showLoginDialog(context, ref, active),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('登录'),
                    ),
                  ),
              ],
              IconButton(
                tooltip: '新建笔记',
                onPressed: active == null ? null : () => _newMemo(ref),
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 4),
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
              ? const Center(child: Text('请添加工作区并登录 Memos'))
              : isWide
                  ? Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: railCollapsed ? 56 : 268,
                          child: railCollapsed
                              ? _CollapsedNav(
                                  mode: mode,
                                  onMode: (m) => ref
                                      .read(appViewModeProvider.notifier)
                                      .state = m,
                                  onExpand: () => ref
                                      .read(workspaceRailCollapsedProvider
                                          .notifier)
                                      .state = false,
                                  onWorkspaces: () =>
                                      _openWorkspaces(context),
                                )
                              : Column(
                                  children: [
                                    _ModeTabs(mode: mode),
                                    const Divider(height: 1),
                                    const Expanded(child: WorkspaceRail()),
                                  ],
                                ),
                        ),
                        const VerticalDivider(width: 1),
                        ..._wideBody(
                          context,
                          ref,
                          mode: mode,
                          listCollapsed: listCollapsed,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _ModeTabs(mode: mode, dense: true),
                        const Divider(height: 1),
                        Expanded(child: _mobileBody(mode, selectedId)),
                      ],
                    ),
        ),
      ),
    );
  }

  List<Widget> _wideBody(
    BuildContext context,
    WidgetRef ref, {
    required AppViewMode mode,
    required bool listCollapsed,
  }) {
    switch (mode) {
      case AppViewMode.notes:
        return [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: listCollapsed ? 0 : 340,
            child: listCollapsed
                ? const SizedBox.shrink()
                : const MemoListPanel(),
          ),
          if (!listCollapsed) const VerticalDivider(width: 1),
          const Expanded(child: MemoDetailPanel()),
        ];
      case AppViewMode.feed:
        return [
          const Expanded(flex: 5, child: MemoFeedPanel()),
          const VerticalDivider(width: 1),
          const Expanded(flex: 4, child: MemoDetailPanel()),
        ];
      case AppViewMode.explore:
        return [const Expanded(child: ExplorePage())];
      case AppViewMode.calendar:
        return [
          const Expanded(flex: 5, child: CalendarPanel()),
          const VerticalDivider(width: 1),
          const Expanded(flex: 4, child: MemoListPanel(compact: true)),
        ];
    }
  }

  Widget _mobileBody(AppViewMode mode, String? selectedId) {
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

class _ModeTabs extends ConsumerWidget {
  const _ModeTabs({required this.mode, this.dense = false});

  final AppViewMode mode;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, dense ? 6 : 10, 8, dense ? 6 : 8),
      child: SegmentedButton<AppViewMode>(
        segments: const [
          ButtonSegment(
            value: AppViewMode.notes,
            icon: Icon(Icons.notes_rounded, size: 16),
            label: Text('笔记'),
          ),
          ButtonSegment(
            value: AppViewMode.feed,
            icon: Icon(Icons.view_stream_rounded, size: 16),
            label: Text('信息流'),
          ),
          ButtonSegment(
            value: AppViewMode.explore,
            icon: Icon(Icons.travel_explore_rounded, size: 16),
            label: Text('Explore'),
          ),
          ButtonSegment(
            value: AppViewMode.calendar,
            icon: Icon(Icons.calendar_month_rounded, size: 16),
            label: Text('日历'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) {
          ref.read(appViewModeProvider.notifier).state = s.first;
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _CollapsedNav extends StatelessWidget {
  const _CollapsedNav({
    required this.mode,
    required this.onMode,
    required this.onExpand,
    required this.onWorkspaces,
  });

  final AppViewMode mode;
  final ValueChanged<AppViewMode> onMode;
  final VoidCallback onExpand;
  final VoidCallback onWorkspaces;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          IconButton(
            tooltip: '展开工作区',
            onPressed: onExpand,
            icon: const Icon(Icons.keyboard_double_arrow_right),
          ),
          IconButton(
            tooltip: '工作区',
            onPressed: onWorkspaces,
            icon: const Icon(Icons.workspaces_outline),
          ),
          const Divider(),
          _navIcon(Icons.notes_rounded, AppViewMode.notes, '笔记'),
          _navIcon(Icons.view_stream_rounded, AppViewMode.feed, '信息流'),
          _navIcon(Icons.travel_explore_rounded, AppViewMode.explore, 'Explore'),
          _navIcon(Icons.calendar_month_rounded, AppViewMode.calendar, '日历'),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, AppViewMode m, String tip) {
    final selected = mode == m;
    return IconButton(
      tooltip: tip,
      isSelected: selected,
      onPressed: () => onMode(m),
      icon: Icon(icon),
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
