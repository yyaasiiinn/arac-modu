import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/in_app_player.dart';
import '../../core/music_service.dart';
import '../../core/now_playing.dart';
import '../../core/theme.dart';
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
  late int _tab = widget.startOnNowPlaying || NowPlaying.hasItem ? 0 : 1;
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
          items: const ['Şu An Çalan', 'Apple Music', 'Radyo', 'Podcast'],
          selected: _tab,
          onChanged: (i) {
            if (i == 2) {
              AppState.I.open(CarApp.radio);
            } else if (i == 3) {
              AppState.I.open(CarApp.podcasts);
            } else {
              setState(() => _tab = i);
            }
          },
        ),
        Expanded(
          child: _tab == 0 ? const NowPlayingView() : _library(),
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
        message: 'Apple Music kitaplığınız iPhone uygulamasında görünür. Radyo ve Podcast sekmeleri her yerde çalışır.',
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

}

/// Büyük "Şu An Çalan" ekranı (Apple Music, radyo veya podcast).
class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  String _t(double s) {
    if (s.isNaN || s < 0) s = 0;
    final m = s ~/ 60;
    final sec = (s % 60).floor();
    if (m >= 60) return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: NowPlaying.listenable,
      builder: (context, _) {
        final src = NowPlaying.source;
        final inApp = src == NowSource.inApp;
        final isWeb = src == NowSource.web;
        final m = MusicService.I;
        final ip = InAppPlayer.I;
        if (!NowPlaying.hasItem && !m.supported) {
          return EmptyState(
            icon: CupertinoIcons.music_note_2,
            title: 'Çalan bir şey yok',
            message: 'Radyo veya podcast açabilir, iPhone\'da Apple Music kitaplığınızı çalabilirsiniz.',
            action: 'Radyoyu Aç',
            onAction: () => AppState.I.open(CarApp.radio),
          );
        }

        final double pos = isWeb ? 0 : (inApp ? ip.position.inMilliseconds / 1000 : m.position);
        final double dur = isWeb ? 0 : (inApp ? ip.duration.inMilliseconds / 1000 : m.duration);
        final live = NowPlaying.isLive;

        return LayoutBuilder(builder: (context, c) {
          final landscape = c.maxWidth > c.maxHeight;
          final artSize = landscape ? (c.maxHeight - 40).clamp(100.0, 300.0) : (c.maxWidth * 0.6).clamp(100.0, 300.0);

          final controls = <Widget>[
            if (!inApp && !isWeb) _btn(CupertinoIcons.shuffle, m.toggleShuffle, p, active: m.shuffle, size: 26),
            if (inApp && ip.kind == PlayerKind.radio)
              _btn(ip.isFavoriteStation(ip.station!) ? CupertinoIcons.star_fill : CupertinoIcons.star,
                  () => ip.toggleFavoriteStation(ip.station!), p, size: 28, color: CP.yellow),
            _btn(inApp && !live ? CupertinoIcons.gobackward_15 : CupertinoIcons.backward_fill, NowPlaying.previous, p, size: 40),
            _btn(NowPlaying.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, NowPlaying.playPause, p, size: 54),
            _btn(inApp && !live ? CupertinoIcons.goforward_30 : CupertinoIcons.forward_fill, NowPlaying.next, p, size: 40),
            if (!inApp && !isWeb)
              _btn(m.repeat == 2 ? CupertinoIcons.repeat_1 : CupertinoIcons.repeat, m.toggleRepeat, p,
                  active: m.repeat != 0, size: 26),
          ];

          final info = Column(
            crossAxisAlignment: landscape ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(NowPlaying.hasItem ? NowPlaying.title : 'Çalan bir şey yok',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: landscape ? TextAlign.start : TextAlign.center,
                  style: TextStyle(color: p.text, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (live)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: CP.red, borderRadius: BorderRadius.circular(6)),
                    child: const Text('CANLI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                Flexible(
                  child: Text(
                    isWeb
                        ? NowPlaying.subtitle
                        : inApp
                        ? (ip.error ?? (ip.loading ? 'Bağlanıyor…' : ip.subtitle))
                        : (m.hasItem ? [m.artist, m.album].where((e) => e.isNotEmpty).join(' — ') : 'Kitaplıktan bir liste seçin'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: inApp && ip.error != null ? CP.red : p.subtext, fontSize: 19),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              if (!live && dur > 0) ...[
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: p.text,
                    inactiveTrackColor: p.card3,
                  ),
                  child: Slider(
                    value: pos.clamp(0, dur),
                    max: dur,
                    onChanged: (v) => inApp ? ip.seek(Duration(milliseconds: (v * 1000).round())) : m.seek(v),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text(_t(pos), style: TextStyle(color: p.subtext, fontSize: 14)),
                  const Spacer(),
                  Text('-${_t(dur - pos)}', style: TextStyle(color: p.subtext, fontSize: 14)),
                ]),
              ],
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: controls),
              if (isWeb && NowPlaying.web != null) ...[
                const SizedBox(height: 12),
                PillButton(
                  text: '${NowPlaying.web!.name} oynatıcısını aç',
                  height: 44,
                  color: p.card2,
                  textColor: p.text,
                  onTap: () => AppState.I.open(NowPlaying.web!.app),
                ),
              ],
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

  Widget _btn(IconData icon, VoidCallback onTap, Palette p, {bool active = false, double size = 32, Color? color}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: active ? BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(10)) : null,
        child: Icon(icon, size: size, color: color ?? (active ? CP.red : p.text)),
      ),
    );
  }
}
