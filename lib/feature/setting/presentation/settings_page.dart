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
    final deadAsync = active == null || !active.isMemos
        ? null
        : ref.watch(syncServiceProvider).listDeadTasks(active.localId);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(AppConstants.appTagline),
          const SizedBox(height: 24),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
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
              Colors.teal,
              Colors.orange,
              Colors.pink,
              Colors.blueGrey,
            ]
                .map(
                  (c) => ChoiceChip(
                    label: const SizedBox(width: 12, height: 12),
                    selected: accent.toARGB32() == c.toARGB32(),
                    selectedColor: c,
                    backgroundColor: c.withValues(alpha: 0.4),
                    onSelected: (_) =>
                        ref.read(accentColorProvider.notifier).setColor(c),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 32),
          Text('Workspace', style: Theme.of(context).textTheme.titleMedium),
          if (active == null)
            const ListTile(title: Text('No active workspace'))
          else ...[
            ListTile(
              title: Text(active.name),
              subtitle: Text(
                active.isLocal
                    ? 'Local offline workspace'
                    : '${active.serverBaseUrl}\n${active.username ?? 'Not signed in'} · auth=${active.authState.name}',
              ),
              isThreeLine: !active.isLocal,
            ),
            if (active.isMemos) ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in / re-auth'),
                onTap: () => showLoginDialog(context, ref, active),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  await ref.read(authRepositoryProvider).logout(active);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync now'),
                onTap: () => ref.read(syncServiceProvider).syncNow(active),
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Delete workspace'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete workspace?'),
                    content: const Text(
                      'Local memos for this workspace will be removed. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
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
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
          const Divider(height: 32),
          Text('Sync dead letters',
              style: Theme.of(context).textTheme.titleMedium),
          if (deadAsync == null)
            const ListTile(title: Text('N/A for local workspace'))
          else
            FutureBuilder(
              future: deadAsync,
              builder: (context, snap) {
                final tasks = snap.data ?? const [];
                if (tasks.isEmpty) {
                  return const ListTile(title: Text('No dead tasks'));
                }
                return Column(
                  children: tasks
                      .map(
                        (t) => ListTile(
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
                            child: const Text('Retry'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const Divider(height: 32),
          Text('Shortcuts (desktop)',
              style: Theme.of(context).textTheme.titleMedium),
          const ListTile(
            dense: true,
            title: Text('Ctrl/Cmd + N'),
            subtitle: Text('New memo'),
          ),
          const ListTile(
            dense: true,
            title: Text('Ctrl/Cmd + F'),
            subtitle: Text('Focus search (list panel)'),
          ),
          const ListTile(
            dense: true,
            title: Text('Ctrl/Cmd + S'),
            subtitle: Text('Sync now (Memos workspace)'),
          ),
        ],
      ),
    );
  }
}
