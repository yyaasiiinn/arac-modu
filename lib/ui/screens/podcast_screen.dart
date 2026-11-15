import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/in_app_player.dart';
import '../../core/media_api.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import '../widgets/common.dart';
import '../widgets/now_playing_card.dart';

/// Podcast'ler: abonelikler, Türkiye listesi, sesli arama, bölüm oynatma.
class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  late int _tab = InAppPlayer.I.subscriptions.isEmpty ? 1 : 0;
  List<Podcast> _top = [];
  List<Podcast> _results = [];
  String _query = '';
  bool _loading = false;
  String? _error;
  Podcast? _open;

  @override
  void initState() {
    super.initState();
    _loadTop();
  }

  Future<void> _loadTop() async {
    if (_top.isNotEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _top = await MediaApi.topPodcasts();
    } catch (_) {
      _error = 'Liste alınamadı. İnternet bağlantısını kontrol edin.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    setState(() {
      _tab = 2;
      _query = q;
      _loading = true;
      _error = null;
      _open = null;
    });
    try {
      _results = await MediaApi.searchPodcasts(q);
      if (_results.isEmpty) _error = '"$q" bulunamadı';
    } catch (_) {
      _error = 'Arama yapılamadı';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_open != null) {
      return _EpisodesView(podcast: _open!, onBack: () => setState(() => _open = null));
    }
    return ListenableBuilder(
      listenable: InAppPlayer.I,
      builder: (context, _) {
        final ip = InAppPlayer.I;
        final list = switch (_tab) {
          0 => ip.subscriptions,
          1 => _top,
          _ => _results,
        };
        Widget body;
        if (_tab == 0 && list.isEmpty) {
          body = const EmptyState(
            icon: CupertinoIcons.dot_radiowaves_left_right,
            title: 'Abonelik yok',
            message: 'Popüler listeden ya da aramadan bir programa girip "Abone Ol"a dokunun.',
          );
        } else if (_tab == 2 && _query.isEmpty) {
          body = EmptyState(
            icon: CupertinoIcons.mic_fill,
            title: 'Podcast ara',
            message: 'Mikrofona dokunup programın adını söyleyin.',
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
              _top = [];
              _loadTop();
            }
          });
        } else {
          body = _grid(list);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: CarSegments(
                  items: const ['Aboneliklerim', 'Popüler', 'Arama'],
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

  Widget _grid(List<Podcast> list) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 165).floor().clamp(2, 8);
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final pod = list[i];
          return Pressable(
            onTap: () => setState(() => _open = pod),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(aspectRatio: 1, child: PodcastArt(pod.artwork)),
              const SizedBox(height: 6),
              Text(pod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
              Text(pod.author,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtext, fontSize: 13)),
            ]),
          );
        },
      );
    });
  }
}

class PodcastArt extends StatelessWidget {
  final String url;
  const PodcastArt(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final fb = Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD56DFB), Color(0xFF872EC4)])),
      child: const Icon(CupertinoIcons.dot_radiowaves_left_right, color: Colors.white, size: 40),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty ? fb : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fb),
    );
  }
}

class _EpisodesView extends StatefulWidget {
  final Podcast podcast;
  final VoidCallback onBack;
  const _EpisodesView({required this.podcast, required this.onBack});

  @override
  State<_EpisodesView> createState() => _EpisodesViewState();
}

class _EpisodesViewState extends State<_EpisodesView> {
  List<Episode>? _eps;
  String? _error;

  @override
  void initState() {
    super.initState();
    MediaApi.episodes(widget.podcast).then((e) {
      if (mounted) setState(() => _eps = e);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Bölümler alınamadı');
    });
  }

  String _dur(Duration d) {
    if (d.inHours > 0) return '${d.inHours} sa ${d.inMinutes % 60} dk';
    return '${d.inMinutes} dk';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pod = widget.podcast;
    return ListenableBuilder(
      listenable: InAppPlayer.I,
      builder: (context, _) {
        final ip = InAppPlayer.I;
        final sub = ip.isSubscribed(pod);
        Widget body;
        if (_error != null) {
          body = EmptyState(icon: CupertinoIcons.exclamationmark_triangle, title: _error!);
        } else if (_eps == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (_eps!.isEmpty) {
          body = const EmptyState(icon: CupertinoIcons.dot_radiowaves_left_right, title: 'Bölüm yok');
        } else {
          body = ListView.separated(
            itemCount: _eps!.length,
            separatorBuilder: (_, _) => const CarDivider(indent: 14),
            itemBuilder: (_, i) {
              final e = _eps![i];
              final current = ip.title == e.title && ip.kind == PlayerKind.podcast;
              final saved = ip.savedPosition(e.url);
              final meta = [
                if (e.date != null) DateFormat('d MMM y').format(e.date!),
                if (e.duration != null && e.duration!.inSeconds > 0) _dur(e.duration!),
                if (saved > 60) '${saved ~/ 60}. dakikada kaldınız',
              ].join(' · ');
              return CarRow(
                onTap: () => current ? ip.playPause() : ip.playEpisode(e, pod, queue: _eps),
                title: e.title,
                titleColor: current ? CP.purple : null,
                subtitle: meta,
                trailing: Icon(
                  current && ip.isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                  color: CP.purple,
                  size: 38,
                ),
              );
            },
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            CarHeader(title: '', onBack: widget.onBack, actions: [
              PillButton(
                text: sub ? 'Abonesiniz' : 'Abone Ol',
                icon: sub ? CupertinoIcons.checkmark_alt : CupertinoIcons.plus,
                height: 42,
                color: sub ? p.card2 : CP.purple,
                textColor: sub ? p.text : Colors.white,
                onTap: () => ip.toggleSubscription(pod),
              ),
            ]),
            Row(children: [
              SizedBox(width: 64, height: 64, child: PodcastArt(pod.artwork)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pod.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(pod.author,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtext, fontSize: 15)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(child: body),
            const MiniPlayerBar(),
          ]),
        );
      },
    );
  }
}
