import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/workspace.dart';

/// Connect or upgrade to a single Memos instance (non-destructive for local notes).
Future<void> showConnectMemosDialog(
  BuildContext context,
  WidgetRef ref, {
  Workspace? existing,
}) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _ConnectMemosDialog(existing: existing),
  );
}

/// @Deprecated — use [showConnectMemosDialog]
@Deprecated('Use showConnectMemosDialog')
Future<void> showCreateWorkspaceDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showConnectMemosDialog(context, ref);
}

class _ConnectMemosDialog extends ConsumerStatefulWidget {
  const _ConnectMemosDialog({this.existing});

  final Workspace? existing;

  @override
  ConsumerState<_ConnectMemosDialog> createState() =>
      _ConnectMemosDialogState();
}

class _ConnectMemosDialogState extends ConsumerState<_ConnectMemosDialog> {
  final _url = TextEditingController();
  var _insecure = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing?.serverBaseUrl != null) {
      _url.text = existing!.serverBaseUrl!;
      _insecure = existing.allowInsecureTls;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = _url.text.trim();
      if (url.isEmpty || !url.startsWith('http')) {
        throw const ValidationFailure('请输入有效的服务器地址（https://…）');
      }
      final repo = ref.read(workspaceRepositoryProvider);
      final existing = widget.existing;
      final Workspace ws;
      if (existing == null) {
        final host = Uri.tryParse(url)?.host ?? 'Memos';
        ws = await repo.createMemos(
          name: host,
          serverBaseUrl: url,
          allowInsecureTls: _insecure,
        );
        await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      } else if (existing.isLocal) {
        ws = await repo.bindMemosServer(
          localId: existing.localId,
          serverBaseUrl: url,
          allowInsecureTls: _insecure,
        );
        await ref
            .read(memoRepositoryProvider)
            .prepareLocalMemosForCloudPush(ws.localId);
        await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      } else {
        ws = await repo.bindMemosServer(
          localId: existing.localId,
          serverBaseUrl: url,
          allowInsecureTls: _insecure,
        );
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      await showLoginDialog(context, ref, ws);
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString();
      setState(() => _error = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpgrade = widget.existing?.isLocal == true;
    return AlertDialog(
      title: Text(isUpgrade ? '连接 Memos 云端' : '连接 Memos'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isUpgrade)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '将把当前本地笔记绑定到服务器，不会清空本机数据。登录后会尝试首次同步。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: '服务器 URL',
                hintText: 'https://memos.example.com',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允许不安全 TLS'),
              subtitle: const Text('局域网自签名证书'),
              value: _insecure,
              onChanged: (v) => setState(() => _insecure = v),
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
          onPressed: _busy
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isUpgrade ? '绑定并登录' : '连接并登录'),
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
    useRootNavigator: true,
    barrierDismissible: false,
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
  final _token = TextEditingController();
  var _useToken = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_useToken) {
        if (_token.text.trim().isEmpty) {
          throw const ValidationFailure('请粘贴 Access Token');
        }
        await ref.read(authRepositoryProvider).loginWithAccessToken(
              workspace: widget.workspace,
              accessToken: _token.text,
            );
      } else {
        if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
          throw const ValidationFailure('请输入用户名和密码');
        }
        await ref.read(authRepositoryProvider).login(
              workspace: widget.workspace,
              username: _user.text.trim(),
              password: _pass.text,
            );
      }
      ref.read(syncWorkerProvider).clearAuthBlock(widget.workspace.localId);
      final latest = await ref
          .read(workspaceRepositoryProvider)
          .get(widget.workspace.localId);
      try {
        await ref.read(syncServiceProvider).syncNow(latest ?? widget.workspace);
      } catch (_) {
        // login ok even if sync fails
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
      }
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString();
      if (mounted) {
        setState(() => _error = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('登录 · ${widget.workspace.name}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.workspace.serverBaseUrl ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用 Access Token'),
                value: _useToken,
                onChanged: (v) => setState(() => _useToken = v),
              ),
              if (_useToken)
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Access Token',
                  ),
                  obscureText: true,
                )
              else ...[
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: '用户名'),
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录并同步'),
        ),
      ],
    );
  }
}
