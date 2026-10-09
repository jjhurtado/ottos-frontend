import 'package:flutter/material.dart';

import 'ottos_colors.dart';

/// Material 3 theme built on the brand colors.
abstract final class OttosTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: OttosColors.navy,
      primary: OttosColors.navy,
      onPrimary: Colors.white,
      secondary: OttosColors.teal,
      onSecondary: Colors.white,
      tertiary: OttosColors.cream,
      onTertiary: OttosColors.navy,
      error: OttosColors.danger,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: OttosColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: OttosColors.navy,
        indicatorColor: OttosColors.teal,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: OttosColors.cream.withValues(alpha: 0.7)),
        selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: OttosColors.cream.withValues(alpha: 0.7)),
      ),
      navigationBarTheme: const NavigationBarThemeData(indicatorColor: OttosColors.cream),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OttosColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: OttosColors.teal, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: const ChipThemeData(side: BorderSide.none),
    );
  }
}
