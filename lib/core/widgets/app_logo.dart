import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// In-app brand mark — hand-drawn Memos bird on pure white.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.borderRadius,
    this.padded = true,
    this.showBorder = false,
  });

  /// Outer box size.
  final double size;

  /// Corner radius (null = soft radius from size).
  final double? borderRadius;

  /// Inner padding so the bird stays readable.
  final bool padded;

  /// Optional hairline border (off by default on white canvas).
  final bool showBorder;

  static const assetPath = 'assets/icons/app_logo_sketch.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.2).clamp(10.0, 20.0);
    final pad = padded ? size * 0.04 : 0.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: AppTheme.line.withValues(alpha: 0.9))
            : null,
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
