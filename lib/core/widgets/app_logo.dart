import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand mark — AppFlowy-style memo card icon (asset already rounded).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.borderRadius,
    this.padded = false,
    this.showBorder = false,
  });

  final double size;
  final double? borderRadius;
  final bool padded;
  final bool showBorder;

  static const assetPath = 'assets/icons/app_logo_sketch.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22).clamp(6.0, 14.0);
    final pad = padded ? size * 0.04 : 0.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: showBorder ? AppTheme.paperElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: AppTheme.line, width: 1)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(pad),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.sticky_note_2_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}
