import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';

/// First-run connect flow. Never leaves until [onboardingDoneProvider] is true.
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
  /// 0 choose · 1 form · 2 failed
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '已登录，首次同步未完成：${e is AppFailure ? e.message : e}',
                ),
              ),
            );
          }
        }
      }

      createdWorkspaceId = null;
      await ref.read(onboardingDoneProvider.notifier).markDone();
    } catch (e) {
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
        setState(() {
          _error = msg;
          _step = 2;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipToLocal() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ws = await ref
          .read(workspaceRepositoryProvider)
          .createLocal(name: '本地笔记');
      await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      await ref.read(onboardingDoneProvider.notifier).markDone();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipLoginLater() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = _url.text.trim();
      if (url.isEmpty || !url.startsWith('http')) {
        await _skipToLocal();
        return;
      }
      final wsRepo = ref.read(workspaceRepositoryProvider);
      final name = Uri.tryParse(url)?.host ?? 'Memos';
      final ws = await wsRepo.createMemos(
        name: name,
        serverBaseUrl: url,
        allowInsecureTls: _insecure,
      );
      await ref.read(activeWorkspaceIdProvider.notifier).select(ws.localId);
      await ref.read(onboardingDoneProvider.notifier).markDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已跳过登录，可稍后在侧栏点击「登录」')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0B4AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '登录失败',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            style: const TextStyle(
              height: 1.4,
              color: Color(0xFF7A271A),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: AppTheme.accent,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Memos One',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '连接服务器后，笔记会缓存在本地——离线也能写，联网自动同步。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_step == 0) ...[
                    _ChoiceCard(
                      icon: Icons.cloud_outlined,
                      title: '连接云端 Memos',
                      subtitle: '推荐 · 登录并同步',
                      emphasized: true,
                      onTap: () => setState(() => _step = 1),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceCard(
                      icon: Icons.phone_iphone_outlined,
                      title: '仅本地使用',
                      subtitle: '稍后再连接服务器',
                      onTap: _busy ? null : _skipToLocal,
                    ),
                  ] else ...[
                    if (_error != null) ...[
                      _errorBanner(_error!),
                      const SizedBox(height: 16),
                    ],
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
                      subtitle: const Text('局域网自签名证书'),
                      value: _insecure,
                      onChanged: (v) => setState(() => _insecure = v),
                    ),
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
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _connect(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_step == 2 ? '重试登录' : '连接并同步'),
                    ),
                    if (_step == 2) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _busy ? null : _skipLoginLater,
                        child: const Text('跳过登录，稍后再登录'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : _skipToLocal,
                        child: const Text('改为仅本地使用'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _step = 0;
                                _error = null;
                              }),
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.emphasized = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppTheme.accentSoft : AppTheme.paperElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: emphasized
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.line,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
