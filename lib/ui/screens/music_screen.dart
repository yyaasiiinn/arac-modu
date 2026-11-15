import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/music_service.dart';
import '../../core/theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/common.dart';
import '../widgets/now_playing_card.dart';

/// Müzik: Şu An Çalan, Çalma Listeleri, diğer müzik uygulamaları.
class MusicScreen extends StatefulWidget {
  final bool startOnNowPlaying;
  const MusicScreen({super.key, this.startOnNowPlaying = false});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  late int _tab = widget.startOnNowPlaying || MusicService.I.hasItem ? 0 : 1;
  Future<List<Playlist>>? _lists;

  @override
  void initState() {
    super.initState();
    _lists = MusicService.I.playlists();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(children: [
        CarSegments(
          items: const ['Şu An Çalan', 'Kitaplık', 'Uygulamalar'],
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const NowPlayingView(),
            1 => _library(),
            _ => _apps(),
          },
        ),
      ]),
    );
  }

  Widget _library() {
    final m = MusicService.I;
    if (!m.supported) {
      return const EmptyState(
        icon: CupertinoIcons.music_note_list,
        title: 'Kitaplık sadece iPhone\'da',
        message: 'Apple Music kitaplığınız iPhone uygulamasında görünür. Spotify için Uygulamalar sekmesini kullanın.',
      );
    }
    final p = Palette.of(context);
    return FutureBuilder<List<Playlist>>(
      future: _lists,
      builder: (context, snap) {
        final lists = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.only(top: 6),
          children: [
            CarRow(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: CP.red, borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.shuffle, color: Colors.white),
              ),
              title: 'Tümünü Karışık Çal',
              onTap: () {
                m.shuffleAll();
                setState(() => _tab = 0);
              },
            ),
            const CarDivider(indent: 76),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (snap.connectionState == ConnectionState.done && lists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  m.authorized
                      ? 'Kitaplıkta çalma listesi yok.'
                      : 'Müzik kitaplığına izin verilmedi. Ayarlar > Araç Modu > Medya ve Apple Music.',
                  style: TextStyle(color: p.subtext, fontSize: 16),
                ),
              ),
            for (final l in lists) ...[
              CarRow(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(10)),
                  child: Icon(CupertinoIcons.music_note_list, color: p.text),
                ),
                title: l.name,
                subtitle: '${l.count} şarkı',
                trailing: Icon(CupertinoIcons.play_circle_fill, color: CP.red, size: 32),
                onTap: () {
                  m.playPlaylist(l.id);
                  setState(() => _tab = 0);
                },
              ),
              const CarDivider(indent: 76),
            ],
          ],
        );
      },
    );
  }

  Widget _apps() {
    const apps = [CarApp.spotify, CarApp.youtubeMusic, CarApp.podcasts, CarApp.audiobooks];
    return Center(
      child: Wrap(
        spacing: 30,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          for (final a in apps)
            AppTile(
              info: appInfos[a]!,
              size: 80,
              labelColor: Palette.of(context).text,
              onTap: () => AppState.I.open(a),
            ),
        ],
      ),
    );
  }
}

/// Büyük "Şu An Çalan" ekranı.
class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  String _t(double s) {
    if (s.isNaN || s < 0) s = 0;
    final m = s ~/ 60;
    final sec = (s % 60).floor();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: MusicService.I,
      builder: (context, _) {
        final m = MusicService.I;
        if (!m.supported) {
          return EmptyState(
            icon: CupertinoIcons.music_note_2,
            title: 'Müzik kontrolü',
            message: 'iPhone\'da Müzik uygulamasını buradan yönetebilirsiniz. Spotify/YouTube Music için uygulamayı açın; '
                'sesli komut ve araçtaki tuşlar da çalışır.',
            action: 'Spotify\'ı Aç',
            onAction: () => AppState.I.open(CarApp.spotify),
          );
        }
        return LayoutBuilder(builder: (context, c) {
          final landscape = c.maxWidth > c.maxHeight;
          final artSize = landscape ? (c.maxHeight - 40).clamp(100.0, 300.0) : (c.maxWidth * 0.6).clamp(100.0, 300.0);

          final info = Column(
            crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(m.hasItem ? m.title : 'Çalan bir şey yok',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: landscape ? TextAlign.start : TextAlign.center,
                  style: TextStyle(color: p.text, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(m.hasItem ? [m.artist, m.album].where((e) => e.isNotEmpty).join(' — ') : 'Kitaplıktan bir liste seçin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.subtext, fontSize: 19)),
              const SizedBox(height: 18),
              if (m.duration > 0) ...[
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: p.text,
                    inactiveTrackColor: p.card3,
                  ),
                  child: Slider(
                    value: m.position.clamp(0, m.duration),
                    max: m.duration,
                    onChanged: (v) => m.seek(v),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text(_t(m.position), style: TextStyle(color: p.subtext, fontSize: 14)),
                  const Spacer(),
                  Text('-${_t(m.duration - m.position)}', style: TextStyle(color: p.subtext, fontSize: 14)),
                ]),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(CupertinoIcons.shuffle, m.toggleShuffle, p, active: m.shuffle, size: 26),
                  _btn(CupertinoIcons.backward_fill, m.previous, p, size: 40),
                  _btn(m.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, m.playPause, p, size: 54),
                  _btn(CupertinoIcons.forward_fill, m.next, p, size: 40),
                  _btn(m.repeat == 2 ? CupertinoIcons.repeat_1 : CupertinoIcons.repeat, m.toggleRepeat, p,
                      active: m.repeat != 0, size: 26),
                ],
              ),
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(14),
            child: landscape
                ? Row(children: [
                    Artwork(size: artSize, radius: 18),
                    const SizedBox(width: 28),
                    Expanded(child: info),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Artwork(size: artSize, radius: 18),
                    const SizedBox(height: 20),
                    info,
                  ]),
          );
        });
      },
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, Palette p, {bool active = false, double size = 32}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: active ? BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(10)) : null,
        child: Icon(icon, size: size, color: active ? CP.red : p.text),
      ),
    );
  }
}
