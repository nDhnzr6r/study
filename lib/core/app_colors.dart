import 'package:flutter/material.dart';

class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color danger;
  final Color warning;
  final Color success;
  final Color info;

  static const light = AppColors(
    background: Color(0xFFF4F1E9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEBE0),
    primary: Color(0xFF2E6B52),
    primarySoft: Color(0xFFE2EFE7),
    accent: Color(0xFFB2824C),
    accentSoft: Color(0xFFF4E9DA),
    textPrimary: Color(0xFF23271F),
    textSecondary: Color(0xFF6D7365),
    border: Color(0xFFE1DCCE),
    danger: Color(0xFFB05247),
    warning: Color(0xFFAD7730),
    success: Color(0xFF3F7D5C),
    info: Color(0xFF4B6E9C),
  );

  static const dark = AppColors(
    background: Color(0xFF141613),
    surface: Color(0xFF1C1F1B),
    surfaceAlt: Color(0xFF252922),
    primary: Color(0xFF8DC4A7),
    primarySoft: Color(0xFF24372C),
    accent: Color(0xFFD6AE78),
    accentSoft: Color(0xFF3A3023),
    textPrimary: Color(0xFFECEDE6),
    textSecondary: Color(0xFFA0A79A),
    border: Color(0xFF32372F),
    danger: Color(0xFFDF8A7F),
    warning: Color(0xFFD5A45E),
    success: Color(0xFF86BE9C),
    info: Color(0xFF8FAED6),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
