import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/location_service.dart';
import '../../core/nav_controller.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Sıradaki dönüş kartı (yeşil CarPlay manevra kartı).
class ManeuverCard extends StatelessWidget {
  final bool compact;
  const ManeuverCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: NavController.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final nav = NavController.I;
    final s = nav.nextStep;
    if (s == null) return const SizedBox.shrink();
    final after = nav.stepAfter;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 320 : 380),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF1E7A3C),
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Row(
              children: [
                Icon(maneuverIcon(s.type, s.modifier), color: Colors.white, size: compact ? 44 : 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatDistance(nav.distToManeuver),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 26 : 34,
                              fontWeight: FontWeight.w700,
                              height: 1.05)),
                      Text(s.road.isNotEmpty ? s.road : s.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white, fontSize: compact ? 16 : 19, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (after != null && nav.distToManeuver < 1000 && !compact)
            Container(
              color: const Color(0xFF155C2C),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const Text('Sonra', style: TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(width: 8),
                Icon(maneuverIcon(after.type, after.modifier), color: Colors.white, size: 24),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(after.road.isNotEmpty ? after.road : after.instruction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Varış saati / kalan süre / mesafe kartı.
class EtaCard extends StatelessWidget {
  final VoidCallback? onEnd;
  final bool compact;
  const EtaCard({super.key, this.onEnd, this.compact = false});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: NavController.I, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final p = Palette.of(context);
    final nav = NavController.I;
    Widget col(String big, String small) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(big, style: TextStyle(color: p.text, fontSize: compact ? 20 : 24, fontWeight: FontWeight.w700)),
            Text(small, style: TextStyle(color: p.subtext, fontSize: 13)),
          ],
        );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          col(DateFormat.Hm().format(nav.eta), 'varış'),
          SizedBox(width: compact ? 16 : 26),
          Builder(builder: (_) {
            final mins = (nav.remainingSeconds / 60).round();
            return mins < 60
                ? col('$mins', 'dk')
                : col('${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}', 'sa');
          }),
          SizedBox(width: compact ? 16 : 26),
          col(formatDistance(nav.remainingDistance).split(' ').first,
              formatDistance(nav.remainingDistance).split(' ').last),
          if (onEnd != null) ...[
            const SizedBox(width: 18),
            PillButton(text: 'Bitir', color: CP.red, height: 46, onTap: onEnd),
          ],
        ],
      ),
    );
  }
}

/// Hız göstergesi balonu.
class SpeedBubble extends StatelessWidget {
  final double size;
  const SpeedBubble({super.key, this.size = 70});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: LocationService.I,
      builder: (_, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${LocationService.I.speedKmh.round()}',
              style: TextStyle(color: p.text, fontSize: size * 0.36, fontWeight: FontWeight.w700, height: 1)),
          Text('km/sa', style: TextStyle(color: p.subtext, fontSize: size * 0.15)),
        ]),
      ),
    );
  }
}
