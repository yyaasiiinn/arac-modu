import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'in_app_player.dart';
import 'music_service.dart';
import 'now_playing.dart';
import 'web_players.dart';

class SpItem {
  final String uri;
  final String title;
  final String subtitle;
  final String image;
  const SpItem(this.uri, this.title, this.subtitle, this.image);
}

/// Telefondaki Spotify uygulamasının hesabını kullanarak (siteden giriş yok)
/// Spotify'ı uygulamanın içinden yönetir: çalan şarkı, kapak, kontroller,
/// çalma listeleri, son çalınanlar ve arama.
///
/// Spotify, kendi uygulamasına bağlanmak için ücretsiz bir "Client ID" ister
/// (developer.spotify.com). Ayarlar > Spotify bölümüne bir kez girilir.
class SpotifyService extends ChangeNotifier {
  SpotifyService._();
  static final SpotifyService I = SpotifyService._();

  static const redirectUrl = 'aracmodu://spotify-callback';
  static const _scope = 'app-remote-control,user-modify-playback-state,user-read-playback-state,'
      'user-read-currently-playing,playlist-read-private,playlist-read-collaborative,'
      'user-library-read,user-read-recently-played';

  SharedPreferences? _prefs;
  String clientId = '';
  String? _token;
  DateTime _tokenAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool connected = false;
  bool connecting = false;
  String? error;

  String title = '';
  String artist = '';
  String album = '';
  String trackUri = '';
  Uint8List? artwork;
  bool isPaused = true;
  int positionMs = 0;
  int durationMs = 0;
  DateTime _stateAt = DateTime.now();

  StreamSubscription? _stateSub, _connSub;
  Timer? _tick;

  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
  bool get configured => clientId.trim().length >= 20;
  bool get isPlaying => connected && !isPaused && title.isNotEmpty;
  bool get hasItem => connected && title.isNotEmpty;

  /// Çalarken ilerlemeyi tahmin et (Spotify her saniye bildirmez).
  int get livePositionMs {
    if (isPaused) return positionMs;
    final p = positionMs + DateTime.now().difference(_stateAt).inMilliseconds;
    return durationMs > 0 ? p.clamp(0, durationMs) : p;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    clientId = p.getString('spotifyClientId') ?? '';
    _token = p.getString('spotifyToken');
    _tokenAt = DateTime.fromMillisecondsSinceEpoch(p.getInt('spotifyTokenAt') ?? 0);
  }

  void setClientId(String id) {
    clientId = id.trim();
    _prefs?.setString('spotifyClientId', clientId);
    _token = null;
    notifyListeners();
  }

  bool get _tokenValid => _token != null && DateTime.now().difference(_tokenAt).inMinutes < 55;

  /// Spotify uygulamasına bağlan. Token yoksa/eskidiyse Spotify bir anlığına
  /// açılıp onay verir ve otomatik olarak geri döner (giriş istemez).
  Future<bool> connect() async {
    if (!supported) {
      error = 'Spotify bağlantısı telefonda çalışır';
      notifyListeners();
      return false;
    }
    if (!configured) {
      error = 'Önce Ayarlar > Spotify bölümüne Client ID girin';
      notifyListeners();
      return false;
    }
    if (connected) return true;
    if (connecting) return false;
    connecting = true;
    error = null;
    notifyListeners();
    try {
      if (!await SpotifySdk.isSpotifyInstalled()) {
        throw Exception('Spotify uygulaması yüklü değil');
      }
      if (!_tokenValid) {
        _token = await SpotifySdk.getAccessToken(clientId: clientId, redirectUrl: redirectUrl, scope: _scope);
        _tokenAt = DateTime.now();
        _prefs?.setString('spotifyToken', _token!);
        _prefs?.setInt('spotifyTokenAt', _tokenAt.millisecondsSinceEpoch);
      }
      connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUrl,
        accessToken: _token,
        scope: _scope,
        playerName: 'CarPlay',
      );
      if (connected) _subscribe();
    } on PlatformException catch (e) {
      error = _friendly(e.message ?? e.code);
      connected = false;
      // Token reddedildiyse bir dahaki sefere yenisini al.
      _token = null;
    } catch (e) {
      error = _friendly(e.toString());
      connected = false;
    }
    connecting = false;
    notifyListeners();
    return connected;
  }

  String _friendly(String m) {
    if (m.contains('yüklü değil')) return 'Spotify uygulaması bu telefonda yüklü değil';
    if (m.toLowerCase().contains('client') || m.contains('INVALID_CLIENT')) {
      return 'Client ID veya yönlendirme adresi hatalı (Ayarlar > Spotify)';
    }
    return 'Spotify\'a bağlanılamadı. Spotify\'ı bir kez açıp tekrar deneyin.';
  }

  void _subscribe() {
    _stateSub?.cancel();
    _connSub?.cancel();
    _stateSub = SpotifySdk.subscribePlayerState().listen((s) async {
      final t = s.track;
      final newUri = t?.uri ?? '';
      final wasPaused = isPaused;
      title = t?.name ?? '';
      artist = t?.artist.name ?? (t?.artists.isNotEmpty == true ? (t!.artists.first.name ?? '') : '');
      album = t?.album.name ?? '';
      isPaused = s.isPaused;
      positionMs = s.playbackPosition;
      durationMs = t?.duration ?? 0;
      _stateAt = DateTime.now();
      if (!isPaused && wasPaused) _onStartedPlaying();
      if (newUri != trackUri) {
        trackUri = newUri;
        artwork = null;
        if (t != null) {
          try {
            artwork = await SpotifySdk.getImage(imageUri: t.imageUri, dimension: ImageDimension.large);
          } catch (_) {}
        }
      }
      notifyListeners();
    }, onError: (_) {});
    _connSub = SpotifySdk.subscribeConnectionStatus().listen((c) {
      connected = c.connected;
      if (!connected) error = null;
      notifyListeners();
    }, onError: (_) {});
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isPlaying) notifyListeners();
    });
  }

  void _onStartedPlaying() {
    NowPlaying.preferSpotify = true;
    NowPlaying.preferInApp = false;
    NowPlaying.preferWeb = null;
    if (InAppPlayer.I.isPlaying) InAppPlayer.I.pause();
    if (MusicService.I.isPlaying) MusicService.I.pause();
    for (final w in WebPlayers.all) {
      w.pause();
    }
  }

  Future<void> _cmd(Future<void> Function() f) async {
    HapticFeedback.lightImpact();
    if (!connected && !await connect()) return;
    try {
      await f();
    } catch (_) {
      connected = false;
      if (await connect()) {
        try {
          await f();
        } catch (_) {}
      }
    }
  }

  Future<void> playPause() => _cmd(() async {
        if (isPaused) {
          _onStartedPlaying();
          await SpotifySdk.resume();
        } else {
          await SpotifySdk.pause();
        }
      });
  Future<void> pause() async {
    if (!connected || isPaused) return;
    try {
      await SpotifySdk.pause();
    } catch (_) {}
  }

  Future<void> next() => _cmd(SpotifySdk.skipNext);
  Future<void> previous() => _cmd(SpotifySdk.skipPrevious);
  Future<void> seek(int ms) => _cmd(() => SpotifySdk.seekTo(positionedMilliseconds: ms));
  Future<void> toggleShuffle() => _cmd(SpotifySdk.toggleShuffle);
  Future<void> play(String uri) => _cmd(() async {
        _onStartedPlaying();
        await SpotifySdk.play(spotifyUri: uri);
      });

  // ---------------- Kitaplık (Spotify Web API, aynı token ile) ----------------

  Future<Map<String, dynamic>?> _api(String path, [Map<String, String>? q]) async {
    if (!_tokenValid && !await connect()) return null;
    final res = await http
        .get(Uri.https('api.spotify.com', '/v1$path', q), headers: {'Authorization': 'Bearer $_token'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) {
      _token = null;
      return null;
    }
    if (res.statusCode != 200) return null;
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static String _img(dynamic images) {
    if (images is List && images.isNotEmpty) return (images.first as Map)['url'] as String? ?? '';
    return '';
  }

  static String _artists(dynamic a) =>
      a is List ? a.map((e) => (e as Map)['name'] ?? '').where((e) => e != '').join(', ') : '';

  Future<List<SpItem>> playlists() async {
    final j = await _api('/me/playlists', {'limit': '50'});
    if (j == null) return [];
    return (j['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map((p) => SpItem(
              p['uri'] as String,
              p['name'] as String? ?? '',
              '${(p['tracks'] as Map?)?['total'] ?? ''} şarkı',
              _img(p['images']),
            ))
        .toList();
  }

  Future<List<SpItem>> recentlyPlayed() async {
    final j = await _api('/me/player/recently-played', {'limit': '40'});
    if (j == null) return [];
    final seen = <String>{};
    final out = <SpItem>[];
    for (final it in (j['items'] as List).whereType<Map<String, dynamic>>()) {
      final t = it['track'] as Map<String, dynamic>?;
      if (t == null || !seen.add(t['uri'] as String)) continue;
      out.add(SpItem(t['uri'] as String, t['name'] as String? ?? '', _artists(t['artists']),
          _img((t['album'] as Map?)?['images'])));
    }
    return out;
  }

  Future<List<SpItem>> search(String q) async {
    final j = await _api('/search', {'q': q, 'type': 'track,playlist,artist', 'limit': '15', 'market': 'from_token'});
    if (j == null) return [];
    final out = <SpItem>[];
    for (final a in ((j['artists'] as Map?)?['items'] as List? ?? []).whereType<Map<String, dynamic>>().take(3)) {
      out.add(SpItem(a['uri'] as String, a['name'] as String? ?? '', 'Sanatçı', _img(a['images'])));
    }
    for (final t in ((j['tracks'] as Map?)?['items'] as List? ?? []).whereType<Map<String, dynamic>>()) {
      out.add(SpItem(t['uri'] as String, t['name'] as String? ?? '', _artists(t['artists']),
          _img((t['album'] as Map?)?['images'])));
    }
    for (final p in ((j['playlists'] as Map?)?['items'] as List? ?? []).whereType<Map<String, dynamic>>().take(6)) {
      out.add(SpItem(p['uri'] as String, p['name'] as String? ?? '', 'Çalma listesi', _img(p['images'])));
    }
    return out;
  }
}
