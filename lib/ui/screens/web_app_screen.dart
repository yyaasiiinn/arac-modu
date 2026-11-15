import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/apps.dart';
import '../../core/web_players.dart';
import '../widgets/common.dart';

/// Spotify / YouTube Music ekranı. Asıl web oynatıcı CarShell'de kalıcı
/// katman olarak durur (başka ekrana geçince müzik durmasın diye);
/// bu ekran sadece üstüne küçük denetimleri koyar.
class WebAppScreen extends StatefulWidget {
  final CarApp app;
  const WebAppScreen(this.app, {super.key});

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  WebPlayer get w => WebPlayers.forApp(widget.app)!;

  @override
  void initState() {
    super.initState();
    w.ensureOpen();
  }

  @override
  Widget build(BuildContext context) {
    if (!WebPlayer.supported) {
      return EmptyState(
        icon: CupertinoIcons.music_note_2,
        title: '${w.name} telefonda çalışır',
        message: 'Bu oynatıcı iPhone uygulamasında, uygulamanın içinde açılır.',
      );
    }
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) => Stack(children: [
        if (w.loading && w.title.isEmpty)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
        Positioned(
          right: 8,
          top: 8,
          child: Pressable(
            onTap: w.reload,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(19)),
              child: const Icon(CupertinoIcons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }
}

/// CarShell'in içinde, açılmış web oynatıcılarını canlı tutan katman.
class WebPlayersLayer extends StatelessWidget {
  final CarApp current;
  const WebPlayersLayer({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    if (!WebPlayer.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: WebPlayers.listenable,
      builder: (context, _) {
        final opened = WebPlayers.all.where((w) => w.opened).toList();
        // Görünen oynatıcı en üstte olsun.
        opened.sort((a, b) => (a.app == current ? 1 : 0).compareTo(b.app == current ? 1 : 0));
        return Stack(children: [
          for (final w in opened)
            Positioned.fill(
              key: ValueKey(w.app),
              child: WebViewWidget(controller: w.controller!),
            ),
        ]);
      },
    );
  }
}
