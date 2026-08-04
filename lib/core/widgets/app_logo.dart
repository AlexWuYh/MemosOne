import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// In-app brand mark (Memos bird / Memos One icon).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 36,
    this.borderRadius,
    this.showBorder = true,
  });

  final double size;
  final double? borderRadius;
  final bool showBorder;

  static const assetPath = 'assets/icons/app_icon_128.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.28).clamp(8.0, 16.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: AppTheme.line) : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppTheme.accentSoft,
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_stories_rounded,
            color: AppTheme.accent,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
