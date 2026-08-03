import 'package:flutter/material.dart';

/// Visual identity: calm field-notebook for Memos.
/// Warm paper, ink, deep sea-green accent — not default purple Material.
abstract final class AppTheme {
  // Named palette
  static const paper = Color(0xFFF3F0EA);
  static const paperElevated = Color(0xFFFCFAF6);
  static const ink = Color(0xFF1C1B19);
  static const inkMuted = Color(0xFF6E6860);
  static const line = Color(0xFFE3DDD3);
  static const accent = Color(0xFF2F6F5E);
  static const accentSoft = Color(0xFFD7E8E1);
  static const danger = Color(0xFFB42318);

  static const paperDark = Color(0xFF141513);
  static const paperElevatedDark = Color(0xFF1E201D);
  static const inkDark = Color(0xFFF2EFE8);
  static const inkMutedDark = Color(0xFFA39C92);
  static const lineDark = Color(0xFF2C2F2B);
  static const accentDark = Color(0xFF6FBFAB);

  static const defaultSeed = accent;

  static ThemeData light([Color seed = accent]) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      outlineVariant: line,
      error: danger,
    ).copyWith(
      surfaceContainerLowest: paperElevated,
      surfaceContainerLow: paperElevated,
      surfaceContainerHighest: const Color(0xFFECE7DE),
      primaryContainer: accentSoft,
      onPrimaryContainer: const Color(0xFF0F3D32),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paper.withValues(alpha: 0.92),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevated,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: paperElevated,
        indicatorColor: accentSoft,
        selectedIconTheme: IconThemeData(color: seed, size: 22),
        unselectedIconTheme: const IconThemeData(color: inkMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: seed,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperElevated,
        hintStyle: const TextStyle(color: inkMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paperElevated,
        selectedColor: accentSoft,
        disabledColor: line,
        deleteIconColor: inkMuted,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Explicit ink color — avoid white-on-light chips from Material defaults.
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      // SegmentedButton selected state can default to low-contrast / near-white labels.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return seed;
            }
            return inkMuted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentSoft;
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: line)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        iconColor: inkMuted,
      ),
    );
  }

  static ThemeData dark([Color seed = accentDark]) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: seed,
      surface: paperDark,
      onSurface: inkDark,
      onSurfaceVariant: inkMutedDark,
      outlineVariant: lineDark,
    ).copyWith(
      surfaceContainerLowest: paperElevatedDark,
      primaryContainer: const Color(0xFF1F3D35),
      onPrimaryContainer: accentSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paperDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: paperDark.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: inkDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevatedDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lineDark),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lineDark, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: paperDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: paperDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
