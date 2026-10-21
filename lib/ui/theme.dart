import 'package:flutter/material.dart';

import '../core/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors palette, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: isLight ? Colors.white : const Color(0xFF10241A),
          primaryContainer: palette.primarySoft,
          onPrimaryContainer: isLight ? palette.primary : palette.textPrimary,
          secondary: palette.accent,
          onSecondary: Colors.white,
          secondaryContainer: palette.accentSoft,
          onSecondaryContainer: palette.textPrimary,
          surface: palette.surface,
          onSurface: palette.textPrimary,
          surfaceContainerHighest: palette.surfaceAlt,
          outline: palette.border,
          outlineVariant: palette.border,
          error: palette.danger,
          onError: Colors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
      fontFamilyFallback: const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'Segoe UI',
      ],
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: isLight ? Colors.white : const Color(0xFF10241A),
          disabledBackgroundColor: palette.surfaceAlt,
          disabledForegroundColor: palette.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textSecondary,
          highlightColor: palette.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.danger, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(fontSize: 13, color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(fontSize: 13, color: palette.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: palette.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
        textStyle: TextStyle(fontSize: 14, color: palette.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? const Color(0xFF23271F) : palette.surfaceAlt,
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : palette.textPrimary,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(24),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFF23271F) : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(
          color: isLight ? Colors.white : palette.textPrimary,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 450),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          palette.textSecondary.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(8),
      ),
    );
  }
}
