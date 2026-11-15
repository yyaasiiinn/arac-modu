import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'apps.dart';
import 'in_app_player.dart';
import 'music_service.dart';
import 'now_playing.dart';
import 'spotify_service.dart';

/// Spotify ve YouTube Music'i başka uygulama açmadan, uygulamanın içinde
/// (web oynatıcıları üzerinden) çalıştırır. Açılan oynatıcı arka planda
/// canlı tutulur; böylece haritaya geçince müzik durmaz.
class WebPlayer extends ChangeNotifier {
  final CarApp app;
  final String name;
  final String url;
  final List<String> playSel;
  final List<String> nextSel;
  final List<String> prevSel;

  WebPlayer(this.app, this.name, this.url, {required this.playSel, required this.nextSel, required this.prevSel});

  WebViewController? controller;
  bool get opened => controller != null;
  bool loading = false;

  String title = '';
  String artist = '';
  String artUrl = '';
  bool isPlaying = false;
  DateTime lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _poll;

  static const _safariUA =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1';

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  void ensureOpen() {
    if (controller != null || !supported) return;
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    final c = WebViewController.fromPlatformCreationParams(params);
    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setUserAgent(_safariUA)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          loading = true;
          notifyListeners();
        },
        onPageFinished: (_) {
          loading = false;
          notifyListeners();
        },
        // "Uygulamada aç" bağlantıları iOS'un "açmak istiyor" sorusunu çıkarır;
        // web dışındaki adresleri engelle, her şey burada kalsın.
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.scheme == 'http' || u.scheme == 'https' || u.scheme == 'about' || u.scheme == 'blob' || u.scheme == 'data') {
            if (u.host.endsWith('apps.apple.com') || u.host.endsWith('itunes.apple.com')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(url));
    controller = c;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    notifyListeners();
  }

  void reload() => controller?.loadRequest(Uri.parse(url));

  static const _metaJs = '''
(function(){try{
var m=navigator.mediaSession&&navigator.mediaSession.metadata;
var els=Array.prototype.slice.call(document.querySelectorAll('video,audio'));
var playing=els.some(function(e){return !e.paused&&!e.ended&&e.readyState>2;});
if(!playing&&navigator.mediaSession&&navigator.mediaSession.playbackState==='playing'){playing=true;}
var art='';if(m&&m.artwork&&m.artwork.length){art=m.artwork[m.artwork.length-1].src;}
return JSON.stringify({t:m?(m.title||''):'',a:m?(m.artist||''):'',art:art,p:playing});
}catch(e){return '{}';}})()''';

  /// "Uygulamayı aç" / "Oturum aç" düğmelerini ve tanıtım bantlarını gizler.
  static const _cleanJs = r'''
(function(){try{
var re=/^(open app|open in app|get the app|uygulamay[ıi] a[çc]|uygulamada a[çc]|uygulamay[ıi] edinin|sign in|oturum a[çc]|giri[şs] yap)$/i;
document.querySelectorAll('a,button,tp-yt-paper-button,yt-button-renderer,ytmusic-guide-entry-renderer,tp-yt-paper-item').forEach(function(e){
 var t=(e.innerText||e.getAttribute('aria-label')||'').trim();
 if(re.test(t)){var el=e.closest('ytmusic-guide-entry-renderer,yt-button-renderer,tp-yt-paper-item')||e;el.style.display='none';}
});
document.querySelectorAll('ytmusic-mealbar-promo-renderer,ytmusic-statement-banner-renderer,ytmusic-popup-container tp-yt-paper-dialog,.upsell-dialog-renderer,ytmusic-upsell-dialog-renderer').forEach(function(e){e.style.display='none';});
return 'ok';}catch(e){return 'err';}})()''';

  Future<void> refresh() async {
    final c = controller;
    if (c == null) return;
    try {
      await c.runJavaScriptReturningResult(_cleanJs);
    } catch (_) {}
    try {
      var r = await c.runJavaScriptReturningResult(_metaJs);
      var s = r is String ? r : r.toString();
      if (s.startsWith('"')) s = jsonDecode(s) as String;
      final m = jsonDecode(s) as Map<String, dynamic>;
      final playing = m['p'] == true;
      final changed = playing != isPlaying || title != (m['t'] ?? '');
      title = (m['t'] as String?) ?? '';
      artist = (m['a'] as String?) ?? '';
      artUrl = (m['art'] as String?) ?? '';
      if (playing && !isPlaying) _onStartedPlaying();
      isPlaying = playing;
      if (playing) lastPlayed = DateTime.now();
      if (changed) notifyListeners();
    } catch (_) {}
  }

  void _onStartedPlaying() {
    NowPlaying.preferWeb = this;
    NowPlaying.preferSpotify = false;
    SpotifyService.I.pause();
    // Aynı anda iki şey çalmasın.
    if (InAppPlayer.I.isPlaying) InAppPlayer.I.pause();
    if (MusicService.I.isPlaying) MusicService.I.pause();
    for (final w in WebPlayers.all) {
      if (w != this && w.isPlaying) w.pause();
    }
  }

  String _clickJs(List<String> sels) {
    final list = jsonEncode(sels);
    return '''
(function(){var s=$list;for(var i=0;i<s.length;i++){var b=document.querySelector(s[i]);if(b){b.click();return 'ok';}}return 'none';})()''';
  }

  Future<void> _run(String js) async {
    try {
      await controller?.runJavaScriptReturningResult(js);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  Future<void> playPause() async {
    HapticFeedback.lightImpact();
    if (!isPlaying) _onStartedPlaying();
    await _run('''
(function(){var els=Array.prototype.slice.call(document.querySelectorAll('video,audio'));
var p=els.filter(function(e){return !e.paused;});
var s=${jsonEncode(playSel)};
for(var i=0;i<s.length;i++){var b=document.querySelector(s[i]);if(b){b.click();return 'btn';}}
if(p.length){p.forEach(function(e){e.pause();});return 'paused';}
if(els.length){els[0].play();return 'play';}return 'none';})()''');
  }

  Future<void> pause() async {
    if (!isPlaying) return;
    await _run('''
(function(){var els=Array.prototype.slice.call(document.querySelectorAll('video,audio'));els.forEach(function(e){e.pause();});return 'ok';})()''');
  }

  Future<void> next() async {
    HapticFeedback.lightImpact();
    await _run(_clickJs(nextSel));
  }

  Future<void> previous() async {
    HapticFeedback.lightImpact();
    await _run(_clickJs(prevSel));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

class WebPlayers {
  static final ytMusic = WebPlayer(
    CarApp.youtubeMusic,
    'YouTube Music',
    'https://music.youtube.com/',
    playSel: ['#play-pause-button', 'ytmusic-player-bar #play-pause-button', 'button[aria-label="Play"]', 'button[aria-label="Pause"]', 'button[aria-label="Oynat"]', 'button[aria-label="Duraklat"]'],
    nextSel: ['.next-button', 'tp-yt-paper-icon-button.next-button', 'button[aria-label="Next"]', 'button[aria-label="Sonraki"]', 'button[aria-label="Sonraki şarkı"]'],
    prevSel: ['.previous-button', 'tp-yt-paper-icon-button.previous-button', 'button[aria-label="Previous"]', 'button[aria-label="Önceki"]', 'button[aria-label="Önceki şarkı"]'],
  );

  static final all = [ytMusic];

  static WebPlayer? forApp(CarApp app) {
    for (final w in all) {
      if (w.app == app) return w;
    }
    return null;
  }

  static Listenable get listenable => Listenable.merge(all);
}
