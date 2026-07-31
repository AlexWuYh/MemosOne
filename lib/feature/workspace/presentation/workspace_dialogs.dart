import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/workspace.dart';

Future<void> showCreateWorkspaceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _CreateWorkspaceDialog(),
  );
}

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  ConsumerState<_CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState
    extends ConsumerState<_CreateWorkspaceDialog> {
  final _name = TextEditingController(text: 'My Notes');
  final _url = TextEditingController();
  var _type = WorkspaceType.local;
  var _insecure = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(workspaceRepositoryProvider);
      final Workspace ws;
      if (_type == WorkspaceType.local) {
        ws = await repo.createLocal(name: _name.text);
      } else {
        final url = _url.text.trim();
        if (url.isEmpty || !url.startsWith('http')) {
          throw const ValidationFailure('Enter a valid server URL (https://…)');
        }
        ws = await repo.createMemos(
          name: _name.text,
          serverBaseUrl: url,
          allowInsecureTls: _insecure,
        );
      }
      await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      if (mounted) Navigator.of(context).pop();
      if (_type == WorkspaceType.memos && mounted) {
        await showLoginDialog(context, ref, ws);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New workspace'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<WorkspaceType>(
              segments: const [
                ButtonSegment(
                  value: WorkspaceType.local,
                  label: Text('Local'),
                  icon: Icon(Icons.folder_outlined),
                ),
                ButtonSegment(
                  value: WorkspaceType.memos,
                  label: Text('Memos'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            if (_type == WorkspaceType.memos) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://memos.example.com',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow insecure TLS'),
                subtitle: const Text(
                  'Only for trusted LAN self-signed certs. Default off.',
                ),
                value: _insecure,
                onChanged: (v) => setState(() => _insecure = v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

Future<void> showLoginDialog(
  BuildContext context,
  WidgetRef ref,
  Workspace workspace,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _LoginDialog(workspace: workspace),
  );
}

class _LoginDialog extends ConsumerStatefulWidget {
  const _LoginDialog({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<_LoginDialog> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).login(
            workspace: widget.workspace,
            username: _user.text.trim(),
            password: _pass.text,
          );
      ref.read(syncWorkerProvider).clearAuthBlock(widget.workspace.localId);
      await ref.read(syncServiceProvider).syncNow(widget.workspace);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e is AppFailure ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sign in · ${widget.workspace.name}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.workspace.serverBaseUrl ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username'),
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
      ],
    );
  }
}
