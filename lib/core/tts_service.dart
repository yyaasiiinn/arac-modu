import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Türkçe sesli okuma (yönlendirme, asistan cevapları, mesaj okuma).
class Tts {
  Tts._();
  static final Tts I = Tts._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.52);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        // Müzik çalarken sesi kısıp üstüne konuşur.
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
