import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF2563EB);
  static const teal = Color(0xFF0F766E);
  static const canvas = Color(0xFFF4F7FA);
  static const border = Color(0xFFDCE3EA);
  static const muted = Color(0xFF627487);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: teal,
      surface: Colors.white,
      onSurface: navy,
      error: const Color(0xFFB42318),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: navy,
          fontSize: 32,
          height: 1.18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        headlineMedium: const TextStyle(
          color: navy,
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineSmall: const TextStyle(
          color: navy,
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          color: navy,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: navy,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: Color(0xFF334E68), height: 1.5),
        bodyMedium: const TextStyle(color: Color(0xFF486581), height: 1.45),
        bodySmall: const TextStyle(color: muted, height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        toolbarHeight: 48,
        titleSpacing: 8,
        backgroundColor: Colors.white,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      tabBarTheme: const TabBarThemeData(
        labelColor: navy,
        unselectedLabelColor: muted,
        indicatorColor: blue,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: Color(0xFF9AA9B7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0xFFE7EFFD),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? navy : muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: blue,
        unselectedItemColor: muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: blue),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
