# Sea of Puzzle — geliştirme kuralları

- Kullanıcıyla (Mehmet Ali) **her zaman Türkçe** konuş. Kod içi adlar ve yorumlar da Türkçe.
- Motor: **Godot 4.3, GDScript**, renderer GL Compatibility, yatay ekran 1280x720 (stretch: canvas_items / expand).
- Tasarım belgesi (kaynak doğruluk): https://claude.ai/artifact/KiGH3z44ZyqLpqGHgjucn1 — Puzzle Pirates + Seafight analizleri, sistemler, 5 aşamalı yol haritası.
- Görseller ve isimler tamamen özgün olmalı; Puzzle Pirates / Seafight'ın sanatı, isimleri ve markaları kopyalanmaz, sadece mekaniklerinden ilham alınır.
- Var olan özellikleri silme; geliştir. Telefon performansı öncelikli (takılma, donma olmamalı).
- Sahneler kodla kurulur (`oyun.tscn` sadece kök düğüm). Yeni puzzle'lar `betikler/puzzle/puzzle_taban.gd`'den türetilir ve `katki(tur, miktar)` sinyaliyle gemiye bağlanır.

## Görsel yön ve ücretsiz varlıklar
- Hedef his: Puzzle Pirates gibi renkli, canlı, çizgi film tarzı; puzzle'lar parlak taşlı ve **animasyonlu** (kayan/düşen taşlar, parıltı parçacıkları, "ÇAT! BAM! BUUM!" tarzı çizgi roman patlamaları, ses efektleri). Kullanıcı bunu özellikle istedi.
- Varlıklar `varliklar/` klasöründe, hepsi **Kenney CC0** (lisans: `varliklar/LISANS.md`). Yükleme `betikler/varlik.gd` ile (`V.doku("gemiler/gemi_05.png")`, `V.karo(70)`, `V.font()`), sesler `betikler/ses.gd` (`ses_cal("eslesme")`).
- Yeni varlık gerekirse önce Kenney aynasına bak: `git clone --depth 1 https://github.com/ETdoFresh/kenney.nl` (opengameart/kenney.nl bu ortamdan erişilemez, github.com erişilebilir). Orada Pirate Pack, Pirate Kit (3D), Puzzle Pack 1-2, Particle/Smoke, UI Pack, Fonts, Impact/Interface/RPG sesleri, Music Jingles, Toon Characters, Modular Characters ve daha fazlası var. Sadece gereken dosyaları kopyala, depoyu şişirme; LISANS.md'yi güncelle.
- Sadece CC0 (veya açıkça serbest) varlık kullan; Puzzle Pirates/Seafight görselleri asla kullanılmaz.
- Gemi sprite'ları: `gemi_NN.png`, renk r (0 beyaz,1 siyah,2 kırmızı,3 yeşil,4 mavi,5 sarı) → sağlam r+1, hasarlı r+7, ağır hasarlı r+13, batık r+19. Pruva aşağı bakar (-90° döndür).
- Adalar Kenney 9 dilim karolarıyla kurulur (`deniz.gd` CIMLI/KUMLU/SIG). Kenney Future fontunda Türkçe harf yok ve "K" harfi "H" gibi okunur: sadece K içermeyen patlama sözlerinde kullan, başlık/isimlerde varsayılan fontu kullan.
- Gelecek hedefi: Puzzle Pirates'taki gibi izometrik **güverte görünümü** (tayfa karakterleri istasyonlarda çalışırken) — Kenney Pirate Kit 3D modelleri izometrik kamerayla render edilebilir ya da Toon/Modular Characters kullanılabilir.

## Yapı
- `betikler/varlik.gd` varlık yükleyici, `ses.gd` ses yöneticisi, `oyun.gd` ana oyun, `deniz.gd` harita, `gemi.gd` gemi sistemleri, `arayuz.gd` HUD, `sis.gd`, `hazineler.gd`, `su.gdshader`
- `betikler/puzzle/` — `yelken.gd` (tetris), `tamir.gd` (yama yerleştirme), `pompa.gd` (yatay takaslı eşleştirme), `top.gd` (barut-gülle-fitil zinciri)
- `betikler/savas.gd` 16x16 turlu savaş tahtası (oyuncu canı = `gemi.govde`, jetonlar `gemi.hareket` / `gemi.mermi`), `korsanlar.gd` denizdeki NPC korsanlar (`saldiri` sinyali → `oyun.savas_baslat`), `canavarlar.gd` deniz canavarları (aynı sinyal, `canavar: true`; `canavar_ciz` statik çizim)
- `betikler/puzzle/duello.gd` rampa düellosu (savaşta kanca → `oyun.duello_baslat`, sonuç `katki("duello", ±1)`)

## Test (göndermeden önce mutlaka)
```
godot --headless --path . --editor --quit          # içe aktar, parse hatası var mı
godot --headless --path . -- --deneme              # "TEST TAMAM" yazmalı
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -- --onizleme=onizleme
```
Son komut `onizleme/` klasörüne 12 ekran görüntüsü yazar; görüntülere bakıp kontrol et ve depoya ekle.

## Derleme
`main`'e her push'ta `.github/workflows/android.yml` APK derler ve `son-surum` sürümüne yükler.
Her çalışmanın özeti `GUNLUK.md`'ye eklenir.
