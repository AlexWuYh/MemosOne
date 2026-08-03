import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../feature/home/presentation/home_shell.dart';
import '../feature/onboarding/presentation/onboarding_page.dart';
import 'providers.dart';

class MemosOneApp extends ConsumerWidget {
  const MemosOneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final needsOnboarding = ref.watch(needsOnboardingProvider);
    final workspaces = ref.watch(workspacesProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      home: workspaces.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('启动失败: $e')),
        ),
        data: (_) =>
            needsOnboarding ? const OnboardingPage() : const HomeShell(),
      ),
    );
  }
}
