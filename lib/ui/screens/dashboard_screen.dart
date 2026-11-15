import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/calendar_repo.dart';
import '../../core/models.dart';
import '../../core/nav_controller.dart';
import '../../core/routing_api.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../widgets/car_map.dart';
import '../widgets/common.dart';
import '../widgets/nav_widgets.dart';
import '../widgets/now_playing_card.dart';

/// CarPlay Dashboard: harita + şu an çalan + öneriler.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final landscape = c.maxWidth >= c.maxHeight;
      final map = _MapPane();
      final side = [
        const Expanded(child: NowPlayingCard()),
        const SizedBox(height: 10, width: 10),
        const Expanded(child: _SuggestionsCard()),
      ];
      return Padding(
        padding: const EdgeInsets.all(10),
        child: landscape
            ? Row(children: [
                Expanded(flex: 3, child: map),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: Column(children: side)),
              ])
            : Column(children: [
                Expanded(flex: 3, child: map),
                const SizedBox(height: 10),
                Expanded(flex: 2, child: Row(children: side)),
              ]),
      );
    });
  }
}

class _MapPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NavController.I,
      builder: (context, _) {
        final nav = NavController.I;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            const Positioned.fill(child: CarMap(showControls: false, interactive: false)),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => AppState.I.open(CarApp.maps),
              ),
            ),
            if (nav.active) const Positioned(left: 10, top: 10, right: 10, child: Align(alignment: Alignment.topLeft, child: ManeuverCard(compact: true))),
            if (nav.active) const Positioned(left: 10, bottom: 10, child: EtaCard(compact: true)),
            if (!nav.active) const Positioned(left: 12, bottom: 12, child: SpeedBubble(size: 64)),
          ]),
        );
      },
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([CalendarRepo.I, NavController.I, AppState.I]),
      builder: (context, _) {
        final st = AppState.I;
        final ev = CalendarRepo.I.nextEvent;
        final items = <Widget>[];

        if (ev != null) {
          items.add(_Suggestion(
            icon: CupertinoIcons.calendar,
            color: CP.red,
            title: ev.title,
            subtitle: '${DateFormat('HH:mm').format(ev.start)}${ev.location.isNotEmpty ? ' · ${ev.location}' : ''}',
            onTap: ev.location.isEmpty
                ? () => st.open(CarApp.calendar)
                : () => _goToAddress(ev.location),
          ));
        }
        if (st.home != null) {
          items.add(_Suggestion(
            icon: CupertinoIcons.house_fill,
            color: CP.blue,
            title: 'Ev',
            subtitle: st.home!.address.isNotEmpty ? st.home!.address : st.home!.name,
            onTap: () => _go(st.home!),
          ));
        }
        if (st.work != null) {
          items.add(_Suggestion(
            icon: CupertinoIcons.briefcase_fill,
            color: CP.orange,
            title: 'İş',
            subtitle: st.work!.address.isNotEmpty ? st.work!.address : st.work!.name,
            onTap: () => _go(st.work!),
          ));
        }
        for (final f in st.favorites.take(2)) {
          items.add(_Suggestion(
            icon: CupertinoIcons.phone_fill,
            color: CP.green,
            title: f.name,
            subtitle: 'Ara',
            onTap: () => st.call(f.name, f.number),
          ));
        }
        if (items.isEmpty) {
          items.add(_Suggestion(
            icon: CupertinoIcons.location_fill,
            color: CP.blue,
            title: 'Nereye?',
            subtitle: 'Ev ve iş adresini Ayarlar\'dan ekleyin',
            onTap: () => st.open(CarApp.maps),
          ));
        }

        return CarCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => Container(height: 0.6, margin: const EdgeInsets.only(left: 62), color: p.divider),
            itemBuilder: (_, i) => items[i],
          ),
        );
      },
    );
  }

  static void _go(Place p) {
    AppState.I.open(CarApp.maps);
    NavController.I.preview(p);
  }

  static Future<void> _goToAddress(String address) async {
    final res = await RoutingApi.search(address, near: LocationService.I.latLng);
    if (res.isNotEmpty) _go(res.first);
  }
}

class _Suggestion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Suggestion({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CarRow(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
      title: title,
      subtitle: subtitle,
    );
  }
}
