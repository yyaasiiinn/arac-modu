import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/nav_apps.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/place_search.dart';

/// Ayarlar (iOS ayarlar görünümü).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _picking; // 'home' | 'work'

  @override
  Widget build(BuildContext context) {
    if (_picking != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: PlaceSearchPanel(
          title: _picking == 'home' ? 'Ev adresini arayın' : 'İş adresini arayın',
          shortcuts: false,
          onClose: () => setState(() => _picking = null),
          onSelect: (p) {
            AppState.I.update(() {
              if (_picking == 'home') {
                AppState.I.home = p.copyWith(name: 'Ev');
              } else {
                AppState.I.work = p.copyWith(name: 'İş');
              }
            });
            setState(() => _picking = null);
          },
        ),
      );
    }

    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final st = AppState.I;
        final p = Palette.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            const CarHeader(title: 'Ayarlar'),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 20), children: [
                _section('STİL'),
                _group([
                  CarRow(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF8CC6), Color(0xFFFF1493)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💖', style: TextStyle(fontSize: 18)),
                    ),
                    title: 'Diva Modu',
                    subtitle: st.divaMode ? 'Her şey pembe 💅' : 'Her şeyi pembe yap',
                    onTap: () => st.setDivaMode(!st.divaMode),
                    trailing: CupertinoSwitch(
                      value: st.divaMode,
                      onChanged: st.setDivaMode,
                      activeTrackColor: CP.hotPink,
                    ),
                  ),
                ]),
                _section('GÖRÜNÜM'),
                _group([
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: CarSegments(
                      items: const ['Otomatik', 'Koyu', 'Açık'],
                      selected: st.themeChoice.index,
                      onChanged: (i) => st.update(() => st.themeChoice = ThemeChoice.values[i]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Duvar Kağıdı', style: TextStyle(color: p.text, fontSize: 19, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        for (var i = 0; i < wallpapers.length; i++)
                          Pressable(
                            onTap: () => st.update(() => st.wallpaper = i),
                            child: Container(
                              width: 78,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: wallpapers[i]),
                                border: Border.all(color: st.wallpaper == i ? CP.blue : Colors.transparent, width: 3),
                              ),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ]),
                _section('SÜRÜŞ'),
                _group([
                  _switch('Ekranı Açık Tut', CupertinoIcons.sun_max_fill, CP.orange, st.keepAwake,
                      (v) => st.update(() => st.keepAwake = v)),
                  const CarDivider(indent: 62),
                  _switch('Yatay Ekrana Kilitle', CupertinoIcons.device_phone_landscape, CP.indigo, st.landscapeLock,
                      (v) => st.update(() => st.landscapeLock = v)),
                  const CarDivider(indent: 62),
                  _switch('Dashboard ile Başla', CupertinoIcons.rectangle_split_3x1_fill, CP.teal, st.startOnDashboard,
                      (v) => st.update(() => st.startOnDashboard = v)),
                ]),
                _section('HARİTALAR'),
                _group([
                  CarRow(
                    leading: _icon(navAppById(st.navApp == 'ask' ? 'internal' : st.navApp).icon,
                        st.navApp == 'ask' ? CP.gray : navAppById(st.navApp).color),
                    title: 'Navigasyon Uygulaması',
                    subtitle: st.navApp == 'ask' ? 'Her seferinde sor' : navAppById(st.navApp).name,
                    trailing: Icon(CupertinoIcons.chevron_right, color: p.subtext),
                    onTap: () async {
                      final a = await pickNavApp(context, title: 'Rotalar hangi uygulamada açılsın?', includeAsk: true);
                      if (a != null) st.update(() => st.navApp = a.id);
                    },
                  ),
                  const CarDivider(indent: 62),
                  _switch('Sesli Yönlendirme', CupertinoIcons.speaker_3_fill, CP.green, st.voiceGuidance,
                      (v) => st.update(() => st.voiceGuidance = v)),
                  const CarDivider(indent: 62),
                  _switch('Gidiş Yönü Yukarıda', CupertinoIcons.compass_fill, CP.blue, st.headingUp,
                      (v) => st.update(() => st.headingUp = v)),
                  const CarDivider(indent: 62),
                  _placeRow('Ev', CupertinoIcons.house_fill, CP.blue, st.home, 'home'),
                  const CarDivider(indent: 62),
                  _placeRow('İş', CupertinoIcons.briefcase_fill, CP.orange, st.work, 'work'),
                  const CarDivider(indent: 62),
                  CarRow(
                    leading: _icon(CupertinoIcons.clock_fill, CP.gray),
                    title: 'Son Yerleri Temizle',
                    titleColor: CP.red,
                    onTap: () => st.update(() => st.recentPlaces.clear()),
                  ),
                ]),
                _section('TELEFON'),
                _group([
                  CarRow(
                    leading: _icon(CupertinoIcons.star_fill, CP.yellow),
                    title: 'Favoriler',
                    subtitle: '${st.favorites.length} kişi · Telefon > Kişiler\'den ekleyin',
                  ),
                  const CarDivider(indent: 62),
                  CarRow(
                    leading: _icon(CupertinoIcons.trash_fill, CP.red),
                    title: 'Son Aramaları Temizle',
                    titleColor: CP.red,
                    onTap: () => st.update(() => st.recents.clear()),
                  ),
                ]),
                _section('SESLİ ASİSTAN'),
                _group([
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Kenar çubuğundaki renkli mikrofona dokunun veya ana ekran düğmesine basılı tutun.\n\n'
                      'Örnekler: "Annemi ara" · "Ahmet\'e mesaj gönder yoldayım" · "Eve git" · '
                      '"En yakın benzinliğe git" · "Müzik çal" · "Sonraki şarkı" · "Ne zaman varırım" · "Saat kaç"',
                      style: TextStyle(color: p.subtext, fontSize: 16, height: 1.4),
                    ),
                  ),
                ]),
                _section('HAKKINDA'),
                _group([
                  CarRow(
                    leading: _icon(CupertinoIcons.info_circle_fill, CP.gray),
                    title: 'Araç Modu 1.0',
                    subtitle: 'Harita: © OpenStreetMap katkıcıları · Rota: OSRM',
                  ),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: TextStyle(color: Palette.of(context).subtext, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _group(List<Widget> children) => CarCard(
        padding: EdgeInsets.zero,
        radius: 16,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _icon(IconData i, Color c) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        child: Icon(i, color: Colors.white, size: 20),
      );

  Widget _switch(String title, IconData icon, Color color, bool value, ValueChanged<bool> onChanged) => CarRow(
        leading: _icon(icon, color),
        title: title,
        onTap: () => onChanged(!value),
        trailing: CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: CP.green),
      );

  Widget _placeRow(String title, IconData icon, Color color, Place? place, String key) => CarRow(
        leading: _icon(icon, color),
        title: title,
        subtitle: place == null ? 'Ayarlanmadı' : [place.name == title ? '' : place.name, place.address].where((e) => e.isNotEmpty).join(', '),
        onTap: () => setState(() => _picking = key),
        trailing: place == null
            ? Icon(CupertinoIcons.chevron_right, color: Palette.of(context).subtext)
            : Pressable(
                onTap: () => AppState.I.update(() {
                  if (key == 'home') {
                    AppState.I.home = null;
                  } else {
                    AppState.I.work = null;
                  }
                }),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(CupertinoIcons.xmark_circle_fill, color: CP.gray)),
              ),
      );
}
