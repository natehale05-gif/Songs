import 'package:flutter/material.dart';

/// Design tokens ported from the original web app's CSS custom properties.
class AppPalette {
  final Color bg;
  final Color surface;
  final Color surfaceGrouped;
  final Color fill1;
  final Color fill2;
  final Color separator;
  final Color label;
  final Color label2;
  final Color label3;
  final Color label4;
  final Color accent;
  final Color navy;
  final Color navyText;
  final Brightness brightness;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceGrouped,
    required this.fill1,
    required this.fill2,
    required this.separator,
    required this.label,
    required this.label2,
    required this.label3,
    required this.label4,
    required this.accent,
    required this.navy,
    required this.navyText,
    required this.brightness,
  });

  static const light = AppPalette(
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceGrouped: Color(0xFFF2F2F7),
    fill1: Color(0x1F78787F),
    fill2: Color(0x2978787F),
    separator: Color(0x2E3C3C43),
    label: Color(0xFF000000),
    label2: Color(0xC73C3C43),
    label3: Color(0x8C3C3C43),
    label4: Color(0x4D3C3C43),
    accent: Color(0xFF007AFF),
    navy: Color(0xFF1C3975),
    navyText: Color(0xFFFFFFFF),
    brightness: Brightness.light,
  );

  static const dark = AppPalette(
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceGrouped: Color(0xFF000000),
    fill1: Color(0x3D76767F),
    fill2: Color(0x5276767F),
    separator: Color(0xA6545458),
    label: Color(0xFFFFFFFF),
    label2: Color(0xC7EBEBF5),
    label3: Color(0x8CEBEBF5),
    label4: Color(0x33EBEBF5),
    accent: Color(0xFF0A84FF),
    navy: Color(0xFF2A52A8),
    navyText: Color(0xFFFFFFFF),
    brightness: Brightness.dark,
  );
}

/// Reader-specific palette (the immersive song view).
class ReaderPalette {
  final Color bg;
  final Color surface;
  final Color text;
  final Color text2;
  final Color text3;
  final Color sep;
  final Color accent;
  final Color green;
  final Color btnBg;
  final Color btnActive;
  final Color chorusBg;
  final Color chorusBorder;
  final Brightness brightness;

  const ReaderPalette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.text2,
    required this.text3,
    required this.sep,
    required this.accent,
    required this.green,
    required this.btnBg,
    required this.btnActive,
    required this.chorusBg,
    required this.chorusBorder,
    required this.brightness,
  });

  static const dark = ReaderPalette(
    bg: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    text2: Color(0x9EEBEBF5),
    text3: Color(0x52EBEBF5),
    sep: Color(0x1AFFFFFF),
    accent: Color(0xFFFFD54A),
    green: Color(0xFF30D158),
    btnBg: Color(0x1AFFFFFF),
    btnActive: Color(0x33FFFFFF),
    chorusBg: Color(0xFF1A2E1F),
    chorusBorder: Color(0x3830D158),
    brightness: Brightness.dark,
  );

  static const light = ReaderPalette(
    bg: Color(0xFFF8F7F3),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    text2: Color(0xC73C3C43),
    text3: Color(0x733C3C43),
    sep: Color(0x243C3C43),
    accent: Color(0xFFB07D10),
    green: Color(0xFF1C7A2B),
    btnBg: Color(0x2478787F),
    btnActive: Color(0x3D78787F),
    chorusBg: Color(0xFFEDF6ED),
    chorusBorder: Color(0x381C7A2B),
    brightness: Brightness.light,
  );
}

/// Colored dot per song category.
Color categoryColor(String category) {
  switch (category) {
    case 'praise':
      return const Color(0xFF34C759);
    case 'communion':
      return const Color(0xFFFF3B30);
    case 'invitation':
      return const Color(0xFF007AFF);
    case 'prayer':
      return const Color(0xFFAF52DE);
    case 'comfort':
      return const Color(0xFFFF9500);
    case 'christmas':
      return const Color(0xFFFF2D55);
    case 'baptism':
      return const Color(0xFF5AC8FA);
    default:
      return const Color(0xFF8E8E93);
  }
}

/// Serif display font stack used for song lyrics, matching the web app feel.
const String kDisplaySerif = 'Georgia';
