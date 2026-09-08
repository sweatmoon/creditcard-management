import 'package:flutter/material.dart';

/// 모던 머티리얼 디자인 테마 (인디고/블루 톤)
class AppTheme {
  static const Color primary = Color(0xFF3F51B5); // Indigo
  static const Color primaryDark = Color(0xFF303F9F);
  static const Color accent = Color(0xFF5C6BC0);
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Colors.white;
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFE53935);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F1F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF0FA),
        selectedColor: primary,
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 계정과목별 대표 색상
  static Color categoryColor(String category) {
    switch (category) {
      case '식대':
        return const Color(0xFFFF9800);
      case '교통비(기차)':
        return const Color(0xFF2196F3);
      case '교통비(고속버스)':
        return const Color(0xFF03A9F4);
      case '교통비(자가용 - 주유비)':
        return const Color(0xFF00BCD4);
      case '교통비(자가용 - 통행료)':
        return const Color(0xFF009688);
      case '숙박비':
        return const Color(0xFF9C27B0);
      case '다과비':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF757575);
    }
  }

  /// 계정과목별 아이콘
  static IconData categoryIcon(String category) {
    switch (category) {
      case '식대':
        return Icons.restaurant;
      case '교통비(기차)':
        return Icons.train;
      case '교통비(고속버스)':
        return Icons.directions_bus;
      case '교통비(자가용 - 주유비)':
        return Icons.local_gas_station;
      case '교통비(자가용 - 통행료)':
        return Icons.toll;
      case '숙박비':
        return Icons.hotel;
      case '다과비':
        return Icons.local_cafe;
      default:
        return Icons.receipt_long;
    }
  }
}
