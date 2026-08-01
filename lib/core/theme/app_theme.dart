import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Fallback seed when dynamic color is loading / unavailable (Monochrome)
  static const _seedColor = Color(0xFF000000);

  static const successColor = Color(0xFF34D399);
  static const warningColor = Color(0xFFFBBF24);
  static const proteinColor = Color(0xFF60A5FA);
  static const carbsColor = Color(0xFFA78BFA);
  static const fatColor = Color(0xFFF472B6);

  /// Build a light theme, optionally seeded from the device wallpaper or custom seed.
  static ThemeData light({ColorScheme? dynamic, Color? seedColor}) =>
      _buildTheme(Brightness.light, dynamic, seedColor);

  /// Build a dark theme, optionally seeded from the device wallpaper or custom seed.
  static ThemeData dark({ColorScheme? dynamic, Color? seedColor}) =>
      _buildTheme(Brightness.dark, dynamic, seedColor);

  // Keep legacy static getters for any code that still references them.
  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();

  static ThemeData _buildTheme(Brightness brightness, ColorScheme? dynamic, Color? customSeed) {
    final isDark = brightness == Brightness.dark;
    final seed = dynamic?.primary ?? customSeed ?? _seedColor;
    final isMonotone = seed.toARGB32() == 0xFF000000;

    final ColorScheme colorScheme;
    final Color cardDark;
    final Color surfaceDark;
    final Color surfaceVariantDark;

    if (isMonotone) {
      surfaceDark = const Color(0xFF09090B);
      surfaceVariantDark = const Color(0xFF18181B);
      cardDark = const Color(0xFF18181B);

      colorScheme = isDark
          ? const ColorScheme.dark(
              primary: Color(0xFFFAFAFA),
              onPrimary: Color(0xFF09090B),
              primaryContainer: Color(0xFF27272A),
              onPrimaryContainer: Colors.white,
              surface: Color(0xFF09090B),
              onSurface: Color(0xFFFAFAFA),
              surfaceContainerHighest: Color(0xFF18181B),
              surfaceContainerLowest: Color(0xFF09090B),
              outline: Color(0xFFA1A1AA),
            )
          : const ColorScheme.light(
              primary: Color(0xFF18181B),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFF27272A),
              onPrimaryContainer: Colors.white,
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF09090B),
              surfaceContainerHighest: Color(0xFFF4F4F5),
              surfaceContainerLowest: Color(0xFFFAFAFA),
              outline: Color(0xFF71717A),
            );
    } else {
      final hsl = HSLColor.fromColor(seed);

      surfaceDark = hsl
          .withLightness(0.06)
          .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
          .toColor();

      surfaceVariantDark = hsl
          .withLightness(0.09)
          .withSaturation((hsl.saturation * 0.30).clamp(0.0, 1.0))
          .toColor();

      cardDark = hsl
          .withLightness(0.12)
          .withSaturation((hsl.saturation * 0.30).clamp(0.0, 1.0))
          .toColor();

      final primaryContainerDark = hsl
          .withLightness(0.24)
          .withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
          .toColor();

      final baseColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        surface: isDark ? surfaceDark : const Color(0xFFF8F8FF),
        surfaceContainerHighest: isDark ? cardDark : Colors.white,
      );

      colorScheme = isDark
          ? baseColorScheme.copyWith(
              primaryContainer: primaryContainerDark,
              onPrimaryContainer: Colors.white,
            )
          : baseColorScheme;
    }

    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final scaffoldBg = isDark ? surfaceDark : colorScheme.surface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardThemeData(
        color: isDark ? cardDark : colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? surfaceVariantDark
            : colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(
              color: colorScheme.onSurface.withValues(alpha: 0.5));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return isDark
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(
              color: isMonotone
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
                  : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
        trackShape: const RoundedRectSliderTrackShape(),
        valueIndicatorColor: colorScheme.primaryContainer,
        valueIndicatorTextStyle:
            TextStyle(color: colorScheme.onPrimaryContainer),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? surfaceVariantDark
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? cardDark : colorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }
}
