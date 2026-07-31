import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/memo.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isMedium = width >= 600 && width < 900;
    final selectedId = ref.watch(selectedMemoIdProvider);
    final active = ref.watch(activeWorkspaceProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _newMemo(ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _newMemo(ref),
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
            title: Text(active?.name ?? 'Memos One'),
            actions: [
              IconButton(
                tooltip: 'New memo',
                onPressed: active == null ? null : () => _newMemo(ref),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          floatingActionButton: (!isWide && active != null)
              ? FloatingActionButton(
                  onPressed: () => _newMemo(ref),
                  child: const Icon(Icons.add),
                )
              : null,
          body: active == null
              ? const _EmptyOnboarding()
              : isWide
                  ? const Row(
                      children: [
                        SizedBox(width: 260, child: WorkspaceRail()),
                        VerticalDivider(width: 1),
                        SizedBox(width: 320, child: MemoListPanel()),
                        VerticalDivider(width: 1),
                        Expanded(child: MemoDetailPanel()),
                      ],
                    )
                  : isMedium
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 280,
                              child: MemoListPanel(compact: true),
                            ),
                            VerticalDivider(width: 1),
                            Expanded(child: MemoDetailPanel()),
                          ],
                        )
                      : selectedId == null
                          ? Column(
                              children: [
                                Expanded(
                                  child: MemoListPanel(
                                    onSelect: (_) {},
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.workspaces),
                                  title: const Text('Workspaces & settings'),
                                  onTap: () {
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => const SizedBox(
                                        height: 480,
                                        child: WorkspaceRail(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          : const MemoDetailPanel(showBack: true),
        ),
      ),
    );
  }
}

class _EmptyOnboarding extends ConsumerWidget {
  const _EmptyOnboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Memos One',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'One Client. Every Device. Your Memos.\nOffline first — local is source of truth.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final ws = await ref
                      .read(workspaceRepositoryProvider)
                      .createLocal(name: 'Personal');
                  await ref
                      .read(activeWorkspaceIdProvider.notifier)
                      .select(ws.localId);
                },
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Create local workspace'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 420,
                      child: WorkspaceRail(),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Connect Memos server…'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
