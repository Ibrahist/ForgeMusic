import 'package:flutter/material.dart';

/// The warm night palette used across Forgemusic.
class ForgeColors {
  static const ink = Color(0xFF16130F);
  static const paper = Color(0xFFF6F0E7);
  static const paperDeep = Color(0xFFEADFD2);
  static const night = Color(0xFF110E0C);
  static const nightRaised = Color(0xFF1C1814);
  static const nightCard = Color(0xFF26211C);
  static const ember = Color(0xFFE8884E);
  static const gold = Color(0xFFE7C7A1);
  static const mist = Color(0xFFA89888);
  static const good = Color(0xFF7EAA78);
  static const danger = Color(0xFFE36B5A);

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? nightCard : Colors.white;
  }
}

/// Keeps album colors in a range that still reads on the night background.
Color tuneAccent(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.35, 0.72))
      .withLightness(hsl.lightness.clamp(0.45, 0.62))
      .toColor();
}

ThemeData forgeTheme(Brightness brightness, Color accent) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: accent,
    onPrimary: dark ? const Color(0xFF1A120C) : Colors.white,
    secondary: ForgeColors.gold,
    onSecondary: ForgeColors.ink,
    surface: dark ? ForgeColors.night : ForgeColors.paper,
    onSurface: dark ? ForgeColors.paper : ForgeColors.ink,
    error: ForgeColors.danger,
    onError: Colors.white,
  );
  const outfit = TextStyle(fontFamily: 'Outfit');
  final titles = TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w600,
    color: scheme.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? ForgeColors.night : ForgeColors.paper,
    fontFamily: 'Outfit',
    textTheme: TextTheme(
      displaySmall: titles.copyWith(fontSize: 40, height: 1.05),
      headlineSmall: titles.copyWith(fontSize: 28, height: 1.1),
      titleLarge: titles.copyWith(fontSize: 22),
      titleMedium: outfit.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: outfit.copyWith(fontSize: 16, height: 1.4, color: scheme.onSurface),
      bodyMedium: outfit.copyWith(fontSize: 14, height: 1.4, color: scheme.onSurface),
      bodySmall: outfit.copyWith(fontSize: 13, height: 1.3, color: ForgeColors.mist),
      labelLarge: outfit.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: titles.copyWith(fontSize: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? ForgeColors.nightRaised : ForgeColors.paperDeep,
      indicatorColor: accent.withValues(alpha: 0.24),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: dark ? const Color(0xFF1A120C) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: ForgeColors.mist.withValues(alpha: 0.3),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? ForgeColors.nightCard : ForgeColors.ink,
      contentTextStyle: const TextStyle(fontFamily: 'Outfit', color: ForgeColors.paper),
    ),
    dividerTheme: DividerThemeData(color: ForgeColors.mist.withValues(alpha: 0.22)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
  );
}
