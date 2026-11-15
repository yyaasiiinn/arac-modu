# Araç Modu (CarPlay tarzı telefon uygulaması)

Ekranı olmayan araçlarda telefonu tutucuya takıp CarPlay gibi kullanmak için yazılmış Flutter uygulaması.
Ses aracın hoparlörlerinden Bluetooth üzerinden gelir. Görüntü telefonun ekranında, CarPlay arayüzüne benzer bir düzende gösterilir.

## Özellikler

| CarPlay | Bu uygulamada |
|---|---|
| Ana ekran + sol kenar çubuğu | Sayfalı simge ızgarası, saat/sinyal/pil, son 3 uygulama, ana ekran düğmesi (ana ekrandayken Dashboard'a geçer) |
| Dashboard | Harita + Şu An Çalan + öneriler (takvim etkinliği, Ev/İş, favori kişiler) |
| Haritalar | Adres/yer arama, kategoriler (akaryakıt, otopark, yemek…), rota önizleme, **adım adım sesli Türkçe navigasyon**, rotadan çıkınca yeniden hesaplama, gece haritası (Esri), yön yukarıda modu — tamamen uygulama içinde |
| Telefon | Favoriler, Son Aramalar, Kişiler (A-Z), Tuş Takımı |
| Mesajlar | Kişi seç → sesle yazdır → sesli okut → uygulamanın içinde açılan pencereden SMS/iMessage gönder (veya WhatsApp), hazır yanıtlar, "varış saatim" paylaşımı |
| Müzik / Şu An Çalan | Apple Music kontrolü (çal/duraklat/ileri/geri/sar, karışık, tekrar), çalma listeleri, kapak görseli |
| Siri | Renkli küre ile Türkçe sesli asistan: "Annemi ara", "Ahmet'e mesaj gönder yoldayım", "Eve git", "En yakın benzinliğe git", "Müzik çal", "Sonraki şarkı", "Ne zaman varırım", "Saat kaç", "Takvimde ne var" |
| Takvim | 7 günlük etkinlikler, konumlu etkinliğe tek dokunuşla rota |
| Ayarlar | Otomatik/Koyu/Açık tema, duvar kağıdı, ekranı açık tutma, yatay kilit, sesli yönlendirme, Ev/İş adresi |
| Radyo | Türkiye'deki canlı radyolar (radio-browser.info), favoriler, sesle istasyon arama — uygulama içinde çalar |
| Podcast'ler | Türkiye listesi, sesle arama, abonelik, kaldığın yerden devam — uygulama içinde çalar |

## iPhone'a kurulum (ücretsiz yöntem)

1. Bu klasörü yeni bir GitHub deposuna yükleyin.
2. **Actions → "iOS IPA (imzasız)" → Run workflow** ile derlemeyi başlatın.
3. Derleme bitince **Artifacts** bölümünden `AracModu-ipa` dosyasını indirip zipten çıkarın.
4. Sideloadly ile `AracModu.ipa` dosyasını Apple ID'nizle iPhone'a yükleyin.
5. iPhone'da **Ayarlar → Genel → VPN ve Aygıt Yönetimi** bölümünde geliştiriciye güvenin.

Ücretsiz Apple ID ile yüklenen uygulamaların 7 günde bir Sideloadly ile yeniden yüklenmesi gerekir.

İlk açılışta konum, mikrofon, konuşma tanıma, kişiler, takvim ve Apple Music izinlerini verin.

## Bilmeniz gerekenler (iOS sınırları)

- **SMS okunamaz:** iOS, uygulamaların gelen SMS'leri okumasına izin vermez. Gönderirken uygulamanın içinde Apple'ın mesaj penceresi açılır; son "Gönder" dokunuşunu iOS zorunlu tutar.
- **Arama onayı:** Arama başlatılırken iOS bir onay penceresi gösterir.
- **Müzik kontrolü** iPhone'un **Müzik (Apple Music)** uygulamasıyla çalışır. Radyo ve podcast uygulamanın kendi oynatıcısında çalar.
- **Son Aramalar** listesinde yalnızca bu uygulamadan yapılan aramalar görünür, çünkü iOS arama geçmişini paylaşmaz.
- Harita verisi OpenStreetMap'ten, rotalar OSRM'den gelir. İkisi de ücretsizdir ve API anahtarı gerektirmez, ancak internet bağlantısı ister.

## Geliştirme

```bash
flutter pub get
flutter run            # bağlı telefonda
flutter build web      # tarayıcıda arayüz denemesi (müzik/rehber/takvim hariç)
```

Klasör yapısı:

- `lib/core/`: durum yönetimi, konum, navigasyon, müzik köprüsü, sesli asistan, rehber ve takvim
- `lib/ui/screens/`: Ana ekran, Dashboard, Haritalar, Telefon, Mesajlar, Müzik, Takvim ve Ayarlar
- `ios/Runner/AppDelegate.swift`: Apple Music kontrolü (MusicBridge)
