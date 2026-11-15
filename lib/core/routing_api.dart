import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Adres arama (OpenStreetMap Nominatim) ve rota (OSRM) — ücretsiz, anahtarsız.
class RoutingApi {
  static const _ua = {'User-Agent': 'CarModeApp/1.0 (github.com/yyaasiiinn)'};

  static Future<List<Place>> search(String query, {LatLng? near, bool nearbyOnly = false}) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '10',
      'addressdetails': '1',
      'accept-language': 'tr',
      'countrycodes': 'tr',
    };
    if (near != null) {
      final d = nearbyOnly ? 0.08 : 1.5;
      params['viewbox'] =
          '${near.longitude - d},${near.latitude + d},${near.longitude + d},${near.latitude - d}';
      if (nearbyOnly) params['bounded'] = '1';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final res = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    final places = list.map((e) {
      final m = e as Map<String, dynamic>;
      final display = m['display_name'] as String? ?? '';
      final name = (m['name'] as String?)?.trim();
      final parts = display.split(', ');
      return Place(
        name: (name != null && name.isNotEmpty) ? name : parts.first,
        address: parts.skip(1).take(3).join(', '),
        lat: double.parse(m['lat'] as String),
        lon: double.parse(m['lon'] as String),
      );
    }).toList();
    if (near != null) {
      const dist = Distance();
      places.sort((a, b) =>
          dist(near, a.latLng).compareTo(dist(near, b.latLng)));
    }
    return places;
  }

  static Future<Place?> reverse(LatLng p) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${p.latitude}',
      'lon': '${p.longitude}',
      'format': 'jsonv2',
      'accept-language': 'tr',
    });
    try {
      final res = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 8));
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final display = m['display_name'] as String? ?? 'İşaretli konum';
      final parts = display.split(', ');
      return Place(
        name: parts.take(2).join(', '),
        address: parts.skip(2).take(3).join(', '),
        lat: p.latitude,
        lon: p.longitude,
      );
    } catch (_) {
      return Place(name: 'İşaretli konum', address: '', lat: p.latitude, lon: p.longitude);
    }
  }

  static Future<RouteData?> route(LatLng from, LatLng to) async {
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final res = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['code'] != 'Ok') return null;
    final r = (j['routes'] as List).first as Map<String, dynamic>;
    final coords = (r['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final steps = <RouteStep>[];
    for (final leg in r['legs'] as List) {
      for (final s in (leg as Map<String, dynamic>)['steps'] as List) {
        final st = s as Map<String, dynamic>;
        final man = st['maneuver'] as Map<String, dynamic>;
        final loc = man['location'] as List;
        final type = man['type'] as String? ?? '';
        final mod = man['modifier'] as String? ?? '';
        final road = (st['name'] as String? ?? '').trim();
        final exit = man['exit'] as int?;
        final base = _instruction(type, mod, exit);
        steps.add(RouteStep(
          instruction: base,
          spoken: road.isEmpty || type == 'arrive' ? base : '$base, $road',
          road: road,
          type: type,
          modifier: mod,
          location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          distance: (st['distance'] as num).toDouble(),
          duration: (st['duration'] as num).toDouble(),
        ));
      }
    }
    return RouteData(coords, steps, (r['distance'] as num).toDouble(),
        (r['duration'] as num).toDouble());
  }

  static String _dir(String mod) {
    switch (mod) {
      case 'left':
        return 'sola';
      case 'right':
        return 'sağa';
      case 'slight left':
        return 'hafif sola';
      case 'slight right':
        return 'hafif sağa';
      case 'sharp left':
        return 'keskin sola';
      case 'sharp right':
        return 'keskin sağa';
      case 'uturn':
        return 'geri';
      default:
        return 'düz';
    }
  }

  static String _instruction(String type, String mod, int? exit) {
    final d = _dir(mod);
    switch (type) {
      case 'depart':
        return 'Rotaya başlayın';
      case 'arrive':
        return 'Varış noktasına ulaştınız';
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        return exit != null
            ? 'Döner kavşaktan $exit. çıkışı kullanın'
            : 'Döner kavşağa girin';
      case 'exit roundabout':
      case 'exit rotary':
        return 'Döner kavşaktan çıkın';
      case 'merge':
        return 'Yola katılın';
      case 'on ramp':
        return 'Bağlantı yoluna girin';
      case 'off ramp':
        return d == 'düz' ? 'Bağlantı yolundan çıkın' : '${_cap(d)} çıkışı kullanın';
      case 'fork':
        return 'Yol ayrımında $d devam edin';
      case 'end of road':
        return 'Yolun sonunda $d dönün';
      case 'continue':
      case 'new name':
        return d == 'düz' ? 'Düz devam edin' : '${_cap(d)} devam edin';
      default:
        if (mod == 'uturn') return 'U dönüşü yapın';
        if (d == 'düz') return 'Düz devam edin';
        return '${_cap(d)} dönün';
    }
  }

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}
