# Sea of Puzzle — geliştirme kuralları

- Kullanıcıyla (Mehmet Ali) **her zaman Türkçe** konuş. Kod içi adlar ve yorumlar da Türkçe.
- Motor: **Godot 4.3, GDScript**, renderer GL Compatibility, yatay ekran 1280x720 (stretch: canvas_items / expand).
- Tasarım belgesi (kaynak doğruluk): https://claude.ai/artifact/KiGH3z44ZyqLpqGHgjucn1 — Puzzle Pirates + Seafight analizleri, sistemler, 5 aşamalı yol haritası.
- Görseller ve isimler tamamen özgün olmalı; Puzzle Pirates / Seafight'ın sanatı, isimleri ve markaları kopyalanmaz, sadece mekaniklerinden ilham alınır.
- Var olan özellikleri silme; geliştir. Telefon performansı öncelikli (takılma, donma olmamalı).
- Sahneler kodla kurulur (`oyun.tscn` sadece kök düğüm). Yeni puzzle'lar `betikler/puzzle/puzzle_taban.gd`'den türetilir ve `katki(tur, miktar)` sinyaliyle gemiye bağlanır.

## Yapı
- `betikler/oyun.gd` ana oyun, `deniz.gd` harita, `gemi.gd` gemi sistemleri, `arayuz.gd` HUD, `sis.gd`, `hazineler.gd`, `su.gdshader`
- `betikler/puzzle/` — `yelken.gd` (tetris), `tamir.gd` (yama yerleştirme), `pompa.gd` (yatay takaslı eşleştirme)

## Test (göndermeden önce mutlaka)
```
godot --headless --path . --editor --quit          # içe aktar, parse hatası var mı
godot --headless --path . -- --deneme              # "TEST TAMAM" yazmalı
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -- --onizleme=onizleme
```
Son komut `onizleme/` klasörüne 4 ekran görüntüsü yazar; görüntülere bakıp kontrol et ve depoya ekle.

## Derleme
`main`'e her push'ta `.github/workflows/android.yml` APK derler ve `son-surum` sürümüne yükler.
Her çalışmanın özeti `GUNLUK.md`'ye eklenir.
