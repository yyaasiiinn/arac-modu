import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/routing_api.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import 'common.dart';

/// "Nereye?" arama paneli: sesli arama, kategoriler, son yerler.
class PlaceSearchPanel extends StatefulWidget {
  final ValueChanged<Place> onSelect;
  final VoidCallback? onClose;
  final bool shortcuts;
  final String title;
  const PlaceSearchPanel({super.key, required this.onSelect, this.onClose, this.shortcuts = true, this.title = 'Nereye?'});

  @override
  State<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends State<PlaceSearchPanel> {
  final _ctl = TextEditingController();
  List<Place> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  static const _categories = [
    ('Akaryakıt', CupertinoIcons.drop_fill, CP.blue, 'akaryakıt istasyonu'),
    ('Otopark', CupertinoIcons.car_detailed, CP.indigo, 'otopark'),
    ('Yemek', Icons.restaurant_rounded, CP.orange, 'restoran'),
    ('Kahve', Icons.local_cafe_rounded, Color(0xFFA2845E), 'kafe'),
    ('Market', CupertinoIcons.bag_fill, CP.yellow, 'market'),
    ('Eczane', CupertinoIcons.bandage_fill, CP.red, 'eczane'),
    ('Şarj', CupertinoIcons.bolt_fill, CP.green, 'şarj istasyonu'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _search(String q, {bool nearby = false}) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RoutingApi.search(q, near: LocationService.I.latLng, nearbyOnly: nearby);
      if (!mounted) return;
      setState(() {
        _results = r;
        _error = r.isEmpty ? 'Sonuç bulunamadı' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Arama yapılamadı (internet?)');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _dictate() {
    VoiceAssistant.I.dictate((text) {
      _ctl.text = text;
      _search(text);
    });
  }

  String _distance(Place p) {
    final me = LocationService.I.latLng;
    if (me == null) return '';
    return formatDistanceShort(const Distance()(me, p.latLng));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final st = AppState.I;
    final showShortcuts = widget.shortcuts && _ctl.text.isEmpty && _results.isEmpty;

    final rows = <Widget>[];
    if (showShortcuts) {
      if (st.home != null) {
        rows.add(_placeRow(st.home!.copyWith(name: 'Ev'), CupertinoIcons.house_fill, CP.blue));
      }
      if (st.work != null) {
        rows.add(_placeRow(st.work!.copyWith(name: 'İş'), CupertinoIcons.briefcase_fill, CP.orange));
      }
      for (final r in st.recentPlaces) {
        rows.add(_placeRow(r, CupertinoIcons.clock_fill, CP.gray));
      }
    } else {
      for (final r in _results) {
        rows.add(_placeRow(r, CupertinoIcons.map_pin_ellipse, CP.red));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(CupertinoIcons.search, color: p.subtext),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctl,
                        style: TextStyle(color: p.text, fontSize: 19),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: widget.title,
                          hintStyle: TextStyle(color: p.subtext, fontSize: 19),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() {});
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 700), () => _search(v));
                        },
                        onSubmitted: _search,
                      ),
                    ),
                    if (_ctl.text.isNotEmpty)
                      Pressable(
                        onTap: () => setState(() {
                          _ctl.clear();
                          _results = [];
                          _error = null;
                        }),
                        child: Icon(CupertinoIcons.xmark_circle_fill, color: p.subtext),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              RoundButton(icon: CupertinoIcons.mic_fill, size: 50, onTap: _dictate),
              if (widget.onClose != null) ...[
                const SizedBox(width: 4),
                Pressable(
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Vazgeç', style: TextStyle(color: CP.blue, fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ]),
          ),
          if (showShortcuts)
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final c in _categories)
                    Pressable(
                      onTap: () {
                        _ctl.text = c.$1;
                        _search(c.$4, nearby: true);
                      },
                      child: SizedBox(
                        width: 78,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: c.$3, shape: BoxShape.circle),
                            child: Icon(c.$2, color: Colors.white, size: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(c.$1, style: TextStyle(color: p.text, fontSize: 13)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: p.subtext, fontSize: 16)),
            ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const CarDivider(indent: 66),
              itemBuilder: (_, i) => rows[i],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeRow(Place place, IconData icon, Color color) {
    final d = _distance(place);
    return CarRow(
      onTap: () => widget.onSelect(place),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: place.name,
      subtitle: [if (d.isNotEmpty) d, if (place.address.isNotEmpty) place.address].join(' · '),
    );
  }
}

String formatDistanceShort(double m) =>
    m >= 1000 ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1).replaceAll('.', ',')} km' : '${m.round()} m';
