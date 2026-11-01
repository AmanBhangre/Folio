import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type roles from the replica: Bricolage Grotesque for display, Figtree for
/// body, JetBrains Mono for labels and numbers.
abstract final class FolioType {
  static TextStyle display(Color color, {double size = 28, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, height: 1.1, letterSpacing: -0.28, color: color);

  static TextStyle heading(Color color, {double size = 19}) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: FontWeight.w600, height: 1.15, color: color);

  static TextStyle body(Color color, {double size = 15, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.figtree(fontSize: size, fontWeight: weight, height: 1.45, color: color);

  /// Uppercase section labels ("CONTINUE PLAYING").
  static TextStyle label(Color color) =>
      GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.92, color: color);

  static TextStyle mono(Color color, {double size = 13}) => GoogleFonts.jetBrainsMono(
      fontSize: size, color: color, fontFeatures: const [FontFeature.tabularFigures()]);
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? FolioColors.dark : FolioColors.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      surface: c.panel,
      onSurface: c.fg,
      error: c.bad,
    ),
    scaffoldBackgroundColor: c.panel,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: GoogleFonts.figtree().fontFamily, bodyColor: c.fg, displayColor: c.fg),
    dividerColor: c.line,
    sliderTheme: SliderThemeData(activeTrackColor: c.accent, thumbColor: c.accent, inactiveTrackColor: c.surface2),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent),
  );
}
