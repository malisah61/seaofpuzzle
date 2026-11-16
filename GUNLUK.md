# Geliştirme günlüğü

## 2026-11-16 — 1. aşama: ilk prototip
- Godot 4.3 projesi, yatay ekran, GL Compatibility.
- Açık deniz: 6000x6000 harita, animasyonlu su shader'ı, 17 ada (bazıları limanlı), 45 kayalık, 32 hazine sandığı, keşif sisi, mini harita.
- Gemi: dokunarak hareket, köpük izi, rüzgara göre şişen yelkenler; hız = rüzgar × su × gövde.
- Gemi sistemleri birbirine bağlı: hasar su aldırır, su ve hasar hızı düşürür; yapay zekâ tayfa boş istasyonları yavaşça çalıştırır.
- Puzzle'lar: Yelken (tetris, 7'li torba, hayalet parça, sıra ödülü), Tamir (deliğe tam oturan döndürülebilir yamalar, bölümler), Pompa (yatay takas, kombo zincirleri, su seviyesi görseli).
- Android APK derlemesi (GitHub Actions) ve önizleme/deneme modları.

## 2026-11-17 — Görsel ve animasyon yükseltmesi (kullanıcı isteği)
- Kenney CC0 varlıkları eklendi (`varliklar/`, 3.7 MB): Pirate Pack gemileri ve karoları, Puzzle Pack 2 taşları ve parıltıları, Smoke patlama kareleri, Kenney Future fontu, arayüz/darbe/RPG sesleri ve bir jingle.
- Deniz: adalar Kenney 9 dilim karolarıyla (kumsal + çimen, sığ su halkası, palmiye, yosunlu kaya, ot), limanlarda kale kulesi ve iskele; kayalıklar Kenney kaya karoları; su rengi Kenney paletine uyduruldu.
- Gemi: Kenney mavi gemi sprite'ı; gövde hasarına göre 3 görünüm (sağlam/hasarlı/ağır hasarlı), su aldıkça mavimsi ton, gölge ve sallanma.
- Puzzle'lar: Yelken'de Kenney parlak bloklar ve akıcı düşüş; Pompa'da 5 farklı şekilli taş (yıldız, elmas, kalp, üçgen, beşgen), takas ve düşüş animasyonu, dalgalı su yüzeyi; Tamir'de çekiç sesi ve kıvılcım.
- Ortak efektler: parıltı parçacıkları, "ÇAT! BAM! BUUM!" çizgi roman patlama yazıları, ses yöneticisi (tık, eşleşme, kombo, çekiç, altın, çarpma, hata, başarı).
