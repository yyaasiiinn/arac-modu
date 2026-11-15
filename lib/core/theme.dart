import 'package:material_ui/material_ui.dart';

/// iOS sistem renkleri (koyu mod tonları). Diva Modu açıkken vurgu renkleri pembeleşir.
class CP {
  /// AppState tarafından ayarlanır.
  static bool diva = false;

  static const hotPink = Color(0xFFFF1493);
  static const pink = Color(0xFFFF4FA3);
  static const softPink = Color(0xFFFF8CC6);
  static const deepPink = Color(0xFFC2185B);

  static Color get blue => diva ? hotPink : const Color(0xFF0A84FF);
  static Color get green => diva ? pink : const Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static Color get orange => diva ? const Color(0xFFFF6FB5) : const Color(0xFFFF9F0A);
  static const yellow = Color(0xFFFFD60A);
  static Color get purple => diva ? const Color(0xFFD63384) : const Color(0xFFBF5AF2);
  static Color get teal => diva ? softPink : const Color(0xFF64D2FF);
  static Color get indigo => diva ? deepPink : const Color(0xFF5E5CE6);
  static const gray = Color(0xFF8E8E93);
}

/// Ekranın o anki (koyu/açık) renk takımı.
class Palette {
  final bool dark;
  final bool diva;
  const Palette(this.dark, {this.diva = false});

  static Palette of(BuildContext context) {
    // Theme'e her zaman bağlan ki Diva Modu açılıp kapanınca yeniden çizilsin.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CP.diva ? const Palette(false, diva: true) : Palette(dark);
  }

  Color get bg => diva ? const Color(0xFFFFE3F1) : (dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7));
  Color get card => diva ? const Color(0xFFFFF5FA) : (dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF));
  Color get card2 => diva ? const Color(0xFFFFCCE5) : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA));
  Color get card3 => diva ? const Color(0xFFFFA8D3) : (dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6));
  Color get text => diva ? const Color(0xFF5C0A36) : (dark ? Colors.white : Colors.black);
  Color get subtext => diva ? const Color(0xFFB4457F) : (dark ? const Color(0xFF98989F) : const Color(0xFF6C6C70));
  Color get divider => diva ? const Color(0xFFF7B8D7) : (dark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8));
  Color get sidebar => diva ? const Color(0xF0FFB8DB) : (dark ? const Color(0xF0161618) : const Color(0xF0FFFFFF));
}

/// Diva Modu duvar kağıdı ve simge renkleri.
const divaWallpaper = [Color(0xFFFFA6D2), Color(0xFFFF4FA3), Color(0xFFC2185B)];
const divaIconGradients = <List<Color>>[
  [Color(0xFFFF8CC6), Color(0xFFFF1493)],
  [Color(0xFFFFB3DA), Color(0xFFFF4FA3)],
  [Color(0xFFF06BB0), Color(0xFFC2185B)],
  [Color(0xFFFF9ED2), Color(0xFFE0218A)],
];

/// Ana ekran duvar kağıtları.
const wallpapers = <List<Color>>[
  [Color(0xFF0B0B0F), Color(0xFF1B1E2B)],
  [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  [Color(0xFF1A0B2E), Color(0xFF3B1C5A), Color(0xFF6A2C70)],
  [Color(0xFF0B3D2E), Color(0xFF145A42), Color(0xFF1F7A5A)],
  [Color(0xFF3A0A0A), Color(0xFF7A1F1F), Color(0xFFB33939)],
  [Color(0xFF0A1931), Color(0xFF185ADB), Color(0xFF4A90E2)],
];

ThemeData buildTheme(Brightness b, {bool diva = false}) {
  final dark = b == Brightness.dark;
  final p = Palette(dark, diva: diva);
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: diva ? CP.hotPink : const Color(0xFF0A84FF),
      brightness: b,
      primary: diva ? CP.hotPink : const Color(0xFF0A84FF),
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
