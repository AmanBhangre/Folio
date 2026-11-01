import 'package:flutter/material.dart';

/// Design tokens copied 1:1 from the web replica (the `:root` block of
/// folio.html). Change a value here and every screen follows; screens never
/// hard-code a color.
@immutable
class FolioColors extends ThemeExtension<FolioColors> {
  const FolioColors({
    required this.bg,
    required this.panel,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.bad,
    required this.badSoft,
    required this.gameBg,
    required this.gameFg,
  });

  final Color bg, panel, surface, surface2, line, fg, muted;
  final Color accent, accentInk, accentSoft;
  final Color good, goodSoft, warn, warnSoft, bad, badSoft;
  final Color gameBg, gameFg;

  static const light = FolioColors(
    bg: Color(0xFFF3F1EC),
    panel: Color(0xFFFFFFFF),
    surface: Color(0xFFF8F6F2),
    surface2: Color(0xFFECE8E1),
    line: Color(0xFFDDD7CD),
    fg: Color(0xFF1C1A17),
    muted: Color(0xFF5E5850),
    accent: Color(0xFFB8650F),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF6E6D2),
    good: Color(0xFF1F7A68),
    goodSoft: Color(0xFFDCF0EA),
    warn: Color(0xFF9A5B00),
    warnSoft: Color(0xFFFBEBCF),
    bad: Color(0xFFB23A2E),
    badSoft: Color(0xFFF7DEDA),
    gameBg: Color(0xFF0E0F11),
    gameFg: Color(0xFFE9E6E0),
  );

  static const dark = FolioColors(
    bg: Color(0xFF121315),
    panel: Color(0xFF1A1C1F),
    surface: Color(0xFF202327),
    surface2: Color(0xFF2A2E33),
    line: Color(0xFF353A40),
    fg: Color(0xFFF1EEE8),
    muted: Color(0xFFA9A398),
    accent: Color(0xFFF0A24A),
    accentInk: Color(0xFF1F1406),
    accentSoft: Color(0xFF3A2A16),
    good: Color(0xFF5CC8B0),
    goodSoft: Color(0xFF163430),
    warn: Color(0xFFF2C062),
    warnSoft: Color(0xFF3A2E14),
    bad: Color(0xFFFF8A7A),
    badSoft: Color(0xFF3D1D19),
    gameBg: Color(0xFF08090A),
    gameFg: Color(0xFFE9E6E0),
  );

  /// Cover colors for games that ship no cover art. White text sits on all of
  /// them in both themes, so they are not theme tokens.
  static const covers = <Color>[
    Color(0xFF4E3F7A),
    Color(0xFF2F5D62),
    Color(0xFF7A4A2C),
    Color(0xFF334A6E),
    Color(0xFF5E3B4E),
    Color(0xFF3E5A3A),
    Color(0xFF6B3F3F),
  ];
  static const coverInk = Color(0xFFF7F4EE);

  @override
  FolioColors copyWith() => this;

  @override
  FolioColors lerp(FolioColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FolioColors(
      bg: l(bg, other.bg),
      panel: l(panel, other.panel),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      fg: l(fg, other.fg),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      accentSoft: l(accentSoft, other.accentSoft),
      good: l(good, other.good),
      goodSoft: l(goodSoft, other.goodSoft),
      warn: l(warn, other.warn),
      warnSoft: l(warnSoft, other.warnSoft),
      bad: l(bad, other.bad),
      badSoft: l(badSoft, other.badSoft),
      gameBg: l(gameBg, other.gameBg),
      gameFg: l(gameFg, other.gameFg),
    );
  }
}

/// Radii, heights and gaps from the replica's CSS, in logical pixels.
abstract final class FolioSize {
  static const radiusButton = 12.0;
  static const radiusButtonSm = 10.0;
  static const radiusCard = 16.0;
  static const radiusCover = 14.0;
  static const radiusSheet = 22.0;
  static const buttonHeight = 46.0;
  static const buttonHeightSm = 36.0;
  static const touch = 44.0;
  static const screenPadH = 18.0;
  static const screenPadTop = 20.0;
  static const sectionGap = 18.0;
}

extension FolioThemeX on BuildContext {
  FolioColors get c => Theme.of(this).extension<FolioColors>()!;
}
