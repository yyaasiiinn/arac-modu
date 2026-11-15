import 'package:flutter/foundation.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/contacts_repo.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import '../widgets/common.dart';

/// Telefon: Favoriler, Son Aramalar, Kişiler, Tuş Takımı.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  int _tab = 0;
  SimpleContact? _detail;

  @override
  void initState() {
    super.initState();
    ContactsRepo.I.load();
    if (AppState.I.favorites.isEmpty) _tab = 2;
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return ContactDetail(contact: _detail!, onBack: () => setState(() => _detail = null));
    }
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.I, ContactsRepo.I]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(children: [
          CarSegments(
            items: const ['Favoriler', 'Son', 'Kişiler', 'Tuşlar'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_tab) {
              0 => _favorites(),
              1 => _recents(),
              2 => _contacts(),
              _ => const Keypad(),
            },
          ),
        ]),
      ),
    );
  }

  Widget _favorites() {
    final favs = AppState.I.favorites;
    if (favs.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.star,
        title: 'Favori yok',
        message: 'Kişiler sekmesinden bir kişiyi açıp yıldıza dokunarak ekleyin.',
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 150).floor().clamp(2, 6);
      return GridView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 1.05),
        itemCount: favs.length,
        itemBuilder: (_, i) {
          final f = favs[i];
          return Pressable(
            onTap: () => AppState.I.call(f.name, f.number),
            onLongPress: () => _confirmRemove(f),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Avatar(f.name, size: 72, photo: _photoFor(f.number)),
              const SizedBox(height: 8),
              Text(f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Palette.of(context).text, fontSize: 17, fontWeight: FontWeight.w600)),
              Text('mobil', style: TextStyle(color: Palette.of(context).subtext, fontSize: 13)),
            ]),
          );
        },
      );
    });
  }

  Uint8List? _photoFor(String number) {
    final d = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 7) return null;
    final tail = d.substring(d.length - 7);
    for (final c in ContactsRepo.I.contacts) {
      if (c.photo != null && c.phones.any((p) => p.replaceAll(RegExp(r'[^0-9]'), '').endsWith(tail))) return c.photo;
    }
    return null;
  }

  void _confirmRemove(FavContact f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.name),
        content: const Text('Favorilerden kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () {
              AppState.I.toggleFavorite(f.name, f.number);
              Navigator.pop(ctx);
            },
            child: const Text('Kaldır', style: TextStyle(color: CP.red)),
          ),
        ],
      ),
    );
  }

  Widget _recents() {
    final rec = AppState.I.recents;
    if (rec.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.clock,
        title: 'Son arama yok',
        message: 'Bu uygulamadan yaptığınız aramalar burada görünür.',
      );
    }
    final p = Palette.of(context);
    return ListView.separated(
      itemCount: rec.length,
      separatorBuilder: (_, _) => const CarDivider(indent: 70),
      itemBuilder: (_, i) {
        final r = rec[i];
        final now = DateTime.now();
        final sameDay = r.time.year == now.year && r.time.month == now.month && r.time.day == now.day;
        return CarRow(
          onTap: () => r.kind == CallKind.call
              ? AppState.I.call(r.name, r.number)
              : _message(r.name, r.number),
          leading: Avatar(r.name.isEmpty ? '#' : r.name, size: 44, photo: _photoFor(r.number)),
          title: r.name.isEmpty ? r.number : r.name,
          subtitle: r.kind == CallKind.call ? 'Giden arama' : 'Mesaj',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.kind == CallKind.call ? CupertinoIcons.phone_fill_arrow_up_right : CupertinoIcons.chat_bubble_fill,
                color: p.subtext, size: 16),
            const SizedBox(width: 6),
            Text(sameDay ? DateFormat.Hm().format(r.time) : DateFormat('d MMM').format(r.time),
                style: TextStyle(color: p.subtext, fontSize: 15)),
          ]),
        );
      },
    );
  }

  void _message(String name, String number) {
    composeRequest.value = ComposeRequest(FavContact(name, number), '');
    AppState.I.open(CarApp.messages);
  }

  Widget _contacts() {
    final repo = ContactsRepo.I;
    if (!repo.available) {
      return const EmptyState(
        icon: CupertinoIcons.person_2,
        title: 'Rehber bu cihazda kullanılamıyor',
        message: 'Kişiler iPhone/Android uygulamasında görünür. Tuşlar sekmesini kullanabilirsiniz.',
      );
    }
    if (repo.loading) return const Center(child: CircularProgressIndicator());
    if (repo.denied) {
      return EmptyState(
        icon: CupertinoIcons.person_crop_circle_badge_xmark,
        title: 'Rehber izni yok',
        message: 'Ayarlar > Araç Modu > Kişiler bölümünden izin verin.',
        action: 'Tekrar Dene',
        onAction: () => repo.load(force: true),
      );
    }
    if (repo.contacts.isEmpty) {
      return const EmptyState(icon: CupertinoIcons.person_2, title: 'Rehberde telefon numaralı kişi yok');
    }
    return _ContactList(onOpen: (c) => setState(() => _detail = c));
  }
}

class _ContactList extends StatefulWidget {
  final ValueChanged<SimpleContact> onOpen;
  const _ContactList({required this.onOpen});

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  final _sc = ScrollController();
  static const _rowH = 66.6;

  String _letter(String name) {
    final n = ContactsRepo.norm(name);
    if (n.isEmpty) return '#';
    final ch = name.characters.first.toUpperCase();
    return RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(ch) ? ch : '#';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final list = ContactsRepo.I.contacts;
    final letters = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      letters.putIfAbsent(_letter(list[i].name), () => i);
    }
    return Row(children: [
      Expanded(
        child: ListView.builder(
          controller: _sc,
          itemExtent: _rowH,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            return Column(children: [
              Expanded(
                child: CarRow(
                  onTap: () => widget.onOpen(c),
                  leading: Avatar(c.name, size: 42, photo: c.photo),
                  title: c.name,
                  trailing: AppState.I.isFavorite(c.phones.first)
                      ? const Icon(CupertinoIcons.star_fill, color: CP.yellow, size: 18)
                      : null,
                ),
              ),
              const CarDivider(indent: 70),
            ]);
          },
        ),
      ),
      SizedBox(
        width: 26,
        child: LayoutBuilder(builder: (context, c) {
          final keys = letters.keys.toList();
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in keys)
                Flexible(
                  child: GestureDetector(
                    onTap: () => _sc.jumpTo((letters[k]! * _rowH).clamp(0, _sc.position.maxScrollExtent)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(k, style: const TextStyle(color: CP.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
      SizedBox(width: 2, child: Container(color: p.bg)),
    ]);
  }
}

/// Kişi kartı: numaralar, ara, mesaj, favori.
class ContactDetail extends StatelessWidget {
  final SimpleContact contact;
  final VoidCallback onBack;
  const ContactDetail({super.key, required this.contact, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) => Column(children: [
        CarHeader(title: '', onBack: onBack),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            Center(child: Avatar(contact.name, size: 90, photo: contact.photo)),
            const SizedBox(height: 10),
            Center(
              child: Text(contact.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            for (final n in contact.phones)
              CarCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: CarRow(
                  title: n,
                  subtitle: 'telefon',
                  onTap: () => AppState.I.call(contact.name, n),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    RoundButton(
                      icon: CupertinoIcons.chat_bubble_fill,
                      size: 50,
                      onTap: () {
                        composeRequest.value = ComposeRequest(FavContact(contact.name, n), '');
                        AppState.I.open(CarApp.messages);
                      },
                    ),
                    const SizedBox(width: 10),
                    RoundButton(icon: CupertinoIcons.phone_fill, color: CP.green, size: 50, onTap: () => AppState.I.call(contact.name, n)),
                    const SizedBox(width: 10),
                    RoundButton(
                      icon: AppState.I.isFavorite(n) ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      color: p.card2,
                      iconColor: CP.yellow,
                      size: 50,
                      onTap: () => AppState.I.toggleFavorite(contact.name, n),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Tuş takımı.
class Keypad extends StatefulWidget {
  const Keypad({super.key});

  @override
  State<Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<Keypad> {
  String _num = '';

  static const _keys = [
    ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
    ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
    ['*', ''], ['0', '+'], ['#', ''],
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final landscape = c.maxWidth > c.maxHeight * 1.2;
      final keyH = landscape ? (c.maxHeight / 4) - 8 : (c.maxHeight - 140) / 4 - 8;
      final keySize = keyH.clamp(40.0, 84.0);

      final display = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(_num.isEmpty ? ' ' : _num,
                style: TextStyle(color: p.text, fontSize: 38, fontWeight: FontWeight.w500, letterSpacing: 1)),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            RoundButton(
              icon: CupertinoIcons.phone_fill,
              color: CP.green,
              size: 70,
              onTap: _num.isEmpty ? null : () => AppState.I.call('', _num),
            ),
            if (_num.isNotEmpty) ...[
              const SizedBox(width: 24),
              Pressable(
                onTap: () => setState(() => _num = _num.substring(0, _num.length - 1)),
                onLongPress: () => setState(() => _num = ''),
                child: Icon(CupertinoIcons.delete_left_fill, color: p.subtext, size: 36),
              ),
            ],
          ]),
        ],
      );

      final pad = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var r = 0; r < 4; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < 3; k++) _key(_keys[r * 3 + k], keySize, p),
                ],
              ),
            ),
        ],
      );

      return landscape
          ? Row(children: [Expanded(child: display), Expanded(child: pad)])
          : Column(children: [SizedBox(height: 130, child: display), Expanded(child: pad)]);
    });
  }

  Widget _key(List<String> k, double size, Palette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Pressable(
        onTap: () => setState(() => _num += k[0]),
        onLongPress: k[0] == '0' ? () => setState(() => _num += '+') : null,
        child: Container(
          width: size * 1.25,
          height: size,
          decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(size / 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(k[0], style: TextStyle(color: p.text, fontSize: size * 0.4, fontWeight: FontWeight.w500, height: 1.1)),
            if (k[1].isNotEmpty)
              Text(k[1], style: TextStyle(color: p.subtext, fontSize: size * 0.14, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
