import 'package:material_ui/material_ui.dart';

/// iOS sistem renkleri (koyu mod tonları).
class CP {
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const yellow = Color(0xFFFFD60A);
  static const pink = Color(0xFFFF375F);
  static const purple = Color(0xFFBF5AF2);
  static const teal = Color(0xFF64D2FF);
  static const indigo = Color(0xFF5E5CE6);
  static const gray = Color(0xFF8E8E93);
}

/// Ekranın o anki (koyu/açık) renk takımı.
class Palette {
  final bool dark;
  const Palette(this.dark);

  static Palette of(BuildContext context) =>
      Palette(Theme.of(context).brightness == Brightness.dark);

  Color get bg => dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get card => dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get card2 => dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get card3 => dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6);
  Color get text => dark ? Colors.white : Colors.black;
  Color get subtext => dark ? const Color(0xFF98989F) : const Color(0xFF6C6C70);
  Color get divider => dark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
  Color get sidebar => dark ? const Color(0xF0161618) : const Color(0xF0FFFFFF);
}

/// Ana ekran duvar kağıtları.
const wallpapers = <List<Color>>[
  [Color(0xFF0B0B0F), Color(0xFF1B1E2B)],
  [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  [Color(0xFF1A0B2E), Color(0xFF3B1C5A), Color(0xFF6A2C70)],
  [Color(0xFF0B3D2E), Color(0xFF145A42), Color(0xFF1F7A5A)],
  [Color(0xFF3A0A0A), Color(0xFF7A1F1F), Color(0xFFB33939)],
  [Color(0xFF0A1931), Color(0xFF185ADB), Color(0xFF4A90E2)],
];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final p = Palette(dark);
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CP.blue,
      brightness: b,
      primary: CP.blue,
      surface: p.card,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: p.divider,
    textTheme: Typography.material2021(platform: TargetPlatform.iOS)
        .englishLike
        .apply(bodyColor: p.text, displayColor: p.text),
  );
}
