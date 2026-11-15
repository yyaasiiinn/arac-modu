import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'apps.dart';
import 'theme.dart';
import 'tts_service.dart';
import 'models.dart';

enum ThemeChoice { auto, dark, light }

/// Uygulamanın genel durumu ve ayarları.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  SharedPreferences? _prefs;

  // ---- Gezinme ----
  CarApp current = CarApp.home;
  final List<CarApp> recentApps = [CarApp.maps, CarApp.music, CarApp.phone];

  // ---- Ayarlar ----
  ThemeChoice themeChoice = ThemeChoice.dark;
  int wallpaper = 0;
  bool keepAwake = true;
  bool landscapeLock = false;
  bool voiceGuidance = true;
  bool headingUp = true;
  bool startOnDashboard = false;
  bool divaMode = false;
  String navApp = 'internal'; // internal | apple | google | waze | yandex | ask

  // ---- Kayıtlı veriler ----
  Place? home;
  Place? work;
  List<Place> recentPlaces = [];
  List<FavContact> favorites = [];
  List<CallLog> recents = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    themeChoice = ThemeChoice.values[p.getInt('theme') ?? 1];
    wallpaper = p.getInt('wallpaper') ?? 0;
    keepAwake = p.getBool('keepAwake') ?? true;
    landscapeLock = p.getBool('landscapeLock') ?? false;
    voiceGuidance = p.getBool('voiceGuidance') ?? true;
    headingUp = p.getBool('headingUp') ?? true;
    startOnDashboard = p.getBool('startOnDashboard') ?? false;
    navApp = p.getString('navApp') ?? 'internal';
    divaMode = p.getBool('divaMode') ?? false;
    CP.diva = divaMode;
    home = _readPlace('home');
    work = _readPlace('work');
    recentPlaces = _readList('recentPlaces', Place.fromJson);
    favorites = _readList('favorites', FavContact.fromJson);
    recents = _readList('recents', CallLog.fromJson);
    if (startOnDashboard) current = CarApp.dashboard;
    applySystemSettings();
  }

  Place? _readPlace(String key) {
    final s = _prefs?.getString(key);
    if (s == null) return null;
    try {
      return Place.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final s = _prefs?.getString(key);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => f(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setInt('theme', themeChoice.index);
    p.setInt('wallpaper', wallpaper);
    p.setBool('keepAwake', keepAwake);
    p.setBool('landscapeLock', landscapeLock);
    p.setBool('voiceGuidance', voiceGuidance);
    p.setBool('headingUp', headingUp);
    p.setBool('startOnDashboard', startOnDashboard);
    p.setString('navApp', navApp);
    p.setBool('divaMode', divaMode);
    if (home != null) {
      p.setString('home', jsonEncode(home!.toJson()));
    } else {
      p.remove('home');
    }
    if (work != null) {
      p.setString('work', jsonEncode(work!.toJson()));
    } else {
      p.remove('work');
    }
    p.setString('recentPlaces',
        jsonEncode(recentPlaces.map((e) => e.toJson()).toList()));
    p.setString(
        'favorites', jsonEncode(favorites.map((e) => e.toJson()).toList()));
    p.setString('recents', jsonEncode(recents.map((e) => e.toJson()).toList()));
  }

  void update(VoidCallback change) {
    change();
    _save();
    applySystemSettings();
    notifyListeners();
  }

  void applySystemSettings() {
    try {
      WakelockPlus.toggle(enable: keepAwake);
    } catch (_) {}
    SystemChrome.setPreferredOrientations(landscapeLock
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const []);
  }

  /// Diva Modu açılış/kapanış yazısı (ekranda kısa süre görünür).
  final announcement = ValueNotifier<String?>(null);

  void setDivaMode(bool on) {
    if (on == divaMode) return;
    HapticFeedback.heavyImpact();
    update(() {
      divaMode = on;
      CP.diva = on;
    });
    announcement.value = on ? 'Hoş geldin divamız' : 'Keep going now';
    if (on) Tts.I.speak('Hoş geldin divamız!');
  }

  bool get isDark {
    switch (themeChoice) {
      case ThemeChoice.dark:
        return true;
      case ThemeChoice.light:
        return false;
      case ThemeChoice.auto:
        final h = DateTime.now().hour;
        return h < 7 || h >= 19;
    }
  }

  // ---- Uygulama açma ----
  Future<void> open(CarApp app) async {
    final info = appInfos[app];
    if (info != null && info.external) {
      await openExternal(info);
      return;
    }
    HapticFeedback.selectionClick();
    current = app;
    if (app != CarApp.home && app != CarApp.dashboard) {
      final shown = app == CarApp.nowPlaying ? CarApp.music : app;
      recentApps.remove(shown);
      recentApps.insert(0, shown);
      if (recentApps.length > 3) recentApps.removeLast();
    }
    notifyListeners();
  }

  /// Ana ekran düğmesi: uygulamadaysa ana ekrana, ana ekrandaysa
  /// Dashboard'a geçer (CarPlay davranışı).
  void homeButton() {
    open(current == CarApp.home ? CarApp.dashboard : CarApp.home);
  }

  /// Diğer uygulamayı doğrudan açar (Safari'ye düşmez). Yüklü değilse uyarır.
  /// Not: iOS, bir uygulamayı ilk kez açarken bir kez "Açılsın mı?" diye sorar;
  /// "Aç" dendikten sonra bir daha sormaz.
  Future<void> openExternal(AppInfo info) async {
    HapticFeedback.selectionClick();
    final ok = await _launch(info.url!);
    if (!ok) toast('${info.name} bu telefonda yüklü değil');
  }

  /// Uygulamanın her yerinden kısa bilgi mesajı göstermek için.
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  void toast(String text) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<bool> launchUrlString(String url) => _launch(url);

  Future<bool> _launch(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  // ---- Telefon / mesaj ----
  Future<void> call(String name, String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (clean.isEmpty) return;
    update(() {
      recents.insert(0, CallLog(name, clean, DateTime.now(), CallKind.call));
      if (recents.length > 50) recents.removeLast();
    });
    await _launch('tel:$clean');
  }

  static const _sms = MethodChannel('car_mode/sms');

  /// SMS'i uygulamanın içinde açılan pencereyle gönderir.
  /// Dönüş: 'sent', 'cancelled', 'failed' veya 'external' (Mesajlar uygulaması açıldı).
  Future<String> sendSms(String name, String number, String body) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    String result = 'external';
    try {
      result = await _sms.invokeMethod<String>('send', {'to': clean, 'body': body}) ?? 'failed';
    } catch (_) {
      result = 'unavailable';
    }
    if (result == 'unavailable') {
      final sep = defaultTargetPlatform == TargetPlatform.iOS ? '&' : '?';
      await _launch('sms:$clean${sep}body=${Uri.encodeComponent(body)}');
      result = 'external';
    }
    if (result == 'sent' || result == 'external') {
      update(() {
        recents.insert(0, CallLog(name, clean, DateTime.now(), CallKind.message));
        if (recents.length > 50) recents.removeLast();
      });
    }
    return result;
  }

  Future<void> sendWhatsApp(String number, String body) async {
    var clean = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '9$clean'; // 05xx -> 905xx
    if (clean.length == 10) clean = '90$clean';
    await _launch('https://wa.me/$clean?text=${Uri.encodeComponent(body)}');
  }

  bool isFavorite(String number) {
    final n = _digits(number);
    return favorites.any((f) => _digits(f.number) == n);
  }

  void toggleFavorite(String name, String number) {
    update(() {
      final n = _digits(number);
      final i = favorites.indexWhere((f) => _digits(f.number) == n);
      if (i >= 0) {
        favorites.removeAt(i);
      } else {
        favorites.add(FavContact(name, number));
      }
    });
  }

  static String _digits(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  void addRecentPlace(Place p) {
    update(() {
      recentPlaces.removeWhere(
          (e) => (e.lat - p.lat).abs() < 1e-4 && (e.lon - p.lon).abs() < 1e-4);
      recentPlaces.insert(0, p);
      if (recentPlaces.length > 15) recentPlaces.removeLast();
    });
  }
}
