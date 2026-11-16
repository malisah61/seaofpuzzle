extends "res://betikler/puzzle/puzzle_taban.gd"
## POMPA istasyonu — sintineyi boşalt.
## Bir taşa dokun: yanındakiyle (sağdaki) yer değiştirir. Yatay ya da dikey 3+ aynı taş silinir.
## Zincirleme silinmeler (kombo) daha çok su boşaltır. Gemideki su yükseldikçe alt sıralar suya gömülür.

const SUTUN := 6
const SATIR := 9
const H := 58.0
const TAHTA := Vector2(24, 80)
const TUR_SAYISI := 5
const RENKLER := [
	Color(0.95, 0.75, 0.25), Color(0.4, 0.8, 0.9), Color(0.9, 0.4, 0.4),
	Color(0.55, 0.85, 0.45), Color(0.8, 0.6, 0.95),
]

var izgara := PackedInt32Array()
var _cozuluyor := false
var _adim_sayac := 0.0
var _silinecek: Array = []
var _kombo := 0
var _imlec := Vector2i(-1, -1)
var toplam := 0
var ofs := PackedVector2Array()   # takas ve düşüş animasyonu için çizim kayması
var _su_zaman := 0.0
const TASLAR := [["Yellow", "09"], ["Blue", "04"], ["Red", "12"], ["Green", "07"], ["Pink", "05"]]
const KOMBO_SOZU := ["", "ÇAT!", "BAM!", "PAT!", "BUUM!"]
const PARCACIK_TUR := ["sari", "mavi", "beyaz", "beyaz", "beyaz"]


func baslat() -> void:
	baslik = "Pompa"
	aciklama = "Taşa dokun: sağındakiyle yer değiştirir · 3+ aynı taş = su boşalır"
	izgara.resize(SUTUN * SATIR)
	ofs.resize(SUTUN * SATIR)
	ofs.fill(Vector2.ZERO)
	for y in SATIR:
		for x in SUTUN:
			izgara[y * SUTUN + x] = _eslesmeyen_tur(x, y)


func _eslesmeyen_tur(x: int, y: int) -> int:
	var t := randi() % TUR_SAYISI
	for i in TUR_SAYISI:
		var aday := (t + i) % TUR_SAYISI
		var yatay := x >= 2 and izgara[y * SUTUN + x - 1] == aday and izgara[y * SUTUN + x - 2] == aday
		var dikey := y >= 2 and izgara[(y - 1) * SUTUN + x] == aday and izgara[(y - 2) * SUTUN + x] == aday
		if not yatay and not dikey:
			return aday
	return t


func _eslesmeleri_bul() -> Array:
	var isaret := {}
	for y in SATIR:
		var x := 0
		while x < SUTUN:
			var t := izgara[y * SUTUN + x]
			var son := x
			while son + 1 < SUTUN and izgara[y * SUTUN + son + 1] == t:
				son += 1
			if t >= 0 and son - x + 1 >= 3:
				for k in range(x, son + 1):
					isaret[Vector2i(k, y)] = true
			x = son + 1
	for x in SUTUN:
		var y := 0
		while y < SATIR:
			var t := izgara[y * SUTUN + x]
			var son := y
			while son + 1 < SATIR and izgara[(son + 1) * SUTUN + x] == t:
				son += 1
			if t >= 0 and son - y + 1 >= 3:
				for k in range(y, son + 1):
					isaret[Vector2i(x, k)] = true
			y = son + 1
	return isaret.keys()


func dokun(p: Vector2) -> void:
	if _cozuluyor:
		return
	var alan := Rect2(TAHTA, Vector2(SUTUN * H, SATIR * H))
	if not alan.has_point(p):
		return
	var x := int((p.x - TAHTA.x) / H)
	var y := int((p.y - TAHTA.y) / H)
	var x2 := x + 1 if x < SUTUN - 1 else x - 1
	takas(mini(x, x2), y)


func takas(x: int, y: int) -> void:
	_imlec = Vector2i(x, y)
	var a := izgara[y * SUTUN + x]
	izgara[y * SUTUN + x] = izgara[y * SUTUN + x + 1]
	izgara[y * SUTUN + x + 1] = a
	ofs[y * SUTUN + x] = Vector2(H, 0)
	ofs[y * SUTUN + x + 1] = Vector2(-H, 0)
	ses_cal("tik", -6.0)
	_kombo = 0
	_silinecek = _eslesmeleri_bul()
	if not _silinecek.is_empty():
		_cozuluyor = true
		_adim_sayac = 0.22


func _process(delta: float) -> void:
	super._process(delta)
	_su_zaman += delta
	for i in ofs.size():
		if ofs[i] != Vector2.ZERO:
			ofs[i] = ofs[i].move_toward(Vector2.ZERO, delta * H * 12.0)
	if not _cozuluyor:
		return
	_adim_sayac -= delta
	if _adim_sayac > 0.0:
		return
	if _silinecek.is_empty():
		_cozuluyor = false
		return
	_kombo += 1
	var orta := Vector2.ZERO
	for c in _silinecek:
		var tur := izgara[c.y * SUTUN + c.x]
		if tur >= 0:
			parcacik_patlat(TAHTA + (Vector2(c) + Vector2(0.5, 0.5)) * H, PARCACIK_TUR[tur], 3)
		orta += Vector2(c)
		izgara[c.y * SUTUN + c.x] = -1
	orta /= float(_silinecek.size())
	patlama_yazisi(TAHTA + (orta + Vector2(0.5, 0.5)) * H, KOMBO_SOZU[mini(_kombo, 4)], [Color(1, 0.8, 0.2), Color(1, 0.55, 0.2), Color(0.95, 0.3, 0.3), Color(0.6, 0.4, 1.0)][mini(_kombo, 4) - 1])
	ses_cal("kombo" if _kombo >= 2 else "tas")
	var miktar := _silinecek.size() * 1.3 * (1.0 + 0.5 * (_kombo - 1))
	toplam += _silinecek.size()
	puan += int(miktar * 10)
	katki.emit("pompa", miktar)
	if _kombo >= 3:
		bildir("Kombo x" + str(_kombo) + "!")
	# Yerçekimi ve doldurma
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
			izgara[y * SUTUN + x] = randi() % TUR_SAYISI
			ofs[y * SUTUN + x] = Vector2(0, -yeni * H)
	_silinecek = _eslesmeleri_bul()
	_adim_sayac = 0.25


func _tas_ciz(merkez: Vector2, t: int) -> void:
	var renk: Color = RENKLER[t]
	var r := H * 0.36
	draw_circle(merkez + Vector2(2, 3), r, Color(0, 0, 0, 0.3))
	match t:
		0:
			draw_circle(merkez, r, renk)
		1:
			draw_colored_polygon(PackedVector2Array([merkez + Vector2(0, -r), merkez + Vector2(r, 0), merkez + Vector2(0, r), merkez + Vector2(-r, 0)]), renk)
		2:
			draw_rect(Rect2(merkez - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), renk)
		3:
			draw_colored_polygon(PackedVector2Array([merkez + Vector2(0, -r), merkez + Vector2(r, r * 0.8), merkez + Vector2(-r, r * 0.8)]), renk)
		_:
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(merkez + Vector2.RIGHT.rotated(TAU * i / 6.0) * r)
			draw_colored_polygon(pts, renk)
	draw_circle(merkez + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.55))


func ciz() -> void:
	var alan := Rect2(TAHTA, Vector2(SUTUN * H, SATIR * H))
	draw_rect(alan.grow(5), Color(0.3, 0.2, 0.1))
	draw_rect(alan, Color(0.12, 0.1, 0.08))
	# Su seviyesi: gemideki suya göre alt sıralar suya gömülür (dalgalı yüzey)
	if gemi != null and gemi.su > 0.5:
		var su_yuk: float = SATIR * H * gemi.su / 100.0
		var ust: float = TAHTA.y + SATIR * H - su_yuk
		var dalga := PackedVector2Array()
		for i in 13:
			var dx := SUTUN * H * i / 12.0
			dalga.append(Vector2(TAHTA.x + dx, ust + sin(_su_zaman * 3.0 + i * 0.9) * 4.0))
		dalga.append(TAHTA + Vector2(SUTUN * H, SATIR * H))
		dalga.append(TAHTA + Vector2(0, SATIR * H))
		draw_colored_polygon(dalga, Color(0.2, 0.5, 0.8, 0.45))
	for y in SATIR:
		for x in SUTUN:
			var t := izgara[y * SUTUN + x]
			var k: Vector2 = TAHTA + Vector2(x, y) * H + ofs[y * SUTUN + x]
			if t >= 0 and k.y > TAHTA.y - H * 0.6:
				var a := clampf((k.y - (TAHTA.y - H * 0.6)) / (H * 0.6), 0.0, 1.0)
				tas_ciz(Rect2(k + Vector2(5, 5), Vector2(H - 10, H - 10)), TASLAR[t][0], TASLAR[t][1], a)
	if _cozuluyor:
		for c in _silinecek:
			draw_rect(Rect2(TAHTA + Vector2(c) * H, Vector2(H, H)).grow(-2), Color(1, 1, 0.8, 0.45))
	if _imlec.x >= 0:
		draw_rect(Rect2(TAHTA + Vector2(_imlec) * H, Vector2(H * 2, H)), Color(1, 0.9, 0.4), false, 3.0)
	var sx := 392.0
	metin(Vector2(sx, 110), "Boşaltılan", 20, SOLUK)
	metin(Vector2(sx, 140), str(toplam) + " taş", 26)
	metin(Vector2(sx, 190), "Puan: " + str(puan), 22)
	if gemi != null:
		metin(Vector2(sx, 250), "Sintine", 20, SOLUK)
		var r := Rect2(sx, 262, 40, 260)
		draw_rect(r, Color(0, 0, 0, 0.4))
		var dolu: float = r.size.y * gemi.su / 100.0
		draw_rect(Rect2(r.position.x, r.end.y - dolu, r.size.x, dolu), Color(0.25, 0.55, 0.85))
		metin(Vector2(sx + 52, 540), "%" + str(int(gemi.su)), 22)


## Önizleme/test botu: eşleşme yaratan ilk takası yapar, yoksa rastgele takas.
func bot_hamle() -> void:
	if _cozuluyor:
		return
	for y in SATIR:
		for x in SUTUN - 1:
			var a := izgara[y * SUTUN + x]
			izgara[y * SUTUN + x] = izgara[y * SUTUN + x + 1]
			izgara[y * SUTUN + x + 1] = a
			var var_mi := not _eslesmeleri_bul().is_empty()
			izgara[y * SUTUN + x + 1] = izgara[y * SUTUN + x]
			izgara[y * SUTUN + x] = a
			if var_mi:
				takas(x, y)
				return
	takas(randi() % (SUTUN - 1), randi() % SATIR)
