import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'app_state.dart';
import 'location_service.dart';
import 'models.dart';
import 'routing_api.dart';
import 'tts_service.dart';

enum NavMode { idle, loading, preview, navigating }

/// Rota önizleme ve adım adım sesli navigasyon.
class NavController extends ChangeNotifier {
  NavController._() {
    LocationService.I.addListener(_onLocation);
  }
  static final NavController I = NavController._();

  static const _dist = Distance();

  NavMode mode = NavMode.idle;
  Place? destination;
  RouteData? route;
  String? error;

  int stepIndex = 0; // sıradaki manevra = steps[stepIndex]
  double distToManeuver = 0;
  double remainingDistance = 0;
  double remainingSeconds = 0;

  final Set<String> _announced = {};
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  bool _rerouting = false;

  bool get active => mode == NavMode.navigating;

  RouteStep? get nextStep =>
      route != null && stepIndex < route!.steps.length ? route!.steps[stepIndex] : null;

  RouteStep? get stepAfter =>
      route != null && stepIndex + 1 < route!.steps.length ? route!.steps[stepIndex + 1] : null;

  DateTime get eta => DateTime.now().add(Duration(seconds: remainingSeconds.round()));

  Future<void> preview(Place dest) async {
    destination = dest;
    error = null;
    mode = NavMode.loading;
    notifyListeners();
    final from = LocationService.I.latLng;
    if (from == null) {
      error = 'Konumunuz henüz bulunamadı';
      mode = NavMode.idle;
      notifyListeners();
      return;
    }
    try {
      route = await RoutingApi.route(from, dest.latLng);
    } catch (_) {
      route = null;
    }
    if (route == null) {
      error = 'Rota bulunamadı (internet bağlantısını kontrol edin)';
      mode = NavMode.idle;
    } else {
      remainingDistance = route!.distance;
      remainingSeconds = route!.duration;
      mode = NavMode.preview;
      AppState.I.addRecentPlace(dest);
    }
    notifyListeners();
  }

  /// Önizlemeyi atlayıp doğrudan başlatır (sesli komut, öneriler).
  Future<void> navigateTo(Place dest) async {
    await preview(dest);
    if (mode == NavMode.preview) start();
  }

  void start() {
    if (route == null) return;
    mode = NavMode.navigating;
    stepIndex = route!.steps.length > 1 ? 1 : 0;
    _announced.clear();
    _recompute();
    notifyListeners();
    final mins = (route!.duration / 60).round();
    _say('${destination?.name ?? 'Hedef'} için rota başladı. '
        'Tahmini süre $mins dakika. ${nextStep?.spoken ?? ''}');
  }

  void stop() {
    mode = NavMode.idle;
    route = null;
    destination = null;
    error = null;
    Tts.I.stop();
    notifyListeners();
  }

  void _say(String s) {
    if (AppState.I.voiceGuidance) Tts.I.speak(s);
  }

  void _onLocation() {
    if (mode != NavMode.navigating || route == null) return;
    final pos = LocationService.I.latLng;
    if (pos == null) return;
    final steps = route!.steps;

    // Manevra noktasına yeterince yaklaşınca bir sonraki adıma geç.
    while (stepIndex < steps.length - 1 &&
        _dist(pos, steps[stepIndex].location) < 20) {
      stepIndex++;
    }

    _recompute();

    // Varış
    if (stepIndex >= steps.length - 1 && distToManeuver < 30) {
      _say('Varış noktasına ulaştınız.');
      stop();
      return;
    }

    // Rotadan çıkıldıysa yeniden hesapla.
    if (_offRoute(pos) &&
        !_rerouting &&
        DateTime.now().difference(_lastReroute).inSeconds > 15) {
      _reroute(pos);
    }

    _announce();
    notifyListeners();
  }

  void _recompute() {
    final pos = LocationService.I.latLng;
    final steps = route!.steps;
    if (pos == null || stepIndex >= steps.length) return;
    distToManeuver = _dist(pos, steps[stepIndex].location);
    double rest = 0;
    double restTime = 0;
    for (var i = stepIndex; i < steps.length; i++) {
      rest += steps[i].distance;
      restTime += steps[i].duration;
    }
    // steps[i].distance = i. manevradan sonraki yol; sıradaki manevraya kalan
    // mesafeyi de ekle.
    remainingDistance = distToManeuver + rest;
    final speed = route!.distance > 0 ? route!.duration / route!.distance : 0.1;
    remainingSeconds = restTime + distToManeuver * speed;
  }

  void _announce() {
    final s = nextStep;
    if (s == null) return;
    final d = distToManeuver;
    String? key;
    String? text;
    if (d < 1200 && d > 700 && !_announced.contains('$stepIndex-1k')) {
      key = '$stepIndex-1k';
      text = '1 kilometre sonra ${_lower(s.spoken)}';
    } else if (d <= 350 && d > 120 && !_announced.contains('$stepIndex-300')) {
      key = '$stepIndex-300';
      text = '${(d / 50).round() * 50} metre sonra ${_lower(s.spoken)}';
    } else if (d <= 60 && !_announced.contains('$stepIndex-now')) {
      key = '$stepIndex-now';
      text = s.spoken;
    }
    if (key != null && text != null) {
      _announced.add(key);
      _say(text);
    }
  }

  String _lower(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  bool _offRoute(LatLng pos) {
    final pts = route!.points;
    if (pts.length < 2) return false;
    var best = double.infinity;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = _segDist(pos, pts[i], pts[i + 1]);
      if (d < best) best = d;
      if (best < 60) return false;
    }
    return best > 60;
  }

  /// Nokta-doğru parçası arası mesafe (m), küçük alanlar için düzlem yaklaşımı.
  double _segDist(LatLng p, LatLng a, LatLng b) {
    final k = math.cos(p.latitude * math.pi / 180) * 111320;
    const m = 110540.0;
    final ax = (a.longitude - p.longitude) * k, ay = (a.latitude - p.latitude) * m;
    final bx = (b.longitude - p.longitude) * k, by = (b.latitude - p.latitude) * m;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final x = ax + t * dx, y = ay + t * dy;
    return math.sqrt(x * x + y * y);
  }

  Future<void> _reroute(LatLng pos) async {
    final dest = destination;
    if (dest == null) return;
    _rerouting = true;
    _lastReroute = DateTime.now();
    try {
      final r = await RoutingApi.route(pos, dest.latLng);
      if (r != null && mode == NavMode.navigating) {
        route = r;
        stepIndex = r.steps.length > 1 ? 1 : 0;
        _announced.clear();
        _recompute();
        _say('Rota yeniden hesaplandı. ${nextStep?.spoken ?? ''}');
        notifyListeners();
      }
    } catch (_) {}
    _rerouting = false;
  }
}

String formatDistance(double m) {
  if (m >= 10000) return '${(m / 1000).round()} km';
  if (m >= 1000) return '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  if (m >= 100) return '${(m / 50).round() * 50} m';
  return '${(m / 10).round() * 10} m';
}

String formatDuration(double s) {
  final mins = (s / 60).round();
  if (mins < 60) return '$mins dk';
  return '${mins ~/ 60} sa ${mins % 60} dk';
}
