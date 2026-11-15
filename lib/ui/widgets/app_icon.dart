import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/apps.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Yuvarlatılmış kare uygulama simgesi.
class AppGlyph extends StatelessWidget {
  final AppInfo info;
  final double size;
  final bool playing;
  const AppGlyph(this.info, {super.key, this.size = 76, this.playing = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Diva Modu değişince yeniden çiz
    Widget inner;
    if (info.app == CarApp.calendar) {
      final now = DateTime.now();
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat('EEE', 'tr').format(now).toUpperCase(),
              style: TextStyle(color: CP.diva ? CP.hotPink : CP.red, fontSize: size * 0.15, fontWeight: FontWeight.w700, height: 1)),
          Text('${now.day}',
              style: TextStyle(color: Colors.black, fontSize: size * 0.46, fontWeight: FontWeight.w400, height: 1.05)),
        ],
      );
    } else {
      inner = Icon(info.icon, color: CP.diva ? Colors.white : info.iconColor, size: size * 0.52);
    }
    var colors = info.colors.length == 1 ? [info.colors[0], info.colors[0]] : info.colors;
    if (CP.diva && info.app != CarApp.calendar) {
      colors = divaIconGradients[info.app.index % divaIconGradients.length];
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.235),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
              color: CP.diva ? const Color(0x66C2185B) : const Color(0x55000000),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          inner,
          if (playing)
            Positioned(
              right: size * 0.06,
              top: size * 0.06,
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.volume_up_rounded, size: size * 0.11, color: CP.red),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ana ekrandaki simge + isim.
class AppTile extends StatelessWidget {
  final AppInfo info;
  final VoidCallback onTap;
  final double size;
  final Color labelColor;
  const AppTile({super.key, required this.info, required this.onTap, this.size = 76, this.labelColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(info, size: size),
          const SizedBox(height: 8),
          SizedBox(
            width: size + 30,
            child: Text(info.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: CP.diva ? FontWeight.w700 : FontWeight.w500,
                  shadows: CP.diva ? const [Shadow(color: Color(0x88A0124F), blurRadius: 6)] : null,
                )),
          ),
        ],
      ),
    );
  }
}
