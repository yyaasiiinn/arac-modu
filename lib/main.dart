import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_state.dart';
import 'core/calendar_repo.dart';
import 'core/contacts_repo.dart';
import 'core/in_app_player.dart';
import 'core/location_service.dart';
import 'core/music_service.dart';
import 'core/nav_controller.dart';
import 'core/spotify_service.dart';
import 'core/theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr';
  await initializeDateFormatting('tr');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await InAppPlayer.initBackground();
  await AppState.I.load();
  await InAppPlayer.I.load();
  await SpotifyService.I.load();
  NavController.I; // konum dinleyicisini bağla
  runApp(const CarModeApp());
  // İzinleri sırayla iste (iOS aynı anda tek diyalog gösterir).
  await LocationService.I.start();
  await MusicService.I.start();
  await ContactsRepo.I.load();
  await CalendarRepo.I.load();
}

class CarModeApp extends StatefulWidget {
  const CarModeApp({super.key});

  @override
  State<CarModeApp> createState() => _CarModeAppState();
}

class _CarModeAppState extends State<CarModeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      AppState.I.applySystemSettings();
      MusicService.I.refresh();
      CalendarRepo.I.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) => MaterialApp(
        title: 'Araç Modu',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: AppState.messengerKey,
        navigatorKey: AppState.navigatorKey,
        theme: buildTheme(Brightness.light, diva: AppState.I.divaMode),
        darkTheme: AppState.I.divaMode
            ? buildTheme(Brightness.light, diva: true)
            : buildTheme(Brightness.dark),
        themeMode: AppState.I.divaMode
            ? ThemeMode.light
            : (AppState.I.isDark ? ThemeMode.dark : ThemeMode.light),
        // Fareyle de kaydırılabilsin (web/test için).
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        home: const CarShell(),
      ),
    );
  }
}
