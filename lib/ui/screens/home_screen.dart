import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/apps.dart';
import '../widgets/app_icon.dart';

/// Sayfalı uygulama ızgarası.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = homeOrder.map((a) => appInfos[a]!).toList();
    return LayoutBuilder(builder: (context, c) {
      final iconSize = (c.maxHeight / 4.2).clamp(60.0, 92.0);
      final cellW = iconSize + 44;
      final cellH = iconSize + 44;
      final cols = (c.maxWidth / cellW).floor().clamp(3, 6);
      final rows = ((c.maxHeight - 30) / cellH).floor().clamp(1, 5);
      final perPage = cols * rows;
      final pages = (apps.length / perPage).ceil();

      return Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: pages,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, pi) {
                final slice = apps.skip(pi * perPage).take(perPage).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var r = 0; r < rows; r++)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var col = 0; col < cols; col++)
                              SizedBox(
                                width: cellW,
                                child: (r * cols + col) < slice.length
                                    ? Center(
                                        child: AppTile(
                                          info: slice[r * cols + col],
                                          size: iconSize,
                                          onTap: () => AppState.I.open(slice[r * cols + col].app),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 24,
            child: pages > 1
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pages; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.35),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        ],
      );
    });
  }
}
