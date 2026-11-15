import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/voice_assistant.dart';

/// Sesli asistan katmanı: köşede dönen renkli küre + yazıya dökülen konuşma.
class SiriOverlay extends StatefulWidget {
  const SiriOverlay({super.key});

  @override
  State<SiriOverlay> createState() => _SiriOverlayState();
}

class _SiriOverlayState extends State<SiriOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final va = VoiceAssistant.I;
    return ListenableBuilder(
      listenable: va,
      builder: (context, _) {
        final show = va.visible;
        final text = va.reply.isNotEmpty
            ? va.reply
            : (va.transcript.isNotEmpty
                ? va.transcript
                : (va.state == VoiceState.listening ? 'Dinliyorum…' : ''));
        return IgnorePointer(
          ignoring: !show,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: GestureDetector(
              onTap: va.cancel,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0xEE000000)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (_, _) {
                        final pulse = va.state == VoiceState.listening
                            ? 1 + (va.level.clamp(0, 10) / 40)
                            : (va.state == VoiceState.thinking
                                ? 1 + 0.06 * math.sin(_spin.value * math.pi * 8)
                                : 1.0);
                        return Transform.scale(
                          scale: pulse,
                          child: Transform.rotate(
                            angle: _spin.value * 2 * math.pi,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(colors: [
                                  Color(0xFF5E5CE6),
                                  Color(0xFFBF5AF2),
                                  Color(0xFFFF375F),
                                  Color(0xFFFF9F0A),
                                  Color(0xFF64D2FF),
                                  Color(0xFF5E5CE6),
                                ]),
                                boxShadow: [BoxShadow(color: Color(0x88BF5AF2), blurRadius: 30, spreadRadius: 4)],
                              ),
                              child: Center(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      Colors.white.withValues(alpha: 0.9),
                                      Colors.white.withValues(alpha: 0.0),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: va.reply.isNotEmpty ? Colors.white : Colors.white.withValues(alpha: 0.85),
                            fontSize: 26,
                            fontWeight: va.reply.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
