import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Workspaces',
                style: Theme.of(context).textTheme.titleMedium,
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
                          'Create a local or Memos workspace to begin.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final ws = list[i];
                      final selected = ws.localId == active?.localId;
                      return ListTile(
                        selected: selected,
                        leading: Icon(
                          ws.isLocal
                              ? Icons.folder_outlined
                              : Icons.cloud_outlined,
                        ),
                        title: Text(ws.name),
                        subtitle: Text(
                          ws.isLocal
                              ? 'Local'
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
                          }
                        },
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
              leading: const Icon(Icons.add),
              title: const Text('New workspace'),
              onTap: () => showCreateWorkspaceDialog(context, ref),
            ),
            if (active?.isMemos == true &&
                active?.authState != WorkspaceAuthState.ok)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: () => showLoginDialog(context, ref, active!),
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
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
    final (icon, label, color) = switch (s.state) {
      GlobalSyncState.syncing => (
          Icons.sync,
          'Syncing…',
          Theme.of(context).colorScheme.primary
        ),
      GlobalSyncState.offline => (
          Icons.cloud_off,
          'Offline',
          Theme.of(context).colorScheme.outline
        ),
      GlobalSyncState.authRequired => (
          Icons.lock_outline,
          'Re-login required',
          Theme.of(context).colorScheme.error
        ),
      GlobalSyncState.error => (
          Icons.error_outline,
          s.lastError ?? 'Sync error',
          Theme.of(context).colorScheme.error
        ),
      GlobalSyncState.idle => (
          Icons.cloud_done_outlined,
          s.pendingCount > 0
              ? '${s.pendingCount} pending'
              : 'Synced',
          Theme.of(context).colorScheme.primary
        ),
    };
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Sync now',
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              ref.read(syncServiceProvider).syncNow(workspace),
        ),
      ),
    );
  }
}
