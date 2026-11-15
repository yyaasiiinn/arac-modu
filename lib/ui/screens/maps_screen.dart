import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/nav_controller.dart';
import '../../core/routing_api.dart';
import '../../core/theme.dart';
import '../widgets/car_map.dart';
import '../widgets/common.dart';
import '../widgets/nav_widgets.dart';
import '../widgets/place_search.dart';

/// Haritalar: arama, rota önizleme, adım adım navigasyon.
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  bool _searching = false;
  bool _showSteps = false;
  Place? _pinned;

  Future<void> _select(Place p) async {
    setState(() {
      _searching = false;
      _pinned = null;
    });
    await NavController.I.preview(p);
  }

  Future<void> _onLongPress(LatLng ll) async {
    if (NavController.I.mode != NavMode.idle) return;
    final p = await RoutingApi.reverse(ll);
    if (mounted) setState(() => _pinned = p);
  }

  Future<void> _openExternal(String which) async {
    final d = NavController.I.destination;
    if (d == null) return;
    final ll = '${d.lat},${d.lon}';
    final urls = {
      'apple': ['maps://?daddr=$ll&dirflg=d', 'https://maps.apple.com/?daddr=$ll&dirflg=d'],
      'google': ['comgooglemaps://?daddr=$ll&directionsmode=driving', 'https://www.google.com/maps/dir/?api=1&destination=$ll'],
      'waze': ['waze://?ll=$ll&navigate=yes', 'https://waze.com/ul?ll=$ll&navigate=yes'],
    }[which]!;
    for (final u in urls) {
      try {
        if (await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([NavController.I, LocationService.I]),
      builder: (context, _) {
        final nav = NavController.I;
        return LayoutBuilder(builder: (context, c) {
          final landscape = c.maxWidth >= c.maxHeight;
          final panelW = landscape ? (c.maxWidth * 0.46).clamp(320.0, 460.0) : c.maxWidth - 20;
          return Stack(children: [
            Positioned.fill(
              child: CarMap(
                onLongPress: _onLongPress,
                fitPadding: landscape
                    ? EdgeInsets.fromLTRB(panelW + 50, 50, 90, 40)
                    : const EdgeInsets.fromLTRB(40, 60, 40, 330),
                controlsPadding: EdgeInsets.only(right: 12, bottom: nav.mode == NavMode.idle ? 12 : (landscape ? 12 : 170)),
              ),
            ),

            // --- Boşta: arama düğmesi ---
            if (nav.mode == NavMode.idle && !_searching)
              Positioned(
                left: 10,
                top: 10,
                child: Row(children: [
                  CarCard(
                    onTap: () => setState(() => _searching = true),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    color: Palette.of(context).card.withValues(alpha: 0.96),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(CupertinoIcons.search, color: CP.blue, size: 24),
                      const SizedBox(width: 10),
                      Text('Nereye?', style: TextStyle(color: Palette.of(context).text, fontSize: 20, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (AppState.I.home != null) ...[
                    const SizedBox(width: 8),
                    RoundButton(icon: CupertinoIcons.house_fill, size: 54, onTap: () => _select(AppState.I.home!.copyWith(name: 'Ev'))),
                  ],
                  if (AppState.I.work != null) ...[
                    const SizedBox(width: 8),
                    RoundButton(icon: CupertinoIcons.briefcase_fill, color: CP.orange, size: 54, onTap: () => _select(AppState.I.work!.copyWith(name: 'İş'))),
                  ],
                ]),
              ),

            if (nav.mode == NavMode.idle && nav.error != null && !_searching)
              Positioned(
                left: 10,
                top: 80,
                child: CarCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(nav.error!, style: const TextStyle(color: CP.red, fontSize: 16)),
                ),
              ),

            // --- İşaretlenen nokta ---
            if (_pinned != null && nav.mode == NavMode.idle && !_searching)
              Positioned(
                left: 10,
                bottom: 10,
                width: panelW,
                child: _PlaceCard(
                  place: _pinned!,
                  primary: 'Yol Tarifi',
                  onPrimary: () => _select(_pinned!),
                  onClose: () => setState(() => _pinned = null),
                ),
              ),

            // --- Arama paneli ---
            if (_searching)
              Positioned(
                left: 10,
                top: 10,
                bottom: 10,
                width: panelW,
                child: PlaceSearchPanel(onSelect: _select, onClose: () => setState(() => _searching = false)),
              ),

            if (nav.mode == NavMode.loading)
              const Center(child: CircularProgressIndicator()),

            // --- Rota önizleme ---
            if (nav.mode == NavMode.preview && nav.route != null)
              Positioned(
                left: 10,
                bottom: 10,
                width: panelW,
                child: _PreviewCard(onExternal: _openExternal),
              ),

            // --- Navigasyon ---
            if (nav.active) ...[
              Positioned(
                left: 10,
                top: 10,
                child: GestureDetector(
                  onTap: () => setState(() => _showSteps = !_showSteps),
                  child: const ManeuverCard(),
                ),
              ),
              if (_showSteps)
                Positioned(
                  left: 10,
                  top: 150,
                  bottom: 90,
                  width: panelW.clamp(0, 380),
                  child: _StepsList(onClose: () => setState(() => _showSteps = false)),
                ),
              Positioned(
                left: 10,
                bottom: 10,
                child: EtaCard(onEnd: nav.stop),
              ),
              Positioned(
                left: landscape ? null : 10,
                right: landscape ? 76 : null,
                bottom: landscape ? 14 : 100,
                child: const SpeedBubble(),
              ),
            ],
          ]);
        });
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  final String primary;
  final VoidCallback onPrimary;
  final VoidCallback onClose;
  const _PlaceCard({required this.place, required this.primary, required this.onPrimary, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return CarCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text, fontSize: 21, fontWeight: FontWeight.w700)),
          ),
          Pressable(onTap: onClose, child: Icon(CupertinoIcons.xmark_circle_fill, color: p.subtext, size: 30)),
        ]),
        if (place.address.isNotEmpty)
          Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtext, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: PillButton(text: primary, icon: CupertinoIcons.car_fill, onTap: onPrimary)),
          const SizedBox(width: 10),
          RoundButton(
            icon: CupertinoIcons.house_fill,
            color: p.card2,
            iconColor: p.text,
            size: 54,
            onTap: () {
              AppState.I.update(() => AppState.I.home = place.copyWith(name: 'Ev'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ev adresi kaydedildi')));
            },
          ),
          const SizedBox(width: 8),
          RoundButton(
            icon: CupertinoIcons.briefcase_fill,
            color: p.card2,
            iconColor: p.text,
            size: 54,
            onTap: () {
              AppState.I.update(() => AppState.I.work = place.copyWith(name: 'İş'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İş adresi kaydedildi')));
            },
          ),
        ]),
      ]),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final void Function(String) onExternal;
  const _PreviewCard({required this.onExternal});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final nav = NavController.I;
    final r = nav.route!;
    final d = nav.destination!;
    Widget ext(String label, String key) => Pressable(
          onTap: () => onExternal(key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        );
    return CarCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.text, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${formatDuration(r.duration)} · ${formatDistance(r.distance)}',
                  style: const TextStyle(color: CP.green, fontSize: 18, fontWeight: FontWeight.w600)),
              if (d.address.isNotEmpty)
                Text(d.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtext, fontSize: 14)),
            ]),
          ),
          Pressable(onTap: nav.stop, child: Icon(CupertinoIcons.xmark_circle_fill, color: p.subtext, size: 32)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: PillButton(text: 'Git', color: CP.green, onTap: nav.start)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ext('Apple Haritalar', 'apple'),
          ext('Google Maps', 'google'),
          ext('Waze', 'waze'),
        ]),
      ]),
    );
  }
}

class _StepsList extends StatelessWidget {
  final VoidCallback onClose;
  const _StepsList({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final nav = NavController.I;
    final steps = nav.route?.steps ?? [];
    return CarCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: steps.length - nav.stepIndex,
        separatorBuilder: (_, _) => const CarDivider(indent: 62),
        itemBuilder: (_, i) {
          final s = steps[nav.stepIndex + i];
          return CarRow(
            onTap: onClose,
            leading: Icon(maneuverIcon(s.type, s.modifier), color: p.text, size: 32),
            title: s.instruction,
            subtitle: [if (s.road.isNotEmpty) s.road, if (s.distance > 0) formatDistance(s.distance)].join(' · '),
          );
        },
      ),
    );
  }
}
