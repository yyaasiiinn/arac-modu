import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/music_service.dart';
import '../../core/theme.dart';
import '../../core/voice_assistant.dart';
import 'app_icon.dart';
import 'common.dart';

/// Saat, sinyal ve pil bilgisi.
class StatusInfo extends StatefulWidget {
  final bool vertical;
  const StatusInfo({super.key, this.vertical = true});

  @override
  State<StatusInfo> createState() => _StatusInfoState();
}

class _StatusInfoState extends State<StatusInfo> {
  late Timer _t;
  DateTime _now = DateTime.now();
  int? _battery;
  bool _charging = false;
  List<ConnectivityResult> _conn = const [];
  StreamSubscription? _bSub, _cSub;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _now = DateTime.now());
      _readBattery();
    });
    _readBattery();
    try {
      _bSub = Battery().onBatteryStateChanged.listen((s) {
        setState(() => _charging = s == BatteryState.charging || s == BatteryState.full);
      });
      Connectivity().checkConnectivity().then((c) => mounted ? setState(() => _conn = c) : null);
      _cSub = Connectivity().onConnectivityChanged.listen((c) => setState(() => _conn = c));
    } catch (_) {}
  }

  Future<void> _readBattery() async {
    try {
      final b = await Battery().batteryLevel;
      if (mounted) setState(() => _battery = b);
    } catch (_) {}
  }

  @override
  void dispose() {
    _t.cancel();
    _bSub?.cancel();
    _cSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final time = Text(DateFormat.Hm().format(_now),
        style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3));

    IconData netIcon;
    String netLabel = '';
    if (_conn.contains(ConnectivityResult.wifi)) {
      netIcon = CupertinoIcons.wifi;
    } else if (_conn.contains(ConnectivityResult.mobile)) {
      netIcon = CupertinoIcons.antenna_radiowaves_left_right;
      netLabel = '4G';
    } else if (_conn.isEmpty) {
      netIcon = CupertinoIcons.wifi;
    } else {
      netIcon = CupertinoIcons.wifi_slash;
    }
    final b = _battery;
    final battIcon = _charging
        ? CupertinoIcons.battery_charging
        : (b == null || b > 70
            ? CupertinoIcons.battery_full
            : (b > 30 ? CupertinoIcons.battery_75_percent : CupertinoIcons.battery_25_percent));

    final icons = Row(mainAxisSize: MainAxisSize.min, children: [
      if (netLabel.isNotEmpty)
        Text(netLabel, style: TextStyle(color: p.text, fontSize: 11, fontWeight: FontWeight.w700)),
      Icon(netIcon, size: 15, color: p.text),
      const SizedBox(width: 4),
      Icon(battIcon, size: 20, color: (b != null && b <= 20 && !_charging) ? CP.red : p.text),
    ]);

    if (widget.vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [time, const SizedBox(height: 4), icons]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [time, const SizedBox(width: 10), icons]);
  }
}

/// CarPlay'deki sol kenar çubuğu (dikey ekranda alt çubuk).
class CarSidebar extends StatelessWidget {
  final bool vertical;
  const CarSidebar({super.key, this.vertical = true});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([AppState.I, MusicService.I]),
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final p = Palette.of(context);
    final st = AppState.I;
    final va = VoiceAssistant.I;

    final recent = st.recentApps
        .map((a) => _RecentIcon(app: a, selected: st.current == a || (a == CarApp.music && st.current == CarApp.nowPlaying)))
        .toList();

    final homeBtn = Pressable(
      onTap: st.homeButton,
      onLongPress: va.activate,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(16)),
        child: Icon(
          st.current == CarApp.home ? CupertinoIcons.rectangle_split_3x1_fill : CupertinoIcons.square_grid_2x2_fill,
          color: p.text,
          size: 28,
        ),
      ),
    );

    final siriBtn = Pressable(
      onTap: va.activate,
      child: Container(
        width: 46,
        height: 46,
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
        ),
        child: const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 22),
      ),
    );

    if (vertical) {
      return Container(
        width: 86,
        color: p.sidebar,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            const StatusInfo(),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                final n = ((c.maxHeight) / 66).floor().clamp(0, 3);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (final w in recent.take(n))
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: w),
                  ],
                );
              }),
            ),
            siriBtn,
            const SizedBox(height: 12),
            homeBtn,
          ],
        ),
      );
    }
    return Container(
      height: 78,
      color: p.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (context, c) => Row(
        children: [
          homeBtn,
          const SizedBox(width: 12),
          ...recent
              .take(((c.maxWidth - 58 - 12 - 46 - 12 - 110) / 69).floor().clamp(0, 3))
              .map((w) => Padding(padding: const EdgeInsets.only(right: 10), child: w)),
          const Spacer(),
          const StatusInfo(vertical: false),
          const SizedBox(width: 12),
          siriBtn,
        ],
      )),
    );
  }
}

class _RecentIcon extends StatelessWidget {
  final CarApp app;
  final bool selected;
  const _RecentIcon({required this.app, required this.selected});

  @override
  Widget build(BuildContext context) {
    final info = appInfos[app]!;
    final playing = app == CarApp.music && MusicService.I.isPlaying;
    return Pressable(
      onTap: () => AppState.I.open(app),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Palette.of(context).text.withValues(alpha: 0.9) : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: AppGlyph(info, size: 48, playing: playing),
      ),
    );
  }
}
