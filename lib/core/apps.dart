import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

enum CarApp {
  home,
  dashboard,
  phone,
  music,
  maps,
  messages,
  nowPlaying,
  calendar,
  radio,
  podcasts,
  settings,
}

class AppInfo {
  final CarApp app;
  final String name;
  final IconData icon;
  final List<Color> colors;
  final Color iconColor;

  /// Dolu ise uygulama içinde değil, dış uygulama olarak açılır.
  final String? url;
  final String? fallbackUrl;

  const AppInfo(
    this.app,
    this.name,
    this.icon,
    this.colors, {
    this.iconColor = Colors.white,
    this.url,
    this.fallbackUrl,
  });

  bool get external => url != null;
}

const appInfos = <CarApp, AppInfo>{
  CarApp.phone: AppInfo(CarApp.phone, 'Telefon', CupertinoIcons.phone_fill,
      [Color(0xFF5BF675), Color(0xFF0CBD2A)]),
  CarApp.music: AppInfo(CarApp.music, 'Müzik', CupertinoIcons.music_note_2,
      [Color(0xFFFF5C77), Color(0xFFFA233B)]),
  CarApp.maps: AppInfo(CarApp.maps, 'Haritalar',
      CupertinoIcons.location_north_fill, [Color(0xFF6DD5A4), Color(0xFF2E9BF0)]),
  CarApp.messages: AppInfo(CarApp.messages, 'Mesajlar',
      CupertinoIcons.chat_bubble_fill, [Color(0xFF67FF81), Color(0xFF01B41F)]),
  CarApp.nowPlaying: AppInfo(CarApp.nowPlaying, 'Şu An Çalan',
      CupertinoIcons.waveform, [Color(0xFFFF6482), Color(0xFFD6266D)]),
  CarApp.calendar: AppInfo(CarApp.calendar, 'Takvim', CupertinoIcons.calendar,
      [Color(0xFFFFFFFF), Color(0xFFF2F2F2)],
      iconColor: CP.red),
  CarApp.radio: AppInfo(CarApp.radio, 'Radyo', CupertinoIcons.radiowaves_right,
      [Color(0xFFFF8A5B), Color(0xFFE8452C)]),
  CarApp.podcasts: AppInfo(CarApp.podcasts, 'Podcast\'ler',
      CupertinoIcons.dot_radiowaves_left_right, [Color(0xFFD56DFB), Color(0xFF872EC4)]),
  CarApp.settings: AppInfo(CarApp.settings, 'Ayarlar',
      CupertinoIcons.gear_alt_fill, [Color(0xFFA2A2A8), Color(0xFF6E6E73)]),
};

/// Ana ekran sırası (CarPlay varsayılan düzenine yakın).
const homeOrder = <CarApp>[
  CarApp.phone,
  CarApp.music,
  CarApp.maps,
  CarApp.messages,
  CarApp.nowPlaying,
  CarApp.radio,
  CarApp.podcasts,
  CarApp.calendar,
  CarApp.settings,
];
