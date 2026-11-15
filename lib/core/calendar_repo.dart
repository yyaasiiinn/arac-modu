import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

class CalEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String location;
  final int color;
  const CalEvent(this.title, this.start, this.end, this.allDay, this.location, this.color);
}

/// Cihaz takvimindeki yaklaşan etkinlikler.
class CalendarRepo extends ChangeNotifier {
  CalendarRepo._();
  static final CalendarRepo I = CalendarRepo._();

  final _plugin = DeviceCalendarPlugin();
  List<CalEvent> events = [];
  bool denied = false;
  bool loading = false;
  DateTime? _loadedAt;

  bool get available => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  CalEvent? get nextEvent {
    final now = DateTime.now();
    for (final e in events) {
      if (!e.allDay && e.end.isAfter(now)) return e;
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (!available || loading) return;
    if (!force && _loadedAt != null &&
        DateTime.now().difference(_loadedAt!).inMinutes < 5) {
      return;
    }
    loading = true;
    notifyListeners();
    try {
      var perm = await _plugin.hasPermissions();
      if (perm.data != true) perm = await _plugin.requestPermissions();
      if (perm.data != true) {
        denied = true;
      } else {
        denied = false;
        final cals = await _plugin.retrieveCalendars();
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 7));
        final out = <CalEvent>[];
        for (final c in cals.data ?? <Calendar>[]) {
          if (c.id == null) continue;
          final r = await _plugin.retrieveEvents(
              c.id, RetrieveEventsParams(startDate: start, endDate: end));
          for (final e in r.data ?? <Event>[]) {
            if (e.start == null) continue;
            out.add(CalEvent(
              e.title ?? '(Başlıksız)',
              e.start!.toLocal(),
              (e.end ?? e.start!).toLocal(),
              e.allDay ?? false,
              e.location ?? '',
              c.color ?? 0xFFFF453A,
            ));
          }
        }
        out.sort((a, b) => a.start.compareTo(b.start));
        events = out;
        _loadedAt = DateTime.now();
      }
    } catch (_) {
      denied = true;
    }
    loading = false;
    notifyListeners();
  }
}
