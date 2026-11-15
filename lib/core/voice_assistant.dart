import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_state.dart';
import 'apps.dart';
import 'calendar_repo.dart';
import 'contacts_repo.dart';
import 'in_app_player.dart';
import 'location_service.dart';
import 'media_api.dart';
import 'now_playing.dart';
import 'models.dart';
import 'music_service.dart';
import 'nav_controller.dart';
import 'routing_api.dart';
import 'tts_service.dart';

enum VoiceState { idle, listening, thinking, speaking }

/// Mesajlar ekranına "şu kişiye şunu yaz" isteği iletmek için.
class ComposeRequest {
  final FavContact to;
  final String body;
  const ComposeRequest(this.to, this.body);
}

final composeRequest = ValueNotifier<ComposeRequest?>(null);

/// Siri benzeri sesli asistan (Türkçe komutlar).
class VoiceAssistant extends ChangeNotifier {
  VoiceAssistant._();
  static final VoiceAssistant I = VoiceAssistant._();

  final SpeechToText _stt = SpeechToText();
  bool _inited = false;
  String? _locale;

  VoiceState state = VoiceState.idle;
  bool visible = false;
  String transcript = '';
  String reply = '';
  double level = 0;

  /// Dikte modu: sonucu komut olarak işlemek yerine geri verir.
  void Function(String text)? _dictationCallback;

  Future<bool> _init() async {
    if (_inited) return true;
    try {
      _inited = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && state == VoiceState.listening) {
            _finish();
          }
        },
        onError: (e) {
          if (state == VoiceState.listening) {
            if (transcript.isEmpty) {
              _respond('Sizi duyamadım.');
            } else {
              _finish();
            }
          }
        },
      );
      if (_inited) {
        final locales = await _stt.locales();
        final tr = locales.where((l) => l.localeId.toLowerCase().startsWith('tr'));
        _locale = tr.isNotEmpty ? tr.first.localeId : 'tr_TR';
      }
    } catch (_) {
      _inited = false;
    }
    return _inited;
  }

  /// Asistanı açar ve dinlemeye başlar.
  Future<void> activate() async {
    _dictationCallback = null;
    await _start();
  }

  /// Sadece yazıya dökme (mesaj, adres arama için).
  Future<void> dictate(void Function(String text) onText) async {
    _dictationCallback = onText;
    await _start();
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    await Tts.I.stop();
    visible = true;
    transcript = '';
    reply = '';
    state = VoiceState.listening;
    notifyListeners();
    if (!await _init()) {
      _respond('Konuşma tanıma kullanılamıyor. Mikrofon ve konuşma tanıma izinlerini kontrol edin.');
      return;
    }
    try {
      await _stt.listen(
        onResult: (r) {
          transcript = r.recognizedWords;
          notifyListeners();
          if (r.finalResult) _finish();
        },
        onSoundLevelChange: (l) {
          level = l;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 20),
        ),
      );
    } catch (_) {
      _respond('Dinleme başlatılamadı.');
    }
  }

  void cancel() {
    try {
      _stt.cancel();
    } catch (_) {}
    Tts.I.stop();
    state = VoiceState.idle;
    visible = false;
    _dictationCallback = null;
    notifyListeners();
  }

  Future<void> _finish() async {
    if (state != VoiceState.listening) return;
    try {
      await _stt.stop();
    } catch (_) {}
    final text = transcript.trim();
    final cb = _dictationCallback;
    if (cb != null) {
      _dictationCallback = null;
      state = VoiceState.idle;
      visible = false;
      notifyListeners();
      if (text.isNotEmpty) cb(text);
      return;
    }
    if (text.isEmpty) {
      _respond('Sizi duyamadım.');
      return;
    }
    state = VoiceState.thinking;
    notifyListeners();
    try {
      await _handle(text);
    } catch (_) {
      _respond('Bir sorun oluştu.');
    }
  }

  Future<void> _respond(String text, {bool close = true}) async {
    reply = text;
    state = VoiceState.speaking;
    notifyListeners();
    await Tts.I.speak(text);
    if (close && state == VoiceState.speaking) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (state == VoiceState.speaking) {
        state = VoiceState.idle;
        visible = false;
        notifyListeners();
      }
    }
  }

  // ------------------------------------------------------------------
  // Komut çözümleme
  // ------------------------------------------------------------------

  Future<void> _handle(String raw) async {
    final t = ContactsRepo.norm(raw);
    final words = t.split(RegExp(r'\s+'));
    bool has(String w) => words.contains(w);
    bool any(List<String> ws) => ws.any((w) => t.contains(w));

    final app = AppState.I;
    final music = MusicService.I;
    final nav = NavController.I;

    // --- Mesaj ---
    if (any(['mesaj', 'yaz ', 'sms'])) {
      final c = _findContact(raw);
      if (c == null) {
        app.open(CarApp.messages);
        return _respond('Kime mesaj göndermek istersiniz?');
      }
      var body = '';
      final m = RegExp(r'(mesaj (gonder|at|yolla|yaz)|yaz|de ki)\s+(.*)$').firstMatch(t);
      // norm() harf başına tek harf döndürdüğü için indeksler raw ile aynı.
      if (m != null && t.length == raw.length) {
        body = raw.substring(m.end - m.group(3)!.length).trim();
      } else if (m != null) {
        body = m.group(3)!.trim();
      }
      composeRequest.value = ComposeRequest(c, body);
      app.open(CarApp.messages);
      return _respond(body.isEmpty ? '${c.name} kişisine ne yazmak istersiniz?' : 'Mesaj hazır. ${c.name} kişisine: $body. Göndermek için Gönder\'e dokunun.');
    }

    // --- Arama ---
    if (has('ara') || has('arayin') || has('ariyorum') || t.endsWith(' ara') || any(['telefon et', 'cagri yap'])) {
      final c = _findContact(raw);
      if (c == null) {
        app.open(CarApp.phone);
        return _respond('Kimi aramak istersiniz?');
      }
      await _respond('${c.name} aranıyor.');
      await app.call(c.name, c.number);
      return;
    }

    // --- Navigasyon ---
    if (any(['navigasyonu bitir', 'rotayi iptal', 'navigasyonu durdur', 'rotayi bitir', 'yol tarifini iptal'])) {
      nav.stop();
      return _respond('Rota sonlandırıldı.');
    }
    if (any(['ne zaman varir', 'kac dakika', 'kac km', 'kac kilometre', 'ne kadar kaldi'])) {
      if (!nav.active) return _respond('Şu anda aktif bir rota yok.');
      return _respond('${formatDistance(nav.remainingDistance)} kaldı. '
          'Tahmini varış saati ${DateFormat.Hm().format(nav.eta)}.');
    }
    if (RegExp(r'\b(git|gidelim|gotur|yol tarifi|navigasyon|rota olustur)\b').hasMatch(t)) {
      if (RegExp(r'\b(eve|evime|ev)\b').hasMatch(t)) {
        if (app.home == null) return _respond('Ev adresiniz kayıtlı değil. Ayarlar\'dan ekleyebilirsiniz.');
        app.open(CarApp.maps);
        await nav.navigateTo(app.home!);
        return _respond(nav.active ? 'Eve gidiyoruz.' : (nav.error ?? 'Rota bulunamadı.'));
      }
      if (RegExp(r'\b(ise|isime|is yerine|ofise)\b').hasMatch(t)) {
        if (app.work == null) return _respond('İş adresiniz kayıtlı değil. Ayarlar\'dan ekleyebilirsiniz.');
        app.open(CarApp.maps);
        await nav.navigateTo(app.work!);
        return _respond(nav.active ? 'İşe gidiyoruz.' : (nav.error ?? 'Rota bulunamadı.'));
      }
      var q = raw
          .replaceAll(RegExp(r'(yol tarifi( al| ver)?|navigasyon( başlat| baslat)?|götür|gotur|gidelim|git|rota( oluştur)?|beni|bana)', caseSensitive: false), ' ')
          .trim();
      q = q.replaceAll(RegExp(r"['’]?(ye|ya|ne|na|e|a)$"), '').replaceAll(RegExp(r"['’]"), '').trim();
      if (q.isEmpty) {
        app.open(CarApp.maps);
        return _respond('Nereye gitmek istersiniz?');
      }
      final nearby = RegExp(r'(en yakin|yakindaki|yakin)').hasMatch(t);
      final query = q.replaceAll(RegExp(r'(en yakın|yakındaki|en yakin|yakindaki)', caseSensitive: false), '').trim();
      final res = await RoutingApi.search(query, near: LocationService.I.latLng, nearbyOnly: nearby);
      if (res.isEmpty) return _respond('"$query" bulunamadı.');
      app.open(CarApp.maps);
      await nav.navigateTo(res.first);
      return _respond(nav.active ? '${res.first.name} için rota başladı.' : (nav.error ?? 'Rota bulunamadı.'));
    }

    // --- Radyo ---
    if (RegExp(r'\b(radyo\w*|fm)\b').hasMatch(t)) {
      final ip = InAppPlayer.I;
      if (any(['kapat', 'durdur', 'sustur'])) {
        await ip.pause();
        return _respond('Radyo durduruldu.');
      }
      // "Kral FM aç", "Radyo Fenomen çal"
      final name = raw
          .replaceAll(RegExp(r"\b(radyoyu|radyosunu|radyo)\b|\b(aç|ac|çal|cal|açar mısın|dinle|dinlet|lütfen)\b|['’](yu|yi|u|i|ı|ü)\b", caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      RadioStation? st;
      if (name.length >= 2) {
        final favs = ip.favoriteStations
            .where((e) => ContactsRepo.norm(e.name).contains(ContactsRepo.norm(name)))
            .toList();
        if (favs.isNotEmpty) {
          st = favs.first;
        } else {
          try {
            final r = await MediaApi.searchRadio(name);
            if (r.isNotEmpty) st = r.first;
          } catch (_) {}
        }
      }
      st ??= ip.station ?? (ip.favoriteStations.isNotEmpty ? ip.favoriteStations.first : null);
      if (st == null) {
        try {
          final top = await MediaApi.topTurkishRadios();
          if (top.isNotEmpty) st = top.first;
        } catch (_) {}
      }
      if (st == null) return _respond('Radyo bulunamadı.');
      await ip.playStation(st);
      app.open(CarApp.nowPlaying);
      return _respond('${st.name} çalıyor.');
    }

    // --- Müzik ---
    if (any(['karisik', 'rastgele'])) {
      await music.shuffleAll();
      app.open(CarApp.nowPlaying);
      return _respond('Kitaplığınız karışık çalınıyor.');
    }
    if (any(['sonraki', 'sarkiyi gec', 'atla', 'diger sarki'])) {
      await NowPlaying.next();
      return _respond(NowPlaying.inApp ? 'Sonraki.' : 'Sonraki şarkı.');
    }
    if (any(['onceki', 'geri al', 'basa sar'])) {
      await NowPlaying.previous();
      return _respond('Önceki.');
    }
    if (any(['durdur', 'duraklat', 'kapat', 'sustur']) && any(['muzik', 'sarki', 'durdur', 'duraklat'])) {
      await NowPlaying.pause();
      return _respond('Duraklatıldı.');
    }
    if (any(['muzik', 'sarki', 'cal', 'devam et', 'oynat'])) {
      if (NowPlaying.inApp && InAppPlayer.I.active) {
        if (!InAppPlayer.I.isPlaying) await InAppPlayer.I.playPause();
      } else {
        await music.play();
      }
      app.open(CarApp.nowPlaying);
      return _respond('Çalıyor.');
    }
    if (any(['ne caliyor', 'bu sarki ne', 'hangi sarki'])) {
      await music.refresh();
      return _respond(NowPlaying.hasItem ? '${NowPlaying.subtitle}, ${NowPlaying.title}' : 'Şu anda bir şey çalmıyor.');
    }

    // --- Bilgi ---
    if (any(['saat kac', 'saat ne'])) {
      return _respond('Saat ${DateFormat.Hm().format(DateTime.now())}.');
    }
    if (any(['bugun ne', 'tarih', 'gunlerden ne'])) {
      return _respond(DateFormat('d MMMM EEEE', 'tr').format(DateTime.now()));
    }
    if (any(['hizim', 'kac km ile', 'hiz kac'])) {
      return _respond('Hızınız saatte ${LocationService.I.speedKmh.round()} kilometre.');
    }
    if (any(['takvim', 'randevu', 'toplanti', 'etkinlik', 'ajanda'])) {
      await CalendarRepo.I.load();
      final e = CalendarRepo.I.nextEvent;
      app.open(CarApp.calendar);
      if (e == null) return _respond('Yaklaşan etkinliğiniz yok.');
      return _respond('Sıradaki etkinlik: ${e.title}, ${DateFormat('d MMMM HH:mm', 'tr').format(e.start)}.');
    }

    // --- Uygulama açma ---
    for (final entry in {
      'harita': CarApp.maps,
      'telefon': CarApp.phone,
      'rehber': CarApp.phone,
      'mesajlar': CarApp.messages,
      'ayarlar': CarApp.settings,
      'podcast': CarApp.podcasts,
      'radyo': CarApp.radio,
      'ana ekran': CarApp.home,
      'dashboard': CarApp.dashboard,
    }.entries) {
      if (t.contains(entry.key)) {
        app.open(entry.value);
        return _respond('Tamam.');
      }
    }

    if (any(['merhaba', 'selam'])) return _respond('Merhaba! Size nasıl yardımcı olabilirim?');
    if (any(['tesekkur', 'sagol'])) return _respond('Rica ederim.');

    return _respond('Bunu anlayamadım. "Annemi ara", "Eve git", "Kral FM aç" ya da "Müzik çal" diyebilirsiniz.');
  }

  FavContact? _findContact(String raw) {
    final favs = AppState.I.favorites
        .map((f) => SimpleContact(f.name, [f.number], null))
        .toList();
    final c = ContactsRepo.I.findInSpeech(raw, extra: favs);
    if (c == null || c.phones.isEmpty) return null;
    return FavContact(c.name, c.phones.first);
  }
}
