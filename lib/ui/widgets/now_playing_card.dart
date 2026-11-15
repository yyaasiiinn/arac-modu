import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/in_app_player.dart';
import '../../core/music_service.dart';
import '../../core/now_playing.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Kapak görseli: Apple Music kapağı, radyo logosu veya podcast görseli.
class Artwork extends StatelessWidget {
  final double size;
  final double radius;
  const Artwork({super.key, required this.size, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final inApp = NowPlaying.inApp;
    final ip = InAppPlayer.I;
    final bytes = inApp ? null : MusicService.I.artwork;
    final url = inApp ? ip.artUrl : '';
    final colors = inApp && ip.kind == PlayerKind.radio
        ? const [Color(0xFFFF8A5B), Color(0xFFE8452C)]
        : inApp
            ? const [Color(0xFFD56DFB), Color(0xFF872EC4)]
            : const [Color(0xFFFF5C77), Color(0xFFFA233B)];
    final icon = inApp && ip.kind == PlayerKind.radio
        ? CupertinoIcons.radiowaves_right
        : inApp
            ? CupertinoIcons.dot_radiowaves_left_right
            : CupertinoIcons.music_note_2;

    final placeholder = Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Icon(icon, color: Colors.white, size: size * 0.45),
    );

    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes, fit: BoxFit.cover);
    } else if (url.isNotEmpty) {
      child = Container(
        color: Colors.white,
        child: Image.network(
          url,
          fit: inApp && ip.kind == PlayerKind.radio ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    } else {
      child = placeholder;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Dashboard'daki küçük "Şu An Çalan" kartı.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: NowPlaying.listenable,
      builder: (context, _) {
        final has = NowPlaying.hasItem;
        return CarCard(
          onTap: () => AppState.I.open(has ? CarApp.nowPlaying : CarApp.radio),
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, c) {
            final art = (c.maxHeight - 64).clamp(40.0, 90.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Artwork(size: art),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(has ? NowPlaying.title : 'Çalan bir şey yok',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(has ? NowPlaying.subtitle : 'Radyo veya podcast açın',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: NowPlaying.isLive ? CP.red : p.subtext, fontSize: 15)),
                      ],
                    ),
                  ),
                ]),
                if (has && !NowPlaying.isLive && NowPlaying.progress > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: NowPlaying.progress,
                        minHeight: 3,
                        backgroundColor: p.card3,
                        color: p.text,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Ctl(CupertinoIcons.backward_fill, NowPlaying.previous),
                    _Ctl(NowPlaying.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        has ? NowPlaying.playPause : () => AppState.I.open(CarApp.radio),
                        big: true),
                    _Ctl(CupertinoIcons.forward_fill, NowPlaying.next),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

class _Ctl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool big;
  const _Ctl(this.icon, this.onTap, {this.big = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Icon(icon, size: big ? 36 : 28, color: Palette.of(context).text),
      ),
    );
  }
}

/// Ekranın altında duran küçük oynatıcı çubuğu (Radyo/Podcast ekranları için).
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: InAppPlayer.I,
      builder: (context, _) {
        final ip = InAppPlayer.I;
        if (!ip.active) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: CarCard(
            onTap: () => AppState.I.open(CarApp.nowPlaying),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: p.card2,
            radius: 18,
            child: Row(children: [
              const Artwork(size: 46, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(ip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
                  Text(ip.error ?? (ip.loading ? 'Bağlanıyor…' : ip.subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ip.error != null ? CP.red : p.subtext, fontSize: 14)),
                ]),
              ),
              if (ip.loading)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              else
                _Ctl(ip.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, ip.playPause, big: true),
              _Ctl(CupertinoIcons.forward_fill, ip.next),
            ]),
          ),
        );
      },
    );
  }
}
