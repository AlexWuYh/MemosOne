import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// In-app brand mark — hand-drawn Memos bird on paper.
///
/// Designed to read clearly at 40–72px (not a dense app-store badge).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.padded = true,
  });

  /// Outer box size.
  final double size;

  /// Corner radius of the paper plate (null = soft notebook radius).
  final double? borderRadius;

  /// Add inner padding so the bird stays large and clear.
  final bool padded;

  static const assetPath = 'assets/icons/app_logo_sketch.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22).clamp(10.0, 18.0);
    final pad = padded ? size * 0.08 : 0.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.paperElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.85)),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(pad),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Icon(
          Icons.auto_stories_rounded,
          color: AppTheme.accent,
          size: size * 0.45,
        ),
      ),
    );
  }
}
