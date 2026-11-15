import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import '../../core/in_app_player.dart';
import '../../core/media_api.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import '../widgets/common.dart';
import '../widgets/now_playing_card.dart';

/// Radyo: Türkiye'deki canlı radyolar, favoriler, sesli arama.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late int _tab = InAppPlayer.I.favoriteStations.isEmpty ? 1 : 0;
  List<RadioStation> _popular = [];
  List<RadioStation> _results = [];
  String _query = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  Future<void> _loadPopular() async {
    if (_popular.isNotEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _popular = await MediaApi.topTurkishRadios();
    } catch (_) {
      _error = 'Radyo listesi alınamadı. İnternet bağlantısını kontrol edin.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    setState(() {
      _tab = 2;
      _query = q;
      _loading = true;
      _error = null;
    });
    try {
      _results = await MediaApi.searchRadio(q);
      if (_results.isEmpty) _error = '"$q" bulunamadı';
    } catch (_) {
      _error = 'Arama yapılamadı';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InAppPlayer.I,
      builder: (context, _) {
        final ip = InAppPlayer.I;
        final list = switch (_tab) {
          0 => ip.favoriteStations,
          1 => _popular,
          _ => _results,
        };
        Widget body;
        if (_tab == 0 && list.isEmpty) {
          body = const EmptyState(
            icon: CupertinoIcons.star,
            title: 'Favori radyo yok',
            message: 'Popüler sekmesinde bir istasyona basılı tutarak ya da çalarken yıldıza dokunarak ekleyin.',
          );
        } else if (_tab == 2 && _query.isEmpty) {
          body = EmptyState(
            icon: CupertinoIcons.mic_fill,
            title: 'Radyo ara',
            message: 'Mikrofona dokunup istasyonun adını söyleyin (ör. "Kral FM").',
            action: 'Söyle',
            onAction: () => VoiceAssistant.I.dictate(_search),
          );
        } else if (_loading && list.isEmpty) {
          body = const Center(child: CircularProgressIndicator());
        } else if (_error != null && list.isEmpty) {
          body = EmptyState(icon: CupertinoIcons.wifi_exclamationmark, title: _error!, action: 'Tekrar Dene', onAction: () {
            if (_tab == 2) {
              _search(_query);
            } else {
              _popular = [];
              _loadPopular();
            }
          });
        } else {
          body = _grid(list, ip);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: CarSegments(
                  items: const ['Favoriler', 'Popüler', 'Arama'],
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(width: 10),
              RoundButton(icon: CupertinoIcons.mic_fill, size: 44, onTap: () => VoiceAssistant.I.dictate(_search)),
            ]),
            const SizedBox(height: 8),
            Expanded(child: body),
            const MiniPlayerBar(),
          ]),
        );
      },
    );
  }

  Widget _grid(List<RadioStation> list, InAppPlayer ip) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 170).floor().clamp(2, 8);
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final s = list[i];
          final current = ip.station?.id == s.id;
          final fav = ip.isFavoriteStation(s);
          return Pressable(
            onTap: () => ip.playStation(s, queue: list),
            onLongPress: () {
              ip.toggleFavoriteStation(s);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(fav ? '${s.name} favorilerden çıkarıldı' : '${s.name} favorilere eklendi'),
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: current ? CP.blue.withValues(alpha: 0.25) : p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: current ? CP.blue : Colors.transparent, width: 2),
              ),
              child: Column(children: [
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(child: StationLogo(s)),
                    if (fav)
                      const Positioned(
                        right: 2,
                        top: 2,
                        child: Icon(CupertinoIcons.star_fill, color: CP.yellow, size: 18),
                      ),
                    if (current && ip.isPlaying)
                      const Positioned(
                        left: 2,
                        top: 2,
                        child: Icon(CupertinoIcons.speaker_3_fill, color: CP.blue, size: 18),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        },
      );
    });
  }
}

class StationLogo extends StatelessWidget {
  final RadioStation s;
  const StationLogo(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final initials = s.name.trim().isEmpty ? '?' : s.name.trim().characters.take(2).toString().toUpperCase();
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A5B), Color(0xFFE8452C)]),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
    );
    if (s.favicon.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        s.favicon,
        fit: BoxFit.contain,
        // Logo yüklenince beyaz zemin üstünde göster, yüklenemezse baş harfler.
        frameBuilder: (_, child, frame, sync) => frame == null && !sync
            ? fallback
            : Container(color: Colors.white, padding: const EdgeInsets.all(6), child: child),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
