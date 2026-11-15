import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Basınca hafifçe küçülen dokunma alanı (CarPlay hissi).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.94});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedOpacity(
          opacity: _down ? 0.75 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Yuvarlatılmış kart.
class CarCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  const CarCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.97, child: box);
  }
}

/// Uygulama başlığı + geri/sağ butonlar (CarPlay üst çubuğu).
class CarHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? center;
  const CarHeader({super.key, required this.title, this.onBack, this.actions = const [], this.center});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (onBack != null)
            Pressable(
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Icon(CupertinoIcons.chevron_left, color: CP.blue, size: 26),
                  const SizedBox(width: 2),
                  Text('Geri', style: TextStyle(color: CP.blue, fontSize: 18, fontWeight: FontWeight.w500)),
                ]),
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: center ??
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: onBack != null ? TextAlign.center : TextAlign.start,
                    style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          ...actions,
          if (onBack != null && actions.isEmpty) const SizedBox(width: 80),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// CarPlay tarzı segment (sekme) seçici.
class CarSegments extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;
  const CarSegments({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Pressable(
                scale: 0.97,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? (p.dark ? const Color(0xFF636366) : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(items[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Büyük satır (liste elemanı).
class CarRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  const CarRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: titleColor ?? p.text, fontSize: 19, fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 15)),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class CarDivider extends StatelessWidget {
  final double indent;
  const CarDivider({super.key, this.indent = 14});
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.6, margin: EdgeInsets.only(left: indent), color: Palette.of(context).divider);
}

/// İsim baş harfli yuvarlak avatar.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Uint8List? photo;
  const Avatar(this.name, {super.key, this.size = 46, this.photo});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first.characters.first + (parts.length > 1 ? parts.last.characters.first : '')).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA5ABB8), Color(0xFF858994)],
        ),
        image: photo != null ? DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : Text(initials,
              style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w600)),
    );
  }
}

/// Büyük yuvarlak eylem butonu.
class RoundButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color iconColor;
  final double size;
  final VoidCallback? onTap;
  final String? label;
  const RoundButton({super.key, required this.icon, this.color, this.iconColor = Colors.white, this.size = 64, this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    final btn = Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color ?? CP.blue, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
    if (label == null) return btn;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      btn,
      const SizedBox(height: 6),
      Text(label!, style: TextStyle(color: Palette.of(context).subtext, fontSize: 13)),
    ]);
  }
}

/// Uzun, hap şeklinde buton.
class PillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final Color textColor;
  final VoidCallback? onTap;
  final double height;
  const PillButton({super.key, required this.text, this.icon, this.color, this.textColor = Colors.white, this.onTap, this.height = 54});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: color ?? CP.blue, borderRadius: BorderRadius.circular(height / 2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: textColor, size: 22), const SizedBox(width: 8)],
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boş durum / izin mesajı.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: p.subtext),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: p.text, fontSize: 21, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: p.subtext, fontSize: 16)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            PillButton(text: action!, onTap: onAction, height: 48),
          ],
        ]),
      ),
    );
  }
}

/// Manevra tipine göre ok simgesi.
IconData maneuverIcon(String type, String modifier) {
  if (type == 'arrive') return Icons.flag_rounded;
  if (type == 'depart') return Icons.navigation_rounded;
  if (type.contains('roundabout') || type.contains('rotary')) {
    return modifier.contains('left') ? Icons.roundabout_left : Icons.roundabout_right;
  }
  if (type == 'merge') return Icons.merge_rounded;
  if (type == 'fork') return modifier.contains('left') ? Icons.fork_left_rounded : Icons.fork_right_rounded;
  if (type == 'on ramp' || type == 'off ramp') {
    return modifier.contains('left') ? Icons.ramp_left_rounded : Icons.ramp_right_rounded;
  }
  switch (modifier) {
    case 'left':
      return Icons.turn_left_rounded;
    case 'right':
      return Icons.turn_right_rounded;
    case 'slight left':
      return Icons.turn_slight_left_rounded;
    case 'slight right':
      return Icons.turn_slight_right_rounded;
    case 'sharp left':
      return Icons.turn_sharp_left_rounded;
    case 'sharp right':
      return Icons.turn_sharp_right_rounded;
    case 'uturn':
      return Icons.u_turn_left_rounded;
    default:
      return Icons.straight_rounded;
  }
}
