import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/apps.dart';
import '../core/music_service.dart';
import '../core/theme.dart';
import '../core/web_players.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/maps_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/music_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/podcast_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/spotify_screen.dart';
import 'screens/web_app_screen.dart';
import 'widgets/diva_announcement.dart';
import 'widgets/sidebar.dart';
import 'widgets/siri_overlay.dart';

/// CarPlay çerçevesi: kenar çubuğu + aktif uygulama + sesli asistan.
class CarShell extends StatelessWidget {
  const CarShell({super.key});

  Widget _screen(CarApp app) {
    switch (app) {
      case CarApp.home:
        return const HomeScreen();
      case CarApp.dashboard:
        return const DashboardScreen();
      case CarApp.phone:
        return const PhoneScreen();
      case CarApp.music:
        return const MusicScreen();
      case CarApp.nowPlaying:
        return const MusicScreen(startOnNowPlaying: true);
      case CarApp.maps:
        return const MapsScreen();
      case CarApp.messages:
        return const MessagesScreen();
      case CarApp.calendar:
        return const CalendarScreen();
      case CarApp.settings:
        return const SettingsScreen();
      case CarApp.radio:
        return const RadioScreen();
      case CarApp.podcasts:
        return const PodcastScreen();
      case CarApp.spotify:
        return const SpotifyScreen();
      case CarApp.youtubeMusic:
        return WebAppScreen(app);
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.I, MusicService.I]),
      builder: (context, _) {
        final st = AppState.I;
        final p = Palette.of(context);
        final colors = st.divaMode ? divaWallpaper : wallpapers[st.wallpaper.clamp(0, wallpapers.length - 1)];
        final isHome = st.current == CarApp.home;
        return Scaffold(
          backgroundColor: p.bg,
          body: LayoutBuilder(builder: (context, c) {
            final landscape = c.maxWidth >= c.maxHeight;
            final isWeb = WebPlayers.forApp(st.current) != null;
            final screen = Container(
              decoration: isWeb
                  ? null
                  : BoxDecoration(
                      color: p.bg,
                      gradient: isHome
                          ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
                          : null,
                    ),
              child: SafeArea(
                left: !landscape,
                right: true,
                top: true,
                bottom: landscape,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
                  ),
                  child: KeyedSubtree(key: ValueKey(st.current), child: _screen(st.current)),
                ),
              ),
            );
            // Spotify / YouTube Music oynatıcıları alttaki katmanda hep canlı kalır.
            final content = Stack(children: [
              Positioned.fill(
                child: SafeArea(
                  left: !landscape,
                  bottom: landscape,
                  child: WebPlayersLayer(current: st.current),
                ),
              ),
              Positioned.fill(child: screen),
            ]);
            final body = landscape
                ? Row(children: [
                    SafeArea(right: false, child: const CarSidebar()),
                    Expanded(child: content),
                  ])
                : Column(children: [
                    Expanded(child: content),
                    SafeArea(top: false, child: const CarSidebar(vertical: false)),
                  ]);
            return Stack(children: [
              Positioned.fill(child: body),
              const Positioned.fill(child: SiriOverlay()),
              const Positioned.fill(child: DivaAnnouncement()),
            ]);
          }),
        );
      },
    );
  }
}
