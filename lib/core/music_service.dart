import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'in_app_player.dart';
import 'now_playing.dart';
import 'web_players.dart';

class Playlist {
  final String id;
  final String name;
  final int count;
  const Playlist(this.id, this.name, this.count);
}

/// iPhone'daki Müzik (Apple Music) uygulamasını kontrol eder.
/// iOS tarafı: ios/Runner/AppDelegate.swift -> MusicBridge.
class MusicService extends ChangeNotifier {
  MusicService._();
  static final MusicService I = MusicService._();

  static const _ch = MethodChannel('car_mode/music');

  bool supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool authorized = false;

  String title = '';
  String artist = '';
  String album = '';
  String? _id;
  Uint8List? artwork;
  double duration = 0;
  double position = 0;
  bool isPlaying = false;
  bool shuffle = false;
  int repeat = 0; // 0 kapalı, 1 tümü, 2 tek şarkı

  Timer? _timer;

  bool get hasItem => title.isNotEmpty;

  Future<void> start() async {
    if (!supported || _timer != null) return;
    try {
      authorized = await _ch.invokeMethod<bool>('requestAuth') ?? false;
    } on MissingPluginException {
      supported = false;
      notifyListeners();
      return;
    } catch (_) {}
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('nowPlaying', _id);
      if (m == null) return;
      final id = m['id'] as String?;
      title = m['title'] as String? ?? '';
      artist = m['artist'] as String? ?? '';
      album = m['album'] as String? ?? '';
      duration = (m['duration'] as num?)?.toDouble() ?? 0;
      position = (m['position'] as num?)?.toDouble() ?? 0;
      isPlaying = m['isPlaying'] as bool? ?? false;
      shuffle = m['shuffle'] as bool? ?? false;
      repeat = m['repeat'] as int? ?? 0;
      if (id != _id) {
        _id = id;
        artwork = m['artwork'] as Uint8List?;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _cmd(String method, [Object? arg]) async {
    if (!supported) return;
    HapticFeedback.lightImpact();
    if (const {'play', 'playAll', 'playPlaylist'}.contains(method)) {
      NowPlaying.preferInApp = false;
      NowPlaying.preferWeb = null;
      await InAppPlayer.I.pause();
      for (final w in WebPlayers.all) {
        await w.pause();
      }
    }
    try {
      await _ch.invokeMethod(method, arg);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 150));
    await refresh();
  }

  Future<void> playPause() => _cmd(isPlaying ? 'pause' : 'play');
  Future<void> play() => _cmd('play');
  Future<void> pause() => _cmd('pause');
  Future<void> next() => _cmd('next');
  Future<void> previous() => _cmd('previous');
  Future<void> seek(double seconds) => _cmd('seek', seconds);
  Future<void> toggleShuffle() => _cmd('toggleShuffle');
  Future<void> toggleRepeat() => _cmd('toggleRepeat');
  Future<void> shuffleAll() => _cmd('playAll');
  Future<void> playPlaylist(String id) => _cmd('playPlaylist', id);

  Future<List<Playlist>> playlists() async {
    if (!supported) return [];
    try {
      final list = await _ch.invokeListMethod<Map>('playlists') ?? [];
      return list
          .map((m) => Playlist(m['id'] as String, m['name'] as String? ?? 'Liste',
              m['count'] as int? ?? 0))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
