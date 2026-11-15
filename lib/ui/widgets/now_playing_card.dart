import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/music_service.dart';
import '../../core/theme.dart';
import 'common.dart';

class Artwork extends StatelessWidget {
  final double size;
  final double radius;
  const Artwork({super.key, required this.size, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final art = MusicService.I.artwork;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: art == null
            ? const LinearGradient(colors: [Color(0xFFFF5C77), Color(0xFFFA233B)])
            : null,
        image: art != null ? DecorationImage(image: MemoryImage(art), fit: BoxFit.cover) : null,
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: art == null ? Icon(CupertinoIcons.music_note_2, color: Colors.white, size: size * 0.45) : null,
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
      listenable: MusicService.I,
      builder: (context, _) {
        final m = MusicService.I;
        return CarCard(
          onTap: () => AppState.I.open(CarApp.nowPlaying),
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
                        Text(m.hasItem ? m.title : 'Çalan bir şey yok',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(m.hasItem ? m.artist : (m.supported ? 'Müzik' : 'Spotify veya YT Music\'i açın'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.subtext, fontSize: 15)),
                      ],
                    ),
                  ),
                ]),
                if (m.hasItem && m.duration > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (m.position / m.duration).clamp(0, 1),
                        minHeight: 3,
                        backgroundColor: p.card3,
                        color: p.text,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Ctl(CupertinoIcons.backward_fill, m.previous),
                    _Ctl(m.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, m.playPause, big: true),
                    _Ctl(CupertinoIcons.forward_fill, m.next),
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
