extends "res://betikler/puzzle/puzzle_taban.gd"
## TOP istasyonu — gülle doldurma.
## Parmağını sürükleyerek yan yana parçalardan zincir kur: BARUT → GÜLLE → FİTİL → BARUT ...
## Zincir istediğin parçadan başlayabilir ama sıra hep bu döngüyü izler. Her tam üçlü bir "yük" verir.
## Seçili mühimmat: Demir 1 yük, Zincir ve Ateşli gülle 2 yük ister. Uzun zincirler bonus yük verir.

const SUTUN := 7
const SATIR := 8
const H := 58.0
const TAHTA := Vector2(24, 80)
const TUR_ADI := ["Barut", "Gülle", "Fitil"]
const MERMILER := [["demir", "Demir", 1], ["zincir", "Zincir", 2], ["ates", "Ateşli", 2], ["harpun", "Harpun", 2]]
const IPUCU_SURE := 5.0
const ZINCIR_SOZU := ["", "", "", "BUM!", "BAM!", "BAM!", "BUUM!", "BUUM!"]

var izgara := PackedInt32Array()
var ofs := PackedVector2Array()
var zincir: Array = []          # Vector2i listesi
var _surukluyor := false
var secili := 0                 # MERMILER indeksi
var artik := 0                  # bir sonraki gülleye aktarılan yük
var dolan := 0
var _zaman := 0.0
var _bosta := 0.0              # hamle yapılmayan süre (ipucu için)
var _ipucu: Array = []         # önerilen zincir (tahta değişince silinir)


func baslat() -> void:
	baslik = "Top"
	aciklama = "Sürükle: Barut > Gülle > Fitil zinciri kur, bırak"
	izgara.resize(SUTUN * SATIR)
	ofs.resize(SUTUN * SATIR)
	ofs.fill(Vector2.ZERO)
	for i in izgara.size():
		izgara[i] = randi() % 3
	_karistir_gerekirse()


func _sonraki_tur(t: int) -> int:
	return (t + 1) % 3


func _hucre(p: Vector2) -> Vector2i:
	var q := (p - TAHTA) / H
	if q.x < 0 or q.y < 0 or q.x >= SUTUN or q.y >= SATIR:
		return Vector2i(-1, -1)
	# Köşegene yakın dokunuşları yok saymak için hücre merkezine yakınlık şartı
	var ic := q - Vector2(floor(q.x), floor(q.y))
	if ic.distance_to(Vector2(0.5, 0.5)) > 0.48:
		return Vector2i(-2, -2)
	return Vector2i(int(q.x), int(q.y))


func _gui_input(event: InputEvent) -> void:
	# Sürükleme için taban sınıfın tıklama işleyişini genişletiyoruz
	if event is InputEventMouseMotion and _surukluyor:
		accept_event()
		zincire_ekle(_hucre(event.position))
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _surukluyor:
		accept_event()
		_surukluyor = false
		doldur()
		return
	super._gui_input(event)


func dokun(p: Vector2) -> void:
	var t := tus_bul(p)
	if t.begins_with("mermi"):
		secili = int(t.substr(5))
		ses_cal("tik")
		return
	var c := _hucre(p)
	if c.x >= 0:
		_bosta = 0.0
		_ipucu.clear()
		zincir = [c]
		_surukluyor = true
		ses_cal("tik", -10.0)


## Sürüklenen hücreyi zincire ekler (geri dönülürse son halka silinir).
func zincire_ekle(c: Vector2i) -> void:
	if c.x < 0 or zincir.is_empty():
		return
	var son: Vector2i = zincir[-1]
	if c == son:
		return
	if zincir.size() >= 2 and c == zincir[-2]:
		zincir.pop_back()
		return
	if zincir.has(c):
		return
	if absi(c.x - son.x) + absi(c.y - son.y) != 1:
		return
	if izgara[c.y * SUTUN + c.x] != _sonraki_tur(izgara[son.y * SUTUN + son.x]):
		return
	zincir.append(c)
	ses_cal("tik", -14.0 + zincir.size())


func doldur() -> void:
	if zincir.size() < 3:
		if zincir.size() > 1:
			ses_cal("hata", -8.0)
			bildir("En az 3 parça: Barut, Gülle, Fitil")
		zincir.clear()
		return
	var yuk := zincir.size() / 3
	if zincir.size() >= 6:
		yuk += 1
	if zincir.size() >= 9:
		yuk += 1
	var orta := Vector2.ZERO
	for c in zincir:
		var tur := izgara[c.y * SUTUN + c.x]
		parcacik_patlat(TAHTA + (Vector2(c) + Vector2(0.5, 0.5)) * H, ["beyaz", "mavi", "sari"][tur], 3)
		orta += Vector2(c)
		izgara[c.y * SUTUN + c.x] = -1
	orta /= float(zincir.size())
	patlama_yazisi(TAHTA + (orta + Vector2(0.5, 0.5)) * H, ZINCIR_SOZU[mini(zincir.size(), 7)], Color(1, 0.55, 0.2) if zincir.size() < 6 else Color(0.95, 0.3, 0.3))
	ses_cal("kombo" if zincir.size() >= 6 else "carpma", -4.0)
	var m: Array = MERMILER[secili]
	var toplam_yuk := yuk + artik
	var adet: int = toplam_yuk / int(m[2])
	artik = toplam_yuk % int(m[2])
	if adet > 0:
		katki.emit(m[0], float(adet))
		dolan += adet
		bildir("+" + str(adet) + " " + str(m[1]) + " gülle")
	puan += zincir.size() * 15
	zincir.clear()
	_ipucu.clear()
	_bosta = 0.0
	_dusur()
	_karistir_gerekirse()


func _dusur() -> void:
	for x in SUTUN:
		var yaz := SATIR - 1
		for y in range(SATIR - 1, -1, -1):
			var t := izgara[y * SUTUN + x]
			if t != -1:
				izgara[yaz * SUTUN + x] = t
				ofs[yaz * SUTUN + x] = Vector2(0, -(yaz - y) * H)
				yaz -= 1
		var yeni := yaz + 1
		for y in range(yaz, -1, -1):
			izgara[y * SUTUN + x] = randi() % 3
			ofs[y * SUTUN + x] = Vector2(0, -yeni * H)


## Tahtada en az bir 3'lü zincir yoksa yeniden karıştırır.
func _karistir_gerekirse() -> void:
	for deneme in 20:
		if en_uzun_zincir(3).size() >= 3:
			return
		for i in izgara.size():
			izgara[i] = randi() % 3


## Derinlik öncelikli arama: en uzun geçerli zinciri bulur (bot ve ipucu için).
func en_uzun_zincir(yeter := 12) -> Array:
	var en_iyi: Array = []
	for y in SATIR:
		for x in SUTUN:
			var yol: Array = [Vector2i(x, y)]
			var sonuc := _ara(yol, yeter)
			if sonuc.size() > en_iyi.size():
				en_iyi = sonuc
				if en_iyi.size() >= yeter:
					return en_iyi
	return en_iyi


func _ara(yol: Array, yeter: int) -> Array:
	var en_iyi: Array = yol.duplicate()
	if yol.size() >= yeter:
		return en_iyi
	var son: Vector2i = yol[-1]
	var gerek := _sonraki_tur(izgara[son.y * SUTUN + son.x])
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = son + d
		if c.x < 0 or c.y < 0 or c.x >= SUTUN or c.y >= SATIR or yol.has(c):
			continue
		if izgara[c.y * SUTUN + c.x] != gerek:
			continue
		yol.append(c)
		var s := _ara(yol, yeter)
		yol.pop_back()
		if s.size() > en_iyi.size():
			en_iyi = s
			if en_iyi.size() >= yeter:
				break
	return en_iyi


func _process(delta: float) -> void:
	super._process(delta)
	_zaman += delta
	# İpucu: 5 sn hamle yoksa uzun bir zincir yanıp söner (yalnız panel görünürken, bir kez hesaplanır)
	if visible and not _surukluyor:
		_bosta += delta
		if _bosta >= IPUCU_SURE and _ipucu.is_empty():
			_ipucu = en_uzun_zincir(6)
	for i in ofs.size():
		if ofs[i] != Vector2.ZERO:
			ofs[i] = ofs[i].move_toward(Vector2.ZERO, delta * H * 12.0)


func _parca_ciz(k: Vector2, t: int, vurgu: bool) -> void:
	var m := k + Vector2(H, H) / 2.0
	var zemin: Color = [Color(0.42, 0.26, 0.14), Color(0.25, 0.3, 0.38), Color(0.5, 0.36, 0.12)][t]
	var sb := StyleBoxFlat.new()
	sb.bg_color = zemin.lightened(0.25) if vurgu else zemin
	sb.set_corner_radius_all(12)
	sb.border_color = Color(1, 0.9, 0.5) if vurgu else zemin.lightened(0.3)
	sb.set_border_width_all(3 if vurgu else 2)
	draw_style_box(sb, Rect2(k + Vector2(4, 4), Vector2(H - 8, H - 8)))
	match t:
		0:  # Barut fıçısı
			var r := Rect2(m - Vector2(13, 16), Vector2(26, 32))
			draw_rect(r, Color(0.62, 0.38, 0.18))
			draw_rect(Rect2(r.position + Vector2(-2, 5), Vector2(30, 4)), Color(0.3, 0.3, 0.32))
			draw_rect(Rect2(r.position + Vector2(-2, 23), Vector2(30, 4)), Color(0.3, 0.3, 0.32))
			draw_rect(Rect2(r.position + Vector2(6, 0), Vector2(3, 32)), Color(0.72, 0.48, 0.25))
			draw_string(ThemeDB.fallback_font, m + Vector2(-5, 7), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.08, 0.04))
		1:  # Gülle
			draw_circle(m + Vector2(2, 3), 15, Color(0, 0, 0, 0.35))
			draw_circle(m, 15, Color(0.13, 0.13, 0.16))
			draw_circle(m + Vector2(-5, -5), 5, Color(1, 1, 1, 0.45))
		_:  # Fitil
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(m + Vector2(-16 + i * 4, sin(i * 1.3 + _zaman * 3.0) * 5.0 + 6))
			draw_polyline(pts, Color(0.92, 0.82, 0.55), 4.0)
			var alev: Texture2D = V.doku("efekt/fire2.png")
			var s := 0.9 + 0.15 * sin(_zaman * 12.0 + k.x)
			draw_texture_rect(alev, Rect2(m + Vector2(12, -18) - Vector2(5.5, 0) * s, Vector2(11, 27) * s), false)


func ciz() -> void:
	var alan := Rect2(TAHTA, Vector2(SUTUN * H, SATIR * H))
	draw_rect(alan.grow(5), Color(0.3, 0.2, 0.1))
	draw_rect(alan, Color(0.1, 0.08, 0.07))
	var zincirde := {}
	for c in zincir:
		zincirde[c] = true
	for y in SATIR:
		for x in SUTUN:
			var t := izgara[y * SUTUN + x]
			var k: Vector2 = TAHTA + Vector2(x, y) * H + ofs[y * SUTUN + x]
			if t >= 0 and k.y > TAHTA.y - H * 0.5:
				_parca_ciz(k, t, zincirde.has(Vector2i(x, y)))
	# İpucu zinciri (yanıp söner)
	if not _ipucu.is_empty() and zincir.is_empty():
		var a := 0.35 + 0.35 * sin(_zaman * 6.0)
		var ip := PackedVector2Array()
		for c in _ipucu:
			var k: Vector2 = TAHTA + Vector2(c) * H
			draw_rect(Rect2(k + Vector2(3, 3), Vector2(H - 6, H - 6)), Color(0.4, 1.0, 0.5, a), false, 4.0)
			ip.append(k + Vector2(H, H) / 2.0)
		draw_polyline(ip, Color(0.4, 1.0, 0.5, a * 0.8), 4.0)
	# Zincir çizgisi
	if zincir.size() >= 2:
		var pts := PackedVector2Array()
		for c in zincir:
			pts.append(TAHTA + (Vector2(c) + Vector2(0.5, 0.5)) * H)
		draw_polyline(pts, Color(0.1, 0.05, 0.02, 0.8), 12.0)
		draw_polyline(pts, Color(1, 0.8, 0.3), 6.0)
		draw_circle(pts[-1], 9, Color(1, 0.9, 0.4))
	# Yan sütun
	var sx := 446.0
	metin(Vector2(sx, 100), "Sıra", 18, SOLUK)
	for i in 3:
		var k := Vector2(sx + 2, 108 + i * 50)
		_parca_ciz_kucuk(k, i)
	metin(Vector2(sx, 280), "Zincir", 18, SOLUK)
	metin(Vector2(sx, 306), str(zincir.size()) + " / " + str(zincir.size() / 3) + " yük", 18)
	metin(Vector2(sx, 350), "Mühimmat", 18, SOLUK)
	for i in MERMILER.size():
		var r := Rect2(sx, 360 + i * 54, 100, 48)
		tus_ciz(r, "", i == secili)
		tus_ekle(r, "mermi" + str(i))
		metin(r.position + Vector2(8, 20), MERMILER[i][1], 17, Color(1, 0.9, 0.5) if i == secili else YAZI)
		var stok: int = gemi.mermi[MERMILER[i][0]] if gemi != null else 0
		metin(r.position + Vector2(8, 40), "x" + str(stok) + "  (" + str(MERMILER[i][2]) + " yük)", 15, SOLUK)
	metin(Vector2(sx, 600), "Artık: " + str(artik), 17, SOLUK)
	metin(Vector2(24, 584), "Dolan gülle: " + str(dolan) + "    Puan: " + str(puan), 20)
	metin(Vector2(24, 614), "Uzun zincir = bonus yük (6+: +1, 9+: +2)", 17, SOLUK)
	metin(Vector2(24, 640), "Zincir yelken yırtar, ateşli yakar, harpun canavar avlar.", 17, SOLUK)


func _parca_ciz_kucuk(k: Vector2, t: int) -> void:
	var renk: Color = [Color(0.62, 0.38, 0.18), Color(0.13, 0.13, 0.16), Color(0.92, 0.82, 0.55)][t]
	draw_circle(k + Vector2(14, 14), 13, renk)
	metin(k + Vector2(34, 20), TUR_ADI[t], 16)
	if t < 2:
		metin(k + Vector2(8, 46), "v", 14, SOLUK)


## Önizleme/test botu: en uzun zinciri bulup doldurur.
func bot_hamle(birak := true) -> void:
	zincir = en_uzun_zincir(9)
	if birak:
		doldur()
