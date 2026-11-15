import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../../core/calendar_repo.dart';
import '../../core/location_service.dart';
import '../../core/nav_controller.dart';
import '../../core/routing_api.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Takvim: önümüzdeki 7 günün etkinlikleri; konumlu etkinliğe yol tarifi.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    CalendarRepo.I.load(force: true);
  }

  String _dayTitle(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return DateFormat('d MMMM EEEE').format(d);
  }

  Future<void> _navigate(CalEvent e) async {
    final res = await RoutingApi.search(e.location, near: LocationService.I.latLng);
    if (!mounted) return;
    if (res.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${e.location}" bulunamadı')));
      return;
    }
    AppState.I.open(CarApp.maps);
    NavController.I.preview(res.first);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: CalendarRepo.I,
      builder: (context, _) {
        final repo = CalendarRepo.I;
        Widget body;
        if (!repo.available) {
          body = const EmptyState(icon: CupertinoIcons.calendar, title: 'Takvim bu cihazda kullanılamıyor');
        } else if (repo.loading && repo.events.isEmpty) {
          body = const Center(child: CircularProgressIndicator());
        } else if (repo.denied) {
          body = EmptyState(
            icon: CupertinoIcons.calendar_badge_minus,
            title: 'Takvim izni yok',
            message: 'Ayarlar > Araç Modu > Takvimler bölümünden tam erişim verin.',
            action: 'Tekrar Dene',
            onAction: () => repo.load(force: true),
          );
        } else {
          final now = DateTime.now();
          final events = repo.events.where((e) => e.end.isAfter(now) || e.allDay).toList();
          if (events.isEmpty) {
            body = const EmptyState(icon: CupertinoIcons.calendar_today, title: 'Önümüzdeki 7 gün boş');
          } else {
            final rows = <Widget>[];
            String? lastDay;
            for (final e in events) {
              final d = _dayTitle(e.start);
              if (d != lastDay) {
                lastDay = d;
                rows.add(Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
                  child: Text(d.toUpperCase(),
                      style: TextStyle(color: p.subtext, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ));
              }
              rows.add(CarCard(
                padding: EdgeInsets.zero,
                radius: 16,
                child: CarRow(
                  onTap: e.location.isEmpty ? null : () => _navigate(e),
                  leading: Container(width: 5, height: 44, decoration: BoxDecoration(color: Color(e.color | 0xFF000000), borderRadius: BorderRadius.circular(3))),
                  title: e.title,
                  subtitle: [
                    e.allDay ? 'Tüm gün' : '${DateFormat.Hm().format(e.start)} – ${DateFormat.Hm().format(e.end)}',
                    if (e.location.isNotEmpty) e.location,
                  ].join(' · '),
                  trailing: e.location.isEmpty
                      ? null
                      : RoundButton(icon: CupertinoIcons.car_fill, size: 46, color: CP.blue, onTap: () => _navigate(e)),
                ),
              ));
              rows.add(const SizedBox(height: 6));
            }
            body = ListView(padding: const EdgeInsets.only(bottom: 12), children: rows);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            CarHeader(title: 'Takvim', actions: [
              Pressable(
                onTap: () => repo.load(force: true),
                child: Padding(padding: EdgeInsets.all(8), child: Icon(CupertinoIcons.refresh, color: CP.blue, size: 26)),
              ),
            ]),
            Expanded(child: body),
          ]),
        );
      },
    );
  }
}
