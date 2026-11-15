import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_api.dart';
import 'music_service.dart';
import 'now_playing.dart';
import 'spotify_service.dart';
import 'web_players.dart';

enum PlayerKind { none, radio, podcast }

/// Uygulamanın kendi oynatıcısı: radyo ve podcast (uygulamadan çıkmadan).
/// Kilit ekranı ve direksiyon tuşları just_audio_background ile çalışır.
class InAppPlayer extends ChangeNotifier {
  InAppPlayer._() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.positionStream.listen((p) {
      // Saniyede bir yeterli.
      if ((p - _lastPos).inMilliseconds.abs() >= 1000) {
        _lastPos = p;
        notifyListeners();
        if (kind == PlayerKind.podcast && _episode != null && p.inSeconds % 10 == 0) _savePosition();
      }
    });
  }
  static final InAppPlayer I = InAppPlayer._();

  final AudioPlayer player = AudioPlayer();
  Duration _lastPos = Duration.zero;
  SharedPreferences? _prefs;

  PlayerKind kind = PlayerKind.none;
  String title = '';
  String subtitle = '';
  String artUrl = '';
  String? error;
  bool loading = false;

  // Radyo
  List<RadioStation> favoriteStations = [];
  List<RadioStation> stationQueue = [];
  RadioStation? station;

  // Podcast
  List<Podcast> subscriptions = [];
  Map<String, int> _positions = {};
  Episode? _episode;
  List<Episode> episodeQueue = [];

  bool get active => kind != PlayerKind.none;
  bool get isPlaying => player.playing;
  Duration get position => player.position;
  Duration get duration => player.duration ?? Duration.zero;
  bool get isLive => kind == PlayerKind.radio;

  static Future<void> initBackground() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.yyaasiiinn.car_mode.audio',
        androidNotificationChannelName: 'Oynatıcı',
      );
    } catch (_) {}
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    try {
      favoriteStations = (jsonDecode(p.getString('favStations') ?? '[]') as List)
          .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
          .toList();
      subscriptions = (jsonDecode(p.getString('podcastSubs') ?? '[]') as List)
          .map((e) => Podcast.fromJson(e as Map<String, dynamic>))
          .toList();
      _positions = (jsonDecode(p.getString('podcastPos') ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {}
    notifyListeners();
  }

  void _persist() {
    _prefs?.setString('favStations', jsonEncode(favoriteStations.map((e) => e.toJson()).toList()));
    _prefs?.setString('podcastSubs', jsonEncode(subscriptions.map((e) => e.toJson()).toList()));
  }

  void _savePosition() {
    final e = _episode;
    if (e == null) return;
    _positions[e.url] = player.position.inSeconds;
    if (_positions.length > 200) _positions.remove(_positions.keys.first);
    _prefs?.setString('podcastPos', jsonEncode(_positions));
  }

  int savedPosition(String url) => _positions[url] ?? 0;

  // ---------------- Radyo ----------------

  bool isFavoriteStation(RadioStation s) => favoriteStations.any((e) => e.id == s.id);

  void toggleFavoriteStation(RadioStation s) {
    if (isFavoriteStation(s)) {
      favoriteStations.removeWhere((e) => e.id == s.id);
    } else {
      favoriteStations.add(s);
    }
    _persist();
    notifyListeners();
  }

  Future<void> playStation(RadioStation s, {List<RadioStation>? queue}) async {
    if (queue != null) stationQueue = queue;
    station = s;
    _episode = null;
    await _play(
      kind: PlayerKind.radio,
      url: s.url,
      title: s.name,
      subtitle: 'Canlı radyo',
      art: s.favicon,
      id: 'radio-${s.id}',
    );
  }

  Future<void> _stepStation(int d) async {
    final q = stationQueue.isNotEmpty ? stationQueue : favoriteStations;
    if (q.isEmpty || station == null) return;
    var i = q.indexWhere((e) => e.id == station!.id);
    i = (i + d) % q.length;
    if (i < 0) i += q.length;
    await playStation(q[i]);
  }

  // ---------------- Podcast ----------------

  bool isSubscribed(Podcast p) => subscriptions.any((e) => e.feedUrl == p.feedUrl);

  void toggleSubscription(Podcast p) {
    if (isSubscribed(p)) {
      subscriptions.removeWhere((e) => e.feedUrl == p.feedUrl);
    } else {
      subscriptions.insert(0, p);
    }
    _persist();
    notifyListeners();
  }

  Future<void> playEpisode(Episode e, Podcast p, {List<Episode>? queue}) async {
    _savePosition();
    if (queue != null) episodeQueue = queue;
    _episode = e;
    station = null;
    await _play(
      kind: PlayerKind.podcast,
      url: e.url,
      title: e.title,
      subtitle: p.name,
      art: e.artwork.isNotEmpty ? e.artwork : p.artwork,
      id: 'pod-${e.url.hashCode}',
      start: Duration(seconds: savedPosition(e.url)),
    );
  }

  // ---------------- Ortak ----------------

  Future<void> _play({
    required PlayerKind kind,
    required String url,
    required String title,
    required String subtitle,
    required String art,
    required String id,
    Duration start = Duration.zero,
  }) async {
    NowPlaying.preferInApp = true;
    NowPlaying.preferWeb = null;
    NowPlaying.preferSpotify = false;
    SpotifyService.I.pause();
    for (final w in WebPlayers.all) {
      w.pause();
    }
    this.kind = kind;
    this.title = title;
    this.subtitle = subtitle;
    artUrl = art;
    error = null;
    loading = true;
    notifyListeners();
    // Apple Music çalıyorsa durdur.
    if (MusicService.I.isPlaying) MusicService.I.pause();
    try {
      final art = Uri.tryParse(artUrl);
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: id,
            title: title,
            album: subtitle,
            artist: subtitle,
            artUri: (art != null && art.hasScheme) ? art : null,
          ),
        ),
        initialPosition: start,
      ).timeout(const Duration(seconds: 20));
      player.play();
    } catch (e) {
      error = kind == PlayerKind.radio ? 'Bu istasyon şu anda yayın vermiyor' : 'Bölüm açılamadı';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> playPause() async {
    HapticFeedback.lightImpact();
    if (player.playing) {
      await player.pause();
      _savePosition();
    } else {
      if (MusicService.I.isPlaying) MusicService.I.pause();
      if (kind == PlayerKind.radio && station != null) {
        // Canlı yayında beklemeden güncel yayına dön.
        await playStation(station!);
      } else {
        player.play();
      }
    }
  }

  Future<void> pause() async {
    if (player.playing) await player.pause();
    _savePosition();
  }

  Future<void> next() async {
    HapticFeedback.lightImpact();
    if (kind == PlayerKind.radio) return _stepStation(1);
    await player.seek(player.position + const Duration(seconds: 30));
  }

  Future<void> previous() async {
    HapticFeedback.lightImpact();
    if (kind == PlayerKind.radio) return _stepStation(-1);
    final p = player.position - const Duration(seconds: 15);
    await player.seek(p < Duration.zero ? Duration.zero : p);
  }

  Future<void> seek(Duration d) => player.seek(d);
}
