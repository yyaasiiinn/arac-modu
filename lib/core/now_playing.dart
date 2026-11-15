import 'package:flutter/foundation.dart';

import 'in_app_player.dart';
import 'music_service.dart';

/// "Şu An Çalan" için tek kaynak: Apple Music veya uygulamanın kendi oynatıcısı
/// (radyo/podcast) — hangisi en son başlatıldıysa.
class NowPlaying {
  static bool preferInApp = false;

  static Listenable get listenable => Listenable.merge([MusicService.I, InAppPlayer.I]);

  static bool get inApp {
    final ip = InAppPlayer.I;
    final m = MusicService.I;
    if (ip.isPlaying) return true;
    if (m.isPlaying) return false;
    return preferInApp && ip.active;
  }

  static bool get hasItem => inApp ? InAppPlayer.I.active : MusicService.I.hasItem;
  static bool get isPlaying => inApp ? InAppPlayer.I.isPlaying : MusicService.I.isPlaying;
  static String get title => inApp ? InAppPlayer.I.title : MusicService.I.title;
  static String get subtitle => inApp ? InAppPlayer.I.subtitle : MusicService.I.artist;
  static bool get isLive => inApp && InAppPlayer.I.isLive;

  static double get progress {
    if (inApp) {
      final ip = InAppPlayer.I;
      if (ip.isLive || ip.duration.inMilliseconds == 0) return 0;
      return (ip.position.inMilliseconds / ip.duration.inMilliseconds).clamp(0.0, 1.0);
    }
    final m = MusicService.I;
    return m.duration > 0 ? (m.position / m.duration).clamp(0.0, 1.0) : 0;
  }

  static Future<void> playPause() => inApp ? InAppPlayer.I.playPause() : MusicService.I.playPause();
  static Future<void> next() => inApp ? InAppPlayer.I.next() : MusicService.I.next();
  static Future<void> previous() => inApp ? InAppPlayer.I.previous() : MusicService.I.previous();
  static Future<void> pause() async {
    await InAppPlayer.I.pause();
    await MusicService.I.pause();
  }
}
