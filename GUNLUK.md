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

## 2026-11-18 — 2. aşama başladı: savaş tahtası, Top puzzle'ı, korsanlar
**Analiz.** (1) Oyuncu deneyimi: denizde risk yoktu; puzzle'ların tek hedefi göstergeleri doldurmaktı, bu yüzden 10 dakika sonra amaç kalmıyordu. Puzzle Pirates'ta puzzle'ların asıl anlamı savaşta ortaya çıkar (Yelken hareket jetonu, Top gülle üretir; Tamir/Pompa gemiyi ayakta tutar). (2) Seafight tarafı: açık denizde dolaşan, görünce saldıran NPC'ler ve farklı mühimmat türleri hem gerilim hem ganimet döngüsü sağlar. Eksikler: düşman, ödül döngüsü, Top istasyonu, savaşın puzzle'larla bağı.

**Yeni (2. aşamadan 3 özellik)**
- **Top puzzle'ı** (`betikler/puzzle/top.gd`): 7x8 tahtada parmakla sürüklenen zincir; sıra Barut > Gülle > Fitil döngüsü. Her tam üçlü 1 yük; 6+ ve 9+ zincire bonus. Mühimmat seçimi: Demir (1 yük), Zincir (2 yük), Ateşli (2 yük). Zincir bulunamazsa tahta kendini karıştırır.
- **Savaş tahtası** (`betikler/savas.gd`): 16x16 ızgara, 20 sn'lik turlar, tur başına 4 adım. Sol/İleri/Sağ hareketleri Yelken jetonu harcar; adım kutusunun kenarına dokununca o bordadan seçili gülle atılır (3 kare menzil). Kaya (4 hasar), rüzgar şeritleri (iter), girdap (döndürüp fırlatır), gemi çarpışması. Demir 9 hasar; Zincir 5 + rakibin sonraki turu 3 hamle; Ateşli 6 + 2 tur yanma. Oyuncunun canı gemi gövdesi: savaşta Tamir ve Pompa kritik. Plan önizlemesi (sarı yol + kırmızı atış çizgileri), uçan gülle, Kenney duman patlamaları, "BAM! YIRT! BUUM! ÇAT! VIIN!" yazıları.
- **NPC korsan gemileri** (`betikler/korsanlar.gd`): 6 korsan (siyah/kırmızı Kenney gemileri, güç 1-3), denizde dolaşır, 520 px'de "!" ile kovalar, 150 px'de savaş başlatır. Yapay zekâ 4 adımlık tüm hareket dizilerini (256) dener ve bordasına hedef gelen planı seçer. Yenilen korsan batar, 60 sn sonra daha güçlü doğar. Ganimet 100-200 altın. Limandayken saldırmazlar.

**İyileştirmeler (3)**
- Yelken: silinen her sıra 2 hareket jetonu (dörtlü fırtına 8) verir; panelde jeton göstergesi.
- Pompa: 5 sn hamle yapılmazsa olası bir takas yeşil yanıp sönerek ipucu verir.
- Arayüz: "Top (yakında)" tuşu artık gerçek istasyon; göstergelerde hareket/gülle sayıları, mini haritada görünen korsanlar kırmızı nokta; savaşta deniz arayüzü gizlenir. Yapay tayfa savaş için yavaşça (4'e kadar) jeton biriktirir.

**Test:** `--deneme` artık Top puzzle'ını ve bot oyuncuyla tam bir korsan savaşını oynatır (atış/isabet istatistiği yazar). `--onizleme` yeni 4 görüntü üretir: `5_top`, `6_korsan`, `7_savas`, `8_savas_atis`.

**Sırada (2. aşamanın kalanı):** harpunla avlanan deniz canavarları, kanca + rampa blok düellosu (kombolar rakibe engel blok gönderir), savaştan kaçış, ses efektleri için Kenney top/patlama sesleri.
