import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/location_service.dart';
import '../../core/nav_controller.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Konumu takip eden, rotayı çizen harita.
class CarMap extends StatefulWidget {
  final bool showControls;
  final bool interactive;
  final void Function(LatLng)? onLongPress;
  final EdgeInsets controlsPadding;
  final EdgeInsets fitPadding;
  const CarMap({
    super.key,
    this.showControls = true,
    this.interactive = true,
    this.onLongPress,
    this.controlsPadding = const EdgeInsets.all(12),
    this.fitPadding = const EdgeInsets.fromLTRB(40, 50, 40, 50),
  });

  @override
  State<CarMap> createState() => _CarMapState();
}

class _CarMapState extends State<CarMap> {
  final _map = MapController();
  bool _ready = false;
  bool _following = true;
  double _zoom = 15;
  NavMode _lastMode = NavMode.idle;
  LatLng? _pin;

  final _loc = LocationService.I;
  final _nav = NavController.I;

  @override
  void initState() {
    super.initState();
    _loc.addListener(_onUpdate);
    _nav.addListener(_onNav);
    _lastMode = _nav.mode;
  }

  @override
  void dispose() {
    _loc.removeListener(_onUpdate);
    _nav.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() {
    if (!mounted) return;
    if (_nav.mode != _lastMode) {
      _lastMode = _nav.mode;
      if (_nav.mode == NavMode.preview) {
        _fitRoute();
      } else if (_nav.mode == NavMode.navigating) {
        _following = true;
        _zoom = 17;
        _pin = null;
        _onUpdate();
      } else if (_nav.mode == NavMode.idle) {
        _following = true;
        _zoom = 15;
        _onUpdate();
      }
    }
    setState(() {});
  }

  void _fitRoute() {
    final r = _nav.route;
    if (!_ready || r == null || r.points.length < 2) return;
    _following = false;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(r.points),
      padding: widget.fitPadding,
    ));
  }

  void _onUpdate() {
    if (!mounted) return;
    final p = _loc.latLng;
    if (_ready && _following && p != null) {
      final rot = (_nav.active && AppState.I.headingUp) ? -_loc.heading : 0.0;
      _map.moveAndRotate(p, _nav.active ? math.max(_zoom, 16) : _zoom, rot);
    }
    setState(() {});
  }

  void _recenter() {
    setState(() => _following = true);
    if (_nav.mode == NavMode.preview) {
      _fitRoute();
    } else {
      _onUpdate();
    }
  }

  void _zoomBy(double d) {
    if (!_ready) return;
    _zoom = (_map.camera.zoom + d).clamp(3, 19);
    _map.move(_map.camera.center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pos = _loc.latLng;
    final route = _nav.route;
    final dest = _nav.destination;


    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: pos ?? const LatLng(41.0082, 28.9784),
            initialZoom: pos == null ? 11 : _zoom,
            backgroundColor: p.dark ? const Color(0xFF1B1B1D) : const Color(0xFFEDEAE2),
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
            ),
            onMapReady: () {
              _ready = true;
              if (_nav.mode == NavMode.preview) {
                _fitRoute();
              } else {
                _onUpdate();
              }
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _following) setState(() => _following = false);
              if (hasGesture) _zoom = camera.zoom;
            },
            onLongPress: widget.onLongPress == null
                ? null
                : (_, latlng) {
                    setState(() => _pin = latlng);
                    widget.onLongPress!(latlng);
                  },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yyaasiiinn.car_mode',
              maxNativeZoom: 19,
              maxZoom: 20,
              // Gece modunda haritayı koyulaştır (CarPlay gece haritası gibi).
              tileBuilder: p.dark ? darkModeTileBuilder : null,
            ),
            if (route != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: route.points,
                  strokeWidth: 9,
                  color: _nav.active ? CP.blue : CP.blue.withValues(alpha: 0.85),
                  borderStrokeWidth: 3,
                  borderColor: const Color(0xFF0A4FA8),
                ),
              ]),
            MarkerLayer(markers: [
              if (dest != null)
                Marker(
                  point: dest.latLng,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  rotate: true,
                  child: const Icon(CupertinoIcons.map_pin, color: CP.red, size: 44),
                ),
              if (_pin != null && dest == null)
                Marker(
                  point: _pin!,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  rotate: true,
                  child: const Icon(CupertinoIcons.map_pin, color: CP.orange, size: 40),
                ),
              if (pos != null)
                Marker(
                  point: pos,
                  width: 46,
                  height: 46,
                  child: _UserPuck(heading: _loc.heading, navigating: _nav.active),
                ),
            ]),
            SimpleAttributionWidget(
              source: Text('OpenStreetMap', style: TextStyle(fontSize: 10, color: p.subtext)),
              alignment: Alignment.bottomRight,
              backgroundColor: p.card.withValues(alpha: 0.6),
            ),
          ],
        ),
        if (widget.showControls)
          Positioned(
            right: widget.controlsPadding.right,
            bottom: widget.controlsPadding.bottom + 22,
            child: Column(
              children: [
                _MapBtn(icon: CupertinoIcons.plus, onTap: () => _zoomBy(1)),
                const SizedBox(height: 1),
                _MapBtn(icon: CupertinoIcons.minus, onTap: () => _zoomBy(-1)),
                const SizedBox(height: 10),
                _MapBtn(
                  icon: _following ? CupertinoIcons.location_fill : CupertinoIcons.location,
                  color: CP.blue,
                  onTap: _recenter,
                ),
                if (_nav.active) ...[
                  const SizedBox(height: 10),
                  _MapBtn(
                    icon: AppState.I.headingUp ? CupertinoIcons.compass_fill : CupertinoIcons.compass,
                    onTap: () {
                      AppState.I.update(() => AppState.I.headingUp = !AppState.I.headingUp);
                      _onUpdate();
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _MapBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)],
        ),
        child: Icon(icon, color: color ?? p.text, size: 24),
      ),
    );
  }
}

class _UserPuck extends StatelessWidget {
  final double heading;
  final bool navigating;
  const _UserPuck({required this.heading, required this.navigating});

  @override
  Widget build(BuildContext context) {
    if (navigating) {
      return Transform.rotate(
        angle: heading * math.pi / 180,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 6)],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(color: CP.blue, shape: BoxShape.circle),
            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 26),
          ),
        ),
      );
    }
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: CP.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
        ),
      ),
    );
  }
}
