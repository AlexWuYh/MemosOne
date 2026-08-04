import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';

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
          const SnackBar(content: Text('已跳过登录，可稍后在设置中登录')),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '登录失败',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.danger,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            msg,
            style: GoogleFonts.inter(
              height: 1.4,
              color: const Color(0xFF7A271A),
              fontSize: 12,
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 56, borderRadius: 12),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Memos One',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '连接 Memos 后，笔记缓存在本地——离线可写，联网同步。',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_step == 0) ...[
                    _ChoiceCard(
                      icon: Icons.cloud_outlined,
                      title: '连接云端 Memos',
                      subtitle: '推荐 · 登录并完成首次同步',
                      emphasized: true,
                      onTap: () => setState(() => _step = 1),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceCard(
                      icon: Icons.phone_iphone_outlined,
                      title: '先本地使用',
                      subtitle: '稍后再连接服务器',
                      onTap: _busy ? null : _skipToLocal,
                    ),
                  ] else ...[
                    if (_error != null) ...[
                      _errorBanner(_error!),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        hintText: 'https://memos.example.com',
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '允许不安全 TLS',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      subtitle: Text(
                        '局域网自签名证书',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                      value: _insecure,
                      onChanged: (v) => setState(() => _insecure = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '使用 Access Token',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      value: _useToken,
                      onChanged: (v) => setState(() => _useToken = v),
                    ),
                    if (_useToken)
                      TextField(
                        controller: _token,
                        decoration: const InputDecoration(
                          labelText: 'Access Token',
                          prefixIcon: Icon(Icons.key_outlined, size: 20),
                        ),
                        obscureText: true,
                      )
                    else ...[
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pass,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _connect(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_step == 2 ? '重试登录' : '连接并同步'),
                    ),
                    if (_step == 2) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _skipLoginLater,
                        child: const Text('跳过登录，稍后再登录'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _skipToLocal,
                        child: const Text('改为仅本地使用'),
                      ),
                    ],
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
      color: emphasized ? Theme.of(context).colorScheme.primaryContainer : AppTheme.paperElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: emphasized
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
              : AppTheme.line,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: emphasized ? Theme.of(context).colorScheme.primary : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: emphasized ? AppTheme.onAccent : AppTheme.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.inkSubtle),
            ],
          ),
        ),
      ),
    );
  }
}
