import 'package:flutter/material.dart';

/// Hopper's palette: signal orange on deep slate. Orange = the brand and anything
/// "live"; blue = information; no green anywhere.
class HopperColors {
  static const ink = Color(0xFF16213A);       // darkest text / hero card
  static const ink2 = Color(0xFF3B4A66);      // body text on light
  static const mid = Color(0xFF6E7B93);       // secondary text
  static const line = Color(0xFFE1E6EF);      // borders on light
  static const soft = Color(0xFFF1F4F9);      // soft fills on light
  static const accent = Color(0xFFFF6A3D);    // signal orange
  static const accentDeep = Color(0xFFE2542B);
  static const accentSoft = Color(0xFFFFE9E1);
  static const blue = Color(0xFF3B6CF0);
  static const blueSoft = Color(0xFFE6EDFF);
  // "ok" is intentionally the accent family, not green.
  static const ok = accent;
  static const okSoft = accentSoft;

  // dark surfaces
  static const dBg = Color(0xFF0E1420);
  static const dCard = Color(0xFF161E2E);
  static const dCard2 = Color(0xFF1D2738);
  static const dLine = Color(0xFF283349);
  static const dText = Color(0xFFEAF0FA);
  static const dMuted = Color(0xFF93A0B8);
}

/// Colors that depend on the current brightness.
class HopperTheme {
  final bool dark;
  const HopperTheme(this.dark);
  factory HopperTheme.of(BuildContext c) => HopperTheme(Theme.of(c).brightness == Brightness.dark);

  Color get card => dark ? HopperColors.dCard : Colors.white;
  Color get card2 => dark ? HopperColors.dCard2 : HopperColors.soft;
  Color get line => dark ? HopperColors.dLine : HopperColors.line;
  Color get text => dark ? HopperColors.dText : HopperColors.ink;
  Color get muted => dark ? HopperColors.dMuted : HopperColors.mid;
  Color get accentSoft => dark ? const Color(0xFF3A2416) : HopperColors.accentSoft;
  Color get blueSoft => dark ? const Color(0xFF1B2A4D) : HopperColors.blueSoft;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final t = HopperTheme(dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: HopperColors.accent,
    brightness: b,
    primary: HopperColors.accent,
    onPrimary: Colors.white,
    secondary: HopperColors.blue,
    surface: dark ? HopperColors.dCard : Colors.white,
    onSurface: t.text,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final textTheme = base.textTheme.apply(bodyColor: t.text, displayColor: t.text).copyWith(
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: t.text),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.text),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: t.text),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.4, color: t.muted),
    labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? HopperColors.dBg : const Color(0xFFF6F8FB),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: t.text,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: t.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.line)),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.muted,
      titleTextStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      subtitleTextStyle: textTheme.bodySmall,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: HopperColors.accent, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: t.text,
      side: BorderSide(color: t.line),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      foregroundColor: HopperColors.accent,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    )),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HopperColors.accent : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : null),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HopperColors.accent : t.muted)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? HopperColors.accent : t.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? HopperColors.accent : t.muted)),
      height: 68,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(
      side: WidgetStateProperty.all(BorderSide(color: t.line)),
      backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accentSoft : t.card),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HopperColors.accentDeep : t.muted),
      textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: t.card2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HopperColors.accent, width: 1.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? HopperColors.dCard2 : HopperColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: t.line,
    dialogTheme: DialogThemeData(backgroundColor: t.card, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: t.card, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    popupMenuTheme: PopupMenuThemeData(color: t.card, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.line))),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: textTheme.bodyMedium),
  );
}
