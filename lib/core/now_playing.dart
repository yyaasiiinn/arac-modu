import 'package:flutter/foundation.dart';

import 'in_app_player.dart';
import 'music_service.dart';
import 'web_players.dart';

enum NowSource { apple, inApp, web }

/// "Şu An Çalan" için tek kaynak: Apple Music, uygulamanın kendi oynatıcısı
/// (radyo/podcast) ya da içerideki Spotify / YouTube Music — hangisi çalıyorsa
/// ya da en son hangisi başlatıldıysa.
class NowPlaying {
  static bool preferInApp = false;
  static WebPlayer? preferWeb;

  static Listenable get listenable => Listenable.merge([MusicService.I, InAppPlayer.I, ...WebPlayers.all]);

  static WebPlayer? get _playingWeb {
    for (final w in WebPlayers.all) {
      if (w.isPlaying) return w;
    }
    return null;
  }

  static NowSource get source {
    if (InAppPlayer.I.isPlaying) return NowSource.inApp;
    if (_playingWeb != null) return NowSource.web;
    if (MusicService.I.isPlaying) return NowSource.apple;
    if (preferWeb != null && preferWeb!.opened && !preferInApp) return NowSource.web;
    if (preferInApp && InAppPlayer.I.active) return NowSource.inApp;
    return NowSource.apple;
  }

  static WebPlayer? get web => _playingWeb ?? preferWeb;

  static bool get inApp => source == NowSource.inApp;

  static bool get hasItem => switch (source) {
        NowSource.inApp => InAppPlayer.I.active,
        NowSource.web => (web?.title ?? '').isNotEmpty,
        NowSource.apple => MusicService.I.hasItem,
      };
  static bool get isPlaying => switch (source) {
        NowSource.inApp => InAppPlayer.I.isPlaying,
        NowSource.web => web?.isPlaying ?? false,
        NowSource.apple => MusicService.I.isPlaying,
      };
  static String get title => switch (source) {
        NowSource.inApp => InAppPlayer.I.title,
        NowSource.web => web?.title ?? '',
        NowSource.apple => MusicService.I.title,
      };
  static String get subtitle => switch (source) {
        NowSource.inApp => InAppPlayer.I.subtitle,
        NowSource.web => [web?.artist ?? '', web?.name ?? ''].where((e) => e.isNotEmpty).join(' · '),
        NowSource.apple => MusicService.I.artist,
      };
  static bool get isLive => inApp && InAppPlayer.I.isLive;

  static double get progress {
    switch (source) {
      case NowSource.inApp:
        final ip = InAppPlayer.I;
        if (ip.isLive || ip.duration.inMilliseconds == 0) return 0;
        return (ip.position.inMilliseconds / ip.duration.inMilliseconds).clamp(0.0, 1.0);
      case NowSource.web:
        return 0;
      case NowSource.apple:
        final m = MusicService.I;
        return m.duration > 0 ? (m.position / m.duration).clamp(0.0, 1.0) : 0;
    }
  }

  static Future<void> playPause() => switch (source) {
        NowSource.inApp => InAppPlayer.I.playPause(),
        NowSource.web => web!.playPause(),
        NowSource.apple => MusicService.I.playPause(),
      };
  static Future<void> next() => switch (source) {
        NowSource.inApp => InAppPlayer.I.next(),
        NowSource.web => web!.next(),
        NowSource.apple => MusicService.I.next(),
      };
  static Future<void> previous() => switch (source) {
        NowSource.inApp => InAppPlayer.I.previous(),
        NowSource.web => web!.previous(),
        NowSource.apple => MusicService.I.previous(),
      };
  static Future<void> pause() async {
    await InAppPlayer.I.pause();
    await MusicService.I.pause();
    for (final w in WebPlayers.all) {
      await w.pause();
    }
  }
}
