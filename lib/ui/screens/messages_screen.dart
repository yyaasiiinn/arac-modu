import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/contacts_repo.dart';
import '../../core/models.dart';
import '../../core/nav_controller.dart';
import '../../core/theme.dart';
import '../../core/tts_service.dart';
import '../../core/voice_assistant.dart';
import '../widgets/common.dart';

/// Mesajlar: kişi seç, sesle yaz, oku, SMS/WhatsApp ile gönder.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  FavContact? _to;
  String _body = '';
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    composeRequest.addListener(_onRequest);
    _onRequest();
    ContactsRepo.I.load();
  }

  @override
  void dispose() {
    composeRequest.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    final r = composeRequest.value;
    if (r == null) return;
    composeRequest.value = null;
    setState(() {
      _to = r.to;
      _body = r.body;
      _picking = false;
    });
    if (r.body.isEmpty) {
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted && _to != null && _body.isEmpty) _dictate();
      });
    }
  }

  void _dictate() {
    VoiceAssistant.I.dictate((text) {
      setState(() => _body = _body.isEmpty ? text : '$_body $text');
      Tts.I.speak('Mesajınız: $text');
    });
  }

  List<String> get _quick {
    final q = <String>['Yoldayım, geliyorum.', 'Araç kullanıyorum, sonra arayacağım.', 'Tamam 👍', 'Biraz gecikeceğim.'];
    final nav = NavController.I;
    if (nav.active) {
      q.insert(0, '${nav.destination?.name ?? 'Hedefe'} varış saatim ${DateFormat.Hm().format(nav.eta)} '
          '(${formatDuration(nav.remainingSeconds)} kaldı).');
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    if (_picking) return _picker();
    if (_to != null) return _compose();
    return _home();
  }

  Widget _home() {
    final p = Palette.of(context);
    final st = AppState.I;
    final recentMsg = <FavContact>[];
    for (final r in st.recents.where((e) => e.kind == CallKind.message)) {
      if (!recentMsg.any((e) => e.number == r.number)) recentMsg.add(FavContact(r.name, r.number));
    }
    final people = [...recentMsg, ...st.favorites.where((f) => !recentMsg.any((r) => r.number == f.number))];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(children: [
        CarHeader(
          title: 'Mesajlar',
          actions: [
            Pressable(
              onTap: () => setState(() => _picking = true),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(CupertinoIcons.square_pencil, color: CP.blue, size: 30),
              ),
            ),
          ],
        ),
        Expanded(
          child: people.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.chat_bubble_2,
                  title: 'Yeni mesaj',
                  message: 'Kişi seçip sesinizle yazdırabilirsiniz. Sesli asistana "Ahmet\'e mesaj gönder yoldayım" da diyebilirsiniz.',
                  action: 'Kişi Seç',
                  onAction: () => setState(() => _picking = true),
                )
              : ListView.separated(
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const CarDivider(indent: 70),
                  itemBuilder: (_, i) {
                    final f = people[i];
                    return CarRow(
                      onTap: () => setState(() {
                        _to = f;
                        _body = '';
                      }),
                      leading: Avatar(f.name.isEmpty ? '#' : f.name, size: 44),
                      title: f.name.isEmpty ? f.number : f.name,
                      subtitle: f.number,
                      trailing: Icon(CupertinoIcons.chevron_right, color: p.subtext),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _picker() {
    final repo = ContactsRepo.I;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final favs = AppState.I.favorites;
        final rows = <Widget>[];
        for (final f in favs) {
          rows.add(CarRow(
            leading: Avatar(f.name, size: 42),
            title: f.name,
            subtitle: 'Favori',
            trailing: const Icon(CupertinoIcons.star_fill, color: CP.yellow, size: 18),
            onTap: () => _pick(f),
          ));
        }
        for (final c in repo.contacts) {
          for (final n in c.phones.take(2)) {
            rows.add(CarRow(
              leading: Avatar(c.name, size: 42, photo: c.photo),
              title: c.name,
              subtitle: n,
              onTap: () => _pick(FavContact(c.name, n)),
            ));
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            CarHeader(title: 'Kime?', onBack: () => setState(() => _picking = false)),
            Expanded(
              child: rows.isEmpty
                  ? EmptyState(
                      icon: CupertinoIcons.person_2,
                      title: repo.loading ? 'Yükleniyor…' : 'Kişi bulunamadı',
                      message: repo.denied ? 'Rehber izni verilmedi.' : null,
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const CarDivider(indent: 70),
                      itemBuilder: (_, i) => rows[i],
                    ),
            ),
          ]),
        );
      },
    );
  }

  void _pick(FavContact f) {
    setState(() {
      _to = f;
      _body = '';
      _picking = false;
    });
    Tts.I.speak('${f.name} kişisine ne yazmak istersiniz?');
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted && _to == f && _body.isEmpty) _dictate();
    });
  }

  Widget _compose() {
    final p = Palette.of(context);
    final to = _to!;
    return LayoutBuilder(builder: (context, c) {
      final landscape = c.maxWidth > c.maxHeight;
      final bubble = Expanded(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
          child: SingleChildScrollView(
            child: _body.isEmpty
                ? Text('Mikrofona dokunup mesajınızı söyleyin ya da hazır bir yanıt seçin.',
                    style: TextStyle(color: p.subtext, fontSize: 20))
                : Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: CP.blue, borderRadius: BorderRadius.circular(20)),
                      child: Text(_body, style: const TextStyle(color: Colors.white, fontSize: 21)),
                    ),
                  ),
          ),
        ),
      );

      final quick = SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final q in _quick)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PillButton(
                  text: q,
                  height: 46,
                  color: p.card2,
                  textColor: p.text,
                  onTap: () => setState(() => _body = q),
                ),
              ),
          ],
        ),
      );

      final actions = Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: [
          RoundButton(icon: CupertinoIcons.mic_fill, size: 66, label: 'Söyle', onTap: _dictate),
          RoundButton(
            icon: CupertinoIcons.speaker_2_fill,
            size: 66,
            color: p.card2,
            iconColor: p.text,
            label: 'Oku',
            onTap: _body.isEmpty ? null : () => Tts.I.speak(_body),
          ),
          RoundButton(
            icon: CupertinoIcons.trash_fill,
            size: 66,
            color: p.card2,
            iconColor: CP.red,
            label: 'Temizle',
            onTap: () => setState(() => _body = ''),
          ),
          RoundButton(
            icon: CupertinoIcons.arrow_up,
            size: 66,
            color: CP.green,
            label: 'SMS',
            onTap: _body.isEmpty
                ? null
                : () async {
                    final r = await AppState.I.sendSms(to.name, to.number, _body);
                    if (!mounted) return;
                    if (r == 'sent' || r == 'external') {
                      setState(() => _body = '');
                      if (r == 'sent') Tts.I.speak('Mesaj gönderildi.');
                    } else if (r == 'failed') {
                      Tts.I.speak('Mesaj gönderilemedi.');
                    }
                  },
          ),
          RoundButton(
            icon: CupertinoIcons.chat_bubble_text_fill,
            size: 66,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            onTap: _body.isEmpty
                ? null
                : () {
                    AppState.I.sendWhatsApp(to.number, _body);
                    setState(() => _body = '');
                  },
          ),
        ],
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(children: [
          CarHeader(
            title: to.name.isEmpty ? to.number : to.name,
            onBack: () => setState(() {
              _to = null;
              _body = '';
            }),
          ),
          Expanded(
            child: landscape
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 3, child: Column(children: [bubble, const SizedBox(height: 10), quick])),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: Center(child: SingleChildScrollView(child: actions))),
                  ])
                : Column(children: [bubble, const SizedBox(height: 10), quick, const SizedBox(height: 14), actions]),
          ),
        ]),
      );
    });
  }
}
