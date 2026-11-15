import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'models.dart';
import 'nav_controller.dart';
import 'theme.dart';

/// Rotayı başlatabilecek navigasyon uygulamaları.
class NavAppInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String? probe; // yüklü mü kontrolü için şema
  final String Function(Place p)? url; // null = uygulamanın kendi navigasyonu
  const NavAppInfo(this.id, this.name, this.icon, this.color, this.probe, this.url);

  bool get internal => url == null;
}

final navApps = <NavAppInfo>[
  NavAppInfo('internal', 'CarPlay', CupertinoIcons.location_north_fill, CP.blue, null, null),
  NavAppInfo('apple', 'Apple Haritalar', CupertinoIcons.map_fill, CP.green, 'maps://',
      (p) => 'maps://?daddr=${p.lat},${p.lon}&dirflg=d'),
  NavAppInfo('google', 'Google Maps', CupertinoIcons.map_pin_ellipse, const Color(0xFF34A853), 'comgooglemaps://',
      (p) => 'comgooglemaps://?daddr=${p.lat},${p.lon}&directionsmode=driving'),
  NavAppInfo('waze', 'Waze', CupertinoIcons.car_fill, const Color(0xFF33CCFF), 'waze://',
      (p) => 'waze://?ll=${p.lat},${p.lon}&navigate=yes'),
  NavAppInfo('yandex', 'Yandex Navigasyon', CupertinoIcons.arrow_up_right_circle_fill, const Color(0xFFFC3F1D),
      'yandexnavi://', (p) => 'yandexnavi://build_route_on_map?lat_to=${p.lat}&lon_to=${p.lon}'),
];

NavAppInfo navAppById(String id) => navApps.firstWhere((e) => e.id == id, orElse: () => navApps.first);

/// Telefonda yüklü olan navigasyon uygulamaları.
Future<List<NavAppInfo>> installedNavApps() async {
  final out = <NavAppInfo>[];
  for (final a in navApps) {
    if (a.probe == null) {
      out.add(a);
      continue;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      if (a.id == 'apple') continue;
      out.add(a);
      continue;
    }
    try {
      if (await canLaunchUrl(Uri.parse(a.probe!))) out.add(a);
    } catch (_) {}
  }
  return out;
}

/// Hedefe gitmeyi Ayarlar'daki tercihe göre başlatır:
/// CarPlay navigasyonu, seçilen uygulama ya da her seferinde sorarak.
Future<void> startNavigation(Place dest, {String? appId}) async {
  final id = appId ?? AppState.I.navApp;
  if (id == 'ask') {
    final ctx = AppState.navigatorKey.currentContext;
    if (ctx == null) return startNavigation(dest, appId: 'internal');
    final chosen = await pickNavApp(ctx, title: '${dest.name} için navigasyon');
    if (chosen == null) return;
    return startNavigation(dest, appId: chosen.id);
  }
  final app = navAppById(id);
  if (app.internal) {
    final nav = NavController.I;
    if (nav.mode == NavMode.preview && nav.destination == dest) {
      nav.start();
    } else {
      await nav.navigateTo(dest);
    }
    return;
  }
  AppState.I.addRecentPlace(dest);
  NavController.I.stop();
  final ok = await AppState.I.launchUrlString(app.url!(dest));
  if (!ok) {
    AppState.I.toast('${app.name} açılamadı, CarPlay ile devam ediliyor');
    await NavController.I.navigateTo(dest);
  }
}

/// Yüklü navigasyon uygulamalarından birini seçtirir.
Future<NavAppInfo?> pickNavApp(BuildContext context, {String title = 'Navigasyon uygulaması', bool includeAsk = false}) async {
  final apps = await installedNavApps();
  if (!context.mounted) return null;
  final p = Palette.of(context);
  return showModalBottomSheet<NavAppInfo>(
    context: context,
    backgroundColor: p.card,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final a in apps) _NavChoice(a, () => Navigator.pop(ctx, a)),
              if (includeAsk)
                _NavChoice(
                  const NavAppInfo('ask', 'Her Seferinde Sor', CupertinoIcons.question_circle_fill, CP.gray, null, null),
                  () => Navigator.pop(ctx, const NavAppInfo('ask', 'Her Seferinde Sor', CupertinoIcons.question, CP.gray, null, null)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}

class _NavChoice extends StatelessWidget {
  final NavAppInfo app;
  final VoidCallback onTap;
  const _NavChoice(this.app, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final selected = AppState.I.navApp == app.id;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: app.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? p.text : Colors.transparent, width: 3),
            ),
            child: Icon(app.icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 6),
          Text(app.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
