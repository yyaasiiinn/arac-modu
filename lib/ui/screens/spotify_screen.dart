import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/spotify_service.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import '../widgets/common.dart';

const _spGreen = Color(0xFF1ED760);

/// Spotify: telefondaki Spotify uygulamasının hesabıyla, uygulamanın içinden.
class SpotifyScreen extends StatefulWidget {
  const SpotifyScreen({super.key});

  @override
  State<SpotifyScreen> createState() => _SpotifyScreenState();
}

class _SpotifyScreenState extends State<SpotifyScreen> {
  int _tab = 0;
  Future<List<SpItem>>? _lists;
  Future<List<SpItem>>? _recent;
  Future<List<SpItem>>? _results;
  String _query = '';

  final sp = SpotifyService.I;

  @override
  void initState() {
    super.initState();
    if (sp.configured && !sp.connected) sp.connect().then((_) => _loadLibrary());
    if (sp.connected) _loadLibrary();
  }

  void _loadLibrary() {
    if (!mounted || !sp.connected) return;
    setState(() {
      _lists ??= sp.playlists();
      _recent ??= sp.recentlyPlayed();
    });
  }

  void _search(String q) {
    setState(() {
      _tab = 3;
      _query = q;
      _results = sp.search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sp,
      builder: (context, _) {
        if (!sp.supported) {
          return const EmptyState(
            icon: CupertinoIcons.music_note_2,
            title: 'Spotify telefonda çalışır',
            message: 'iPhone\'daki Spotify uygulamasının hesabıyla, giriş yapmadan kontrol edilir.',
          );
        }
        if (!sp.configured) return const _SetupView();
        if (!sp.connected) {
          return EmptyState(
            icon: CupertinoIcons.link,
            title: sp.connecting ? 'Spotify\'a bağlanılıyor…' : 'Spotify\'a bağlan',
            message: sp.error ??
                'Telefondaki Spotify hesabın kullanılır, giriş gerekmez. '
                    'Bağlanırken Spotify bir anlığına açılıp kendiliğinden geri döner.',
            action: sp.connecting ? null : 'Bağlan',
            onAction: () => sp.connect().then((_) => _loadLibrary()),
          );
        }
        if (_lists == null) WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: CarSegments(
                  items: const ['Çalan', 'Listelerim', 'Son Çalınanlar', 'Arama'],
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(width: 10),
              RoundButton(icon: CupertinoIcons.mic_fill, size: 44, color: _spGreen, onTap: () => VoiceAssistant.I.dictate(_search)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: switch (_tab) {
                0 => const _SpNowPlaying(),
                1 => _list(_lists, grid: true, empty: 'Çalma listesi yok'),
                2 => _list(_recent, empty: 'Son çalınan yok'),
                _ => _query.isEmpty
                    ? EmptyState(
                        icon: CupertinoIcons.mic_fill,
                        title: 'Spotify\'da ara',
                        message: 'Şarkı, sanatçı ya da liste adını söyleyin.',
                        action: 'Söyle',
                        onAction: () => VoiceAssistant.I.dictate(_search),
                      )
                    : _list(_results, empty: '"$_query" bulunamadı'),
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _list(Future<List<SpItem>>? f, {bool grid = false, required String empty}) {
    final p = Palette.of(context);
    return FutureBuilder<List<SpItem>>(
      future: f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final items = snap.data ?? [];
        if (items.isEmpty) return EmptyState(icon: CupertinoIcons.music_note_list, title: empty);
        if (grid) {
          return LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 165).floor().clamp(2, 8);
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return Pressable(
                  onTap: () {
                    sp.play(it.uri);
                    setState(() => _tab = 0);
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(aspectRatio: 1, child: _Cover(it.image)),
                    const SizedBox(height: 6),
                    Text(it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(it.subtitle, maxLines: 1, style: TextStyle(color: p.subtext, fontSize: 13)),
                  ]),
                );
              },
            );
          });
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const CarDivider(indent: 76),
          itemBuilder: (_, i) {
            final it = items[i];
            final current = it.uri == sp.trackUri;
            return CarRow(
              leading: SizedBox(width: 50, height: 50, child: _Cover(it.image)),
              title: it.title,
              titleColor: current ? _spGreen : null,
              subtitle: it.subtitle,
              onTap: () {
                sp.play(it.uri);
                setState(() => _tab = 0);
              },
            );
          },
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  final String url;
  const _Cover(this.url);

  @override
  Widget build(BuildContext context) {
    final fb = Container(
      color: const Color(0xFF282828),
      child: const Icon(CupertinoIcons.music_note_2, color: _spGreen),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url.isEmpty ? fb : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fb),
    );
  }
}

class _SpNowPlaying extends StatelessWidget {
  const _SpNowPlaying();

  String _t(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sp = SpotifyService.I;
    if (!sp.hasItem) {
      return const EmptyState(
        icon: CupertinoIcons.music_note_2,
        title: 'Spotify\'da çalan bir şey yok',
        message: 'Listelerim ya da Son Çalınanlar\'dan bir şey seçin.',
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final landscape = c.maxWidth > c.maxHeight;
      final art = landscape ? (c.maxHeight - 30).clamp(100.0, 280.0) : (c.maxWidth * 0.6).clamp(100.0, 280.0);
      final cover = Container(
        width: art,
        height: art,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF282828),
          image: sp.artwork != null ? DecorationImage(image: MemoryImage(sp.artwork!), fit: BoxFit.cover) : null,
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: sp.artwork == null ? const Icon(CupertinoIcons.music_note_2, color: _spGreen, size: 60) : null,
      );
      Widget btn(IconData i, VoidCallback f, double s) => Pressable(
            onTap: f,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: s, color: p.text)),
          );
      final info = Column(
        crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(sp.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text, fontSize: 28, fontWeight: FontWeight.w700)),
          Text(sp.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtext, fontSize: 19)),
          const SizedBox(height: 16),
          if (sp.durationMs > 0) ...[
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: _spGreen,
                inactiveTrackColor: p.card3,
              ),
              child: Slider(
                value: sp.livePositionMs.toDouble().clamp(0, sp.durationMs.toDouble()),
                max: sp.durationMs.toDouble(),
                onChanged: (v) => sp.seek(v.round()),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text(_t(sp.livePositionMs), style: TextStyle(color: p.subtext, fontSize: 14)),
              const Spacer(),
              Text('-${_t(sp.durationMs - sp.livePositionMs)}', style: TextStyle(color: p.subtext, fontSize: 14)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            btn(CupertinoIcons.shuffle, sp.toggleShuffle, 26),
            btn(CupertinoIcons.backward_fill, sp.previous, 40),
            btn(sp.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill, sp.playPause, 54),
            btn(CupertinoIcons.forward_fill, sp.next, 40),
          ]),
        ],
      );
      return Padding(
        padding: const EdgeInsets.all(14),
        child: landscape
            ? Row(children: [cover, const SizedBox(width: 28), Expanded(child: info)])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [cover, const SizedBox(height: 18), info]),
      );
    });
  }
}

/// İlk kurulum: Spotify Client ID girişi.
class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _ctl = TextEditingController(text: SpotifyService.I.clientId);
  String _bundle = 'com.yyaasiiinn.carMode';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted && i.packageName.isNotEmpty) setState(() => _bundle = i.packageName);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _spGreen, shape: BoxShape.circle),
              child: Text(n, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(t, style: TextStyle(color: p.text, fontSize: 16))),
          ]),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Spotify kurulumu (bir kez)', style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Telefondaki Spotify hesabın kullanılır; siteden giriş yapılmaz. Spotify bunun için ücretsiz bir uygulama kimliği ister.',
            style: TextStyle(color: p.subtext, fontSize: 15)),
        const SizedBox(height: 14),
        step('1', 'developer.spotify.com/dashboard adresine Spotify hesabınla gir ve "Create app"e dokun.'),
        step('2', 'Redirect URI olarak tam şunu yaz: ${SpotifyService.redirectUrl}'),
        step('3', '"iOS" ve "Web API" kutularını işaretle. iOS Bundle ID: $_bundle'),
        step('4', 'Oluşan "Client ID"yi kopyalayıp aşağıya yapıştır.'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _ctl,
                style: TextStyle(color: p.text, fontSize: 17),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Client ID',
                  hintStyle: TextStyle(color: p.subtext),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PillButton(
            text: 'Kaydet ve Bağlan',
            color: _spGreen,
            textColor: Colors.black,
            onTap: () {
              SpotifyService.I.setClientId(_ctl.text);
              if (SpotifyService.I.configured) SpotifyService.I.connect();
            },
          ),
        ]),
      ]),
    );
  }
}
