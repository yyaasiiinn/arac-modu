import 'package:latlong2/latlong.dart';

/// Kayıtlı/aranan bir konum.
class Place {
  final String name;
  final String address;
  final double lat;
  final double lon;

  const Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
  });

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'lat': lat, 'lon': lon};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );

  Place copyWith({String? name}) =>
      Place(name: name ?? this.name, address: address, lat: lat, lon: lon);
}

/// Favori kişi (Telefon > Favoriler).
class FavContact {
  final String name;
  final String number;
  const FavContact(this.name, this.number);

  Map<String, dynamic> toJson() => {'name': name, 'number': number};
  factory FavContact.fromJson(Map<String, dynamic> j) =>
      FavContact(j['name'] as String? ?? '', j['number'] as String? ?? '');
}

enum CallKind { call, message }

/// Uygulama üzerinden yapılan arama/mesaj kaydı (Son Aramalar).
class CallLog {
  final String name;
  final String number;
  final DateTime time;
  final CallKind kind;
  const CallLog(this.name, this.number, this.time, this.kind);

  Map<String, dynamic> toJson() => {
        'name': name,
        'number': number,
        'time': time.millisecondsSinceEpoch,
        'kind': kind.name,
      };
  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
        j['name'] as String? ?? '',
        j['number'] as String? ?? '',
        DateTime.fromMillisecondsSinceEpoch(j['time'] as int? ?? 0),
        j['kind'] == 'message' ? CallKind.message : CallKind.call,
      );
}

/// Yol tarifindeki tek adım.
class RouteStep {
  final String instruction; // ekranda gösterilen
  final String spoken; // sesli okunan
  final String road;
  final String type;
  final String modifier;
  final LatLng location; // manevra noktası
  final double distance; // bu adımın uzunluğu (m)
  final double duration; // s

  const RouteStep({
    required this.instruction,
    required this.spoken,
    required this.road,
    required this.type,
    required this.modifier,
    required this.location,
    required this.distance,
    required this.duration,
  });
}

class RouteData {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distance; // m
  final double duration; // s
  const RouteData(this.points, this.steps, this.distance, this.duration);
}
