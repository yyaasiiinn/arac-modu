import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';

/// Diva Modu açılırken "Hoş geldin divamız", kapanırken "Keep going now" yazısı.
class DivaAnnouncement extends StatefulWidget {
  const DivaAnnouncement({super.key});

  @override
  State<DivaAnnouncement> createState() => _DivaAnnouncementState();
}

class _DivaAnnouncementState extends State<DivaAnnouncement> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  String? _text;
  bool _welcome = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    AppState.I.announcement.addListener(_onAnnounce);
  }

  @override
  void dispose() {
    AppState.I.announcement.removeListener(_onAnnounce);
    _hide?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _onAnnounce() {
    final t = AppState.I.announcement.value;
    if (t == null) return;
    AppState.I.announcement.value = null;
    setState(() {
      _text = t;
      _welcome = AppState.I.divaMode;
    });
    _anim.forward(from: 0);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _text = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_text == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _text = null),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          // 0-0.15 içeri gir, 0.8-1 kaybol
          final opacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          final scale = 0.7 + 0.3 * Curves.elasticOut.transform((t / 0.5).clamp(0.0, 1.0));
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _welcome
                      ? const [Color(0xFFFFB3DA), Color(0xFFFF1493), Color(0xFFC2185B)]
                      : const [Color(0xFF1B1B1F), Color(0xFF2C2C34), Color(0xFF0B0B0F)],
                ),
              ),
              child: Stack(children: [
                if (_welcome) ..._sparkles(t, context),
                Center(
                  child: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_welcome ? '💖' : '🚗', style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 12),
                        Text(
                          _text!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            fontStyle: _welcome ? FontStyle.italic : FontStyle.normal,
                            letterSpacing: _welcome ? 0.5 : 2,
                            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 18)],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Ekranda süzülen kalpler ve pırıltılar.
  List<Widget> _sparkles(double t, BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rnd = math.Random(7);
    const items = ['✨', '💖', '💕', '🌸', '✨', '💗'];
    return List.generate(22, (i) {
      final x = rnd.nextDouble() * size.width;
      final startY = size.height + rnd.nextDouble() * 120;
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      final y = startY - t * speed * (size.height + 200);
      final wobble = math.sin(t * 8 + i) * 14;
      return Positioned(
        left: x + wobble,
        top: y,
        child: Text(items[i % items.length], style: TextStyle(fontSize: 20 + rnd.nextDouble() * 22)),
      );
    });
  }
}
