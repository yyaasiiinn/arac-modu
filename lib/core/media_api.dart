import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// İnternet radyosu (radio-browser.info, ücretsiz ve anahtarsız).
class RadioStation {
  final String id;
  final String name;
  final String url;
  final String favicon;
  final String tags;
  const RadioStation(this.id, this.name, this.url, this.favicon, this.tags);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'favicon': favicon, 'tags': tags};
  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        j['id'] as String? ?? '',
        j['name'] as String? ?? '',
        j['url'] as String? ?? '',
        j['favicon'] as String? ?? '',
        j['tags'] as String? ?? '',
      );
}

/// Podcast programı.
class Podcast {
  final String id;
  final String name;
  final String author;
  final String artwork;
  final String feedUrl;
  const Podcast(this.id, this.name, this.author, this.artwork, this.feedUrl);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'author': author, 'artwork': artwork, 'feedUrl': feedUrl};
  factory Podcast.fromJson(Map<String, dynamic> j) => Podcast(
        j['id'] as String? ?? '',
        j['name'] as String? ?? '',
        j['author'] as String? ?? '',
        j['artwork'] as String? ?? '',
        j['feedUrl'] as String? ?? '',
      );
}

class Episode {
  final String title;
  final String url;
  final DateTime? date;
  final Duration? duration;
  final String artwork;
  const Episode(this.title, this.url, this.date, this.duration, this.artwork);
}

class MediaApi {
  static const _ua = {'User-Agent': 'CarModeApp/1.0 (github.com/yyaasiiinn/arac-modu)'};
  static const _radioHosts = ['de1.api.radio-browser.info', 'nl1.api.radio-browser.info', 'fi1.api.radio-browser.info'];

  static Future<List<RadioStation>> _radio(Map<String, String> q) async {
    for (final host in _radioHosts) {
      try {
        final res = await http
            .get(Uri.https(host, '/json/stations/search', q), headers: _ua)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        final seen = <String>{};
        final out = <RadioStation>[];
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final name = (m['name'] as String? ?? '').trim();
          final url = (m['url_resolved'] as String? ?? m['url'] as String? ?? '').trim();
          if (name.isEmpty || url.isEmpty) continue;
          // Aynı istasyonun kopyalarını ele.
          final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü]'), '');
          if (!seen.add(key)) continue;
          out.add(RadioStation(m['stationuuid'] as String? ?? url, name, url,
              m['favicon'] as String? ?? '', m['tags'] as String? ?? ''));
        }
        return out;
      } catch (_) {}
    }
    throw Exception('Radyo listesi alınamadı');
  }

  static Future<List<RadioStation>> topTurkishRadios() => _radio({
        'countrycode': 'TR',
        'order': 'clickcount',
        'reverse': 'true',
        'hidebroken': 'true',
        'limit': '80',
      });

  static Future<List<RadioStation>> searchRadio(String name) => _radio({
        'name': name,
        'countrycode': 'TR',
        'order': 'clickcount',
        'reverse': 'true',
        'hidebroken': 'true',
        'limit': '40',
      });

  static Podcast _podcastFrom(Map<String, dynamic> m) => Podcast(
        '${m['collectionId'] ?? m['trackId'] ?? m['id'] ?? ''}',
        (m['collectionName'] ?? m['name'] ?? '') as String,
        (m['artistName'] ?? '') as String,
        (m['artworkUrl600'] ?? m['artworkUrl100'] ?? '') as String,
        (m['feedUrl'] ?? '') as String,
      );

  static Future<List<Podcast>> searchPodcasts(String term) async {
    final uri = Uri.https('itunes.apple.com', '/search',
        {'media': 'podcast', 'term': term, 'country': 'TR', 'limit': '30'});
    final res = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (j['results'] as List)
        .map((e) => _podcastFrom(e as Map<String, dynamic>))
        .where((p) => p.feedUrl.isNotEmpty)
        .toList();
  }

  /// Türkiye'de en çok dinlenen podcast'ler.
  static Future<List<Podcast>> topPodcasts() async {
    Map<String, dynamic>? j;
    for (final host in ['rss.applemarketingtools.com', 'rss.marketingtools.apple.com']) {
      try {
        final res = await http
            .get(Uri.https(host, '/api/v2/tr/podcasts/top/30/podcasts.json'), headers: _ua)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          break;
        }
      } catch (_) {}
    }
    if (j == null) throw Exception('Liste alınamadı');
    final ids = ((j['feed'] as Map<String, dynamic>)['results'] as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final look = await http
        .get(Uri.https('itunes.apple.com', '/lookup', {'id': ids.join(','), 'country': 'TR'}), headers: _ua)
        .timeout(const Duration(seconds: 10));
    final lj = jsonDecode(utf8.decode(look.bodyBytes)) as Map<String, dynamic>;
    final byId = <String, Podcast>{};
    for (final e in lj['results'] as List) {
      final p = _podcastFrom(e as Map<String, dynamic>);
      if (p.feedUrl.isNotEmpty) byId[p.id] = p;
    }
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  static Future<List<Episode>> episodes(Podcast p) async {
    final res = await http.get(Uri.parse(p.feedUrl), headers: _ua).timeout(const Duration(seconds: 15));
    final doc = XmlDocument.parse(utf8.decode(res.bodyBytes, allowMalformed: true));
    final out = <Episode>[];
    for (final item in doc.findAllElements('item').take(60)) {
      final enc = item.getElement('enclosure');
      final url = enc?.getAttribute('url');
      if (url == null || url.isEmpty) continue;
      final title = item.getElement('title')?.innerText.trim() ?? 'Bölüm';
      DateTime? date;
      final pd = item.getElement('pubDate')?.innerText.trim();
      if (pd != null) date = _parseRfc822(pd);
      Duration? dur;
      final d = item.getElement('itunes:duration')?.innerText.trim();
      if (d != null && d.isNotEmpty) {
        final parts = d.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        var secs = 0;
        for (final x in parts) {
          secs = secs * 60 + x;
        }
        dur = Duration(seconds: secs);
      }
      final img = item.getElement('itunes:image')?.getAttribute('href') ?? p.artwork;
      out.add(Episode(title, url, date, dur, img));
    }
    return out;
  }

  static DateTime? _parseRfc822(String s) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})').firstMatch(s);
    if (m == null) return null;
    final mon = months[m.group(2)];
    if (mon == null) return null;
    return DateTime(int.parse(m.group(3)!), mon, int.parse(m.group(1)!));
  }
}
