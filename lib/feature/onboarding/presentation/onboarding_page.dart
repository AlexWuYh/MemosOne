import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_failure.dart';

/// First-run: connect to Memos cloud, then work offline on the local cache.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _token = TextEditingController();
  var _useToken = false;
  var _insecure = false;
  var _busy = false;
  String? _error;
  var _step = 0;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? createdWorkspaceId;
    try {
      final url = _url.text.trim();
      if (url.isEmpty || !url.startsWith('http')) {
        throw const ValidationFailure('请输入有效的服务器地址（https://…）');
      }
      if (_useToken && _token.text.trim().isEmpty) {
        throw const ValidationFailure('请粘贴 Access Token');
      }
      if (!_useToken &&
          (_user.text.trim().isEmpty || _pass.text.isEmpty)) {
        throw const ValidationFailure('请输入用户名和密码');
      }

      final wsRepo = ref.read(workspaceRepositoryProvider);
      final name = Uri.tryParse(url)?.host ?? 'Memos';
      final ws = await wsRepo.createMemos(
        name: name,
        serverBaseUrl: url,
        allowInsecureTls: _insecure,
      );
      createdWorkspaceId = ws.localId;

      // Authenticate BEFORE treating onboarding as done / navigating home.
      if (_useToken) {
        await ref.read(authRepositoryProvider).loginWithAccessToken(
              workspace: ws,
              accessToken: _token.text,
            );
      } else {
        await ref.read(authRepositoryProvider).login(
              workspace: ws,
              username: _user.text.trim(),
              password: _pass.text,
            );
      }

      await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      final latest = await wsRepo.get(ws.localId);
      if (latest != null) {
        ref.read(syncWorkerProvider).clearAuthBlock(latest.localId);
        try {
          await ref.read(syncServiceProvider).syncNow(latest);
        } catch (e) {
          // Login succeeded; sync can fail offline — still enter app.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '已登录，但首次同步失败：${e is AppFailure ? e.message : e}',
                ),
              ),
            );
          }
        }
      }

      await ref.read(preferencesStoreProvider).setOnboardingDone(true);
      createdWorkspaceId = null; // success — do not roll back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已连接并完成首次同步，可离线继续使用')),
        );
      }
    } catch (e) {
      // Roll back half-created workspace so user stays on onboarding.
      if (createdWorkspaceId != null) {
        try {
          await ref
              .read(workspaceRepositoryProvider)
              .delete(createdWorkspaceId, wipeData: true);
          await ref.read(activeWorkspaceIdProvider.notifier).select(null);
        } catch (_) {}
      }
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

  Future<void> _offlineOnly() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ws = await ref
          .read(workspaceRepositoryProvider)
          .createLocal(name: '本地笔记');
      await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      await ref.read(preferencesStoreProvider).setOnboardingDone(true);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: scheme.onPrimary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Memos One',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '连接你的 Memos 服务器，本地缓存后随时离线编辑，网络恢复后自动同步。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 28),
                  if (_step == 0) ...[
                    _HeroCard(
                      icon: Icons.cloud_done_outlined,
                      title: '连接云端 Memos',
                      subtitle: '推荐 · 首次同步后即可离线使用',
                      primary: true,
                      onTap: () => setState(() => _step = 1),
                    ),
                    const SizedBox(height: 12),
                    _HeroCard(
                      icon: Icons.phone_iphone_outlined,
                      title: '仅本地使用',
                      subtitle: '不连接服务器（可稍后在设置中添加）',
                      primary: false,
                      onTap: _busy ? null : _offlineOnly,
                    ),
                  ] else ...[
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        hintText: 'https://memos.example.com',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('允许不安全 TLS'),
                      subtitle: const Text('仅用于局域网自签名证书'),
                      value: _insecure,
                      onChanged: (v) => setState(() => _insecure = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('使用 Access Token'),
                      subtitle: const Text('从 Memos 设置复制令牌时勾选'),
                      value: _useToken,
                      onChanged: (v) => setState(() => _useToken = v),
                    ),
                    if (_useToken)
                      TextField(
                        controller: _token,
                        decoration: const InputDecoration(
                          labelText: 'Access Token',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        obscureText: true,
                      )
                    else ...[
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _connect(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: scheme.onErrorContainer,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('连接并同步'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _busy ? null : () => setState(() => _step = 0),
                      child: const Text('返回'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: primary
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
