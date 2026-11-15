import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class SimpleContact {
  final String name;
  final List<String> phones;
  final Uint8List? photo;
  const SimpleContact(this.name, this.phones, this.photo);
}

/// Rehber (sadece okuma).
class ContactsRepo extends ChangeNotifier {
  ContactsRepo._();
  static final ContactsRepo I = ContactsRepo._();

  List<SimpleContact> contacts = [];
  bool loading = false;
  bool denied = false;
  bool _loaded = false;

  bool get available => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> load({bool force = false}) async {
    if (!available || loading || (_loaded && !force)) return;
    loading = true;
    notifyListeners();
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        denied = true;
      } else {
        denied = false;
        final all = await FlutterContacts.getAll(
          properties: {ContactProperty.name, ContactProperty.phone, ContactProperty.photoThumbnail},
        );
        contacts = all
            .where((c) => c.phones.isNotEmpty)
            .map((c) => SimpleContact(
                  (c.displayName ?? '').trim().isEmpty ? c.phones.first.number : c.displayName!.trim(),
                  c.phones.map((p) => p.number).toList(),
                  c.photo?.thumbnail,
                ))
            .toList()
          ..sort((a, b) => _key(a.name).compareTo(_key(b.name)));
        _loaded = true;
      }
    } catch (_) {
      denied = true;
    }
    loading = false;
    notifyListeners();
  }

  /// Türkçe harfleri sıralama/arama için sadeleştirir.
  static String norm(String s) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'c', 'Ğ': 'g', 'Ö': 'o', 'Ş': 's', 'Ü': 'u', 'I': 'i', 'â': 'a', 'î': 'i',
    };
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(map[ch] ?? ch.toLowerCase());
    }
    return b.toString();
  }

  static String _key(String s) => norm(s);

  /// Sesli komuttaki ismi rehberde bulur. "annemi ara" -> "Annem".
  SimpleContact? findInSpeech(String speech, {List<SimpleContact>? extra}) {
    final words = norm(speech).replaceAll(RegExp(r"[^a-z0-9 ]"), ' ').split(RegExp(r'\s+'));
    SimpleContact? best;
    var bestScore = 0;
    for (final c in [...?extra, ...contacts]) {
      final n = norm(c.name).replaceAll(RegExp(r"[^a-z0-9 ]"), ' ').trim();
      if (n.isEmpty) continue;
      final parts = n.split(RegExp(r'\s+'));
      // Tam isim geçiyorsa en yüksek puan.
      final joined = words.join(' ');
      var score = 0;
      if (joined.contains(n)) {
        score = 100 + n.length;
      } else {
        // İlk isim, ek almış bir kelimenin başında mı? (ahmeti, ayşeyi, annemi)
        final first = parts.first;
        if (first.length >= 3 && words.any((w) => w.startsWith(first) && w.length - first.length <= 3)) {
          score = 10 + first.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }
}
