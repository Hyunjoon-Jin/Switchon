import 'package:flutter/material.dart';

/// 앱 테마 — "스위치를 켠다" 컨셉의 프리미엄 다크 글라스.
/// 깊은 에메랄드/틸 그라데이션 위에 프로스티드 글라스 카드를 올리는 디자인.
/// 극단적 톤(자극적 색·강한 경고색)은 절제 — 차분하고 고급스럽게.
class AppTheme {
  AppTheme._();

  // 브랜드 컬러
  static const Color emerald = Color(0xFF34E0A1); // 메인 민트 에메랄드
  static const Color teal = Color(0xFF5EEAD4); // 보조 틸
  static const Color sky = Color(0xFF7CC5FF); // 포인트 스카이
  static const Color softCoral = Color(0xFFFF8C9C); // 부드러운 경고색

  // 글라스 토큰
  static Color glassFill(Brightness b) => b == Brightness.dark
      ? Colors.white.withOpacity(0.07)
      : Colors.white.withOpacity(0.55);
  static Color glassBorder(Brightness b) => b == Brightness.dark
      ? Colors.white.withOpacity(0.16)
      : Colors.white.withOpacity(0.65);

  // 배경 그라데이션
  static const List<Color> bgDark = [
    Color(0xFF0C1B17),
    Color(0xFF0A1A22),
    Color(0xFF0E1330),
  ];
  static const List<Color> bgLight = [
    Color(0xFFEAF6F0),
    Color(0xFFE6F1F4),
    Color(0xFFEFEDF8),
  ];

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? emerald : const Color(0xFF1F9D6E),
      secondary: teal,
      tertiary: sky,
      error: softCoral,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final onSurface = scheme.onSurface;

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: _textTheme(base.textTheme, onSurface),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF18241F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: glassFill(brightness),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: glassBorder(brightness)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(isDark ? 0.22 : 0.18),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: onSurface.withOpacity(0.9)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : onSurface.withOpacity(0.6),
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? const Color(0xFF06251A) : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: glassBorder(brightness)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? scheme.primary.withOpacity(0.22)
                  : Colors.transparent),
          side: WidgetStatePropertyAll(
              BorderSide(color: glassBorder(brightness))),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: glassFill(brightness),
        side: BorderSide(color: glassBorder(brightness)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassFill(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassBorder(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassBorder(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF14211D)
            : Colors.white.withOpacity(0.92),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: DividerThemeData(
        color: glassBorder(brightness),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1C2A26) : null,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    return base
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(
          headlineSmall: base.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
          titleLarge: base.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        );
  }
}
