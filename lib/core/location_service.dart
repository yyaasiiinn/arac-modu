import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// GPS konumu, hız ve yön.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService I = LocationService._();

  Position? position;
  double heading = 0; // derece, kuzey = 0
  String? error;
  StreamSubscription<Position>? _sub;

  LatLng? get latLng =>
      position == null ? null : LatLng(position!.latitude, position!.longitude);

  /// km/sa
  double get speedKmh {
    final s = position?.speed ?? 0;
    return s < 0.5 ? 0 : s * 3.6;
  }

  Future<void> start() async {
    if (_sub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Konum servisleri kapalı';
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        error = 'Konum izni verilmedi';
        notifyListeners();
        return;
      }
      error = null;

      LocationSettings settings;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        settings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        settings = const LocationSettings(accuracy: LocationAccuracy.high);
      }

      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) {
          position = p;
          // Duran araçta pusula yönü zıplamasın.
          if (p.speed > 1.5 && p.heading >= 0) heading = p.heading;
          notifyListeners();
        },
        onError: (e) {
          error = 'Konum alınamadı';
          notifyListeners();
        },
      );
    } catch (e) {
      error = 'Konum alınamadı';
      notifyListeners();
    }
  }
}
