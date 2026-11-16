extends "res://betikler/puzzle/puzzle_taban.gd"
## YELKEN istasyonu — tetris tarzı.
## Düşen yelken bezi parçalarıyla sıra tamamlanır; her silinen sıra gemiye rüzgar verir.
## Kontrol: tahtada parçanın soluna dokun = sola, sağına = sağa, üstüne = döndür. Yan tuşlar da var.

const SUTUN := 10
const SATIR := 16
const H := 36.0
const TAHTA := Vector2(24, 72)
const RENKLER := [
	Color(0.96, 0.93, 0.84), Color(0.93, 0.78, 0.45), Color(0.55, 0.78, 0.92), Color(0.85, 0.45, 0.38),
	Color(0.6, 0.82, 0.55), Color(0.78, 0.62, 0.88), Color(0.95, 0.66, 0.3),
]
const SEKILLER := [
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],  # I
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],  # O
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],  # T
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],  # S
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],  # Z
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],  # J
	[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],  # L
]
const SIRA_ODULU := [0.0, 10.0, 24.0, 40.0, 60.0]

var izgara := PackedInt32Array()
var tip := 0
var hucreler: Array = []      # aktif parçanın hücreleri (tahta koordinatı)
var sonraki := 0
var dusme_sure := 0.65
var _sayac := 0.0
var satirlar := 0
var _flas: Array = []
var _flas_sure := 0.0
var _torba: Array = []


func baslat() -> void:
	baslik = "Yelken"
	aciklama = "Parçanın soluna/sağına dokun: kaydır · üstüne: döndür"
	izgara.resize(SUTUN * SATIR)
	izgara.fill(-1)
	sonraki = _torbadan()
	_yeni_parca()


func _torbadan() -> int:
	if _torba.is_empty():
		_torba = [0, 1, 2, 3, 4, 5, 6]
		_torba.shuffle()
	return _torba.pop_back()


func _yeni_parca() -> void:
	tip = sonraki
	sonraki = _torbadan()
	hucreler = []
	for c in SEKILLER[tip]:
		hucreler.append(c + Vector2i(3, 0))
	if not _uygun(hucreler):
		# Yelkenler dolaştı: tahta temizlenir, küçük bir rüzgar kaybı olur.
		izgara.fill(-1)
		katki.emit("ruzgar", -6.0)
		bildir("Yelkenler dolaştı!")


func _uygun(hs: Array) -> bool:
	for c in hs:
		if c.x < 0 or c.x >= SUTUN or c.y >= SATIR:
			return false
		if c.y >= 0 and izgara[c.y * SUTUN + c.x] != -1:
			return false
	return true


func _kaydir(d: Vector2i) -> bool:
	var yeni: Array = []
	for c in hucreler:
		yeni.append(c + d)
	if _uygun(yeni):
		hucreler = yeni
		return true
	return false


func dondur() -> void:
	if tip == 1:
		return
	var merkez: Vector2i = hucreler[2] if tip != 0 else hucreler[1]
	var yeni: Array = []
	for c in hucreler:
		var r: Vector2i = c - merkez
		yeni.append(merkez + Vector2i(-r.y, r.x))
	for itme in [0, -1, 1, -2, 2]:
		var denenen: Array = []
		for c in yeni:
			denenen.append(c + Vector2i(itme, 0))
		if _uygun(denenen):
			hucreler = denenen
			return


func birak() -> void:
	while _kaydir(Vector2i(0, 1)):
		pass
	_kilitle()


func _kilitle() -> void:
	for c in hucreler:
		if c.y >= 0:
			izgara[c.y * SUTUN + c.x] = tip
	var dolu: Array = []
	for y in SATIR:
		var tam := true
		for x in SUTUN:
			if izgara[y * SUTUN + x] == -1:
				tam = false
				break
		if tam:
			dolu.append(y)
	if not dolu.is_empty():
		_flas = dolu.duplicate()
		_flas_sure = 0.18
		for y in dolu:
			for yy in range(y, 0, -1):
				for x in SUTUN:
					izgara[yy * SUTUN + x] = izgara[(yy - 1) * SUTUN + x]
			for x in SUTUN:
				izgara[x] = -1
		satirlar += dolu.size()
		var odul: float = SIRA_ODULU[mini(dolu.size(), 4)]
		puan += int(odul * 10)
		katki.emit("ruzgar", odul)
		bildir(["", "Rüzgar +", "Çift sıra! +", "Üçlü sıra! +", "FIRTINA! +"][mini(dolu.size(), 4)] + str(int(odul)))
		dusme_sure = maxf(0.22, 0.65 - satirlar * 0.012)
	_yeni_parca()


func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		return
	if _flas_sure > 0.0:
		_flas_sure -= delta
	_sayac += delta
	if _sayac >= dusme_sure:
		_sayac = 0.0
		if not _kaydir(Vector2i(0, 1)):
			_kilitle()


func dokun(p: Vector2) -> void:
	match tus_bul(p):
		"dondur":
			dondur()
			return
		"sol":
			_kaydir(Vector2i(-1, 0))
			return
		"sag":
			_kaydir(Vector2i(1, 0))
			return
		"asagi":
			_kaydir(Vector2i(0, 1))
			return
		"birak":
			birak()
			return
	var tahta := Rect2(TAHTA, Vector2(SUTUN * H, SATIR * H))
	if tahta.has_point(p):
		var x := (p.x - TAHTA.x) / H
		var minx := 99
		var maxx := -99
		for c in hucreler:
			minx = mini(minx, c.x)
			maxx = maxi(maxx, c.x)
		if x < minx:
			_kaydir(Vector2i(-1, 0))
		elif x >= maxx + 1:
			_kaydir(Vector2i(1, 0))
		else:
			dondur()


func _gorunen_dusme() -> Array:
	var golge := hucreler.duplicate()
	while true:
		var yeni: Array = []
		for c in golge:
			yeni.append(c + Vector2i(0, 1))
		if _uygun(yeni):
			golge = yeni
		else:
			break
	return golge


func ciz() -> void:
	var tahta := Rect2(TAHTA, Vector2(SUTUN * H, SATIR * H))
	draw_rect(tahta.grow(4), Color(0.45, 0.3, 0.16))
	draw_rect(tahta, Color(0.08, 0.18, 0.28))
	for x in SUTUN + 1:
		draw_line(TAHTA + Vector2(x * H, 0), TAHTA + Vector2(x * H, SATIR * H), Color(1, 1, 1, 0.05))
	for y in SATIR:
		for x in SUTUN:
			var t := izgara[y * SUTUN + x]
			if t != -1:
				hucre_ciz(Rect2(TAHTA + Vector2(x, y) * H, Vector2(H, H)), RENKLER[t])
	if _flas_sure > 0.0:
		for y in _flas:
			draw_rect(Rect2(TAHTA + Vector2(0, y * H), Vector2(SUTUN * H, H)), Color(1, 1, 0.8, _flas_sure * 4.0))
	for c in _gorunen_dusme():
		draw_rect(Rect2(TAHTA + Vector2(c) * H, Vector2(H, H)).grow(-3), Color(1, 1, 1, 0.12))
	for c in hucreler:
		if c.y >= 0:
			hucre_ciz(Rect2(TAHTA + Vector2(c) * H, Vector2(H, H)), RENKLER[tip])
	# Yan sütun: tuşlar, sıradaki parça, rüzgar
	var sx := 404.0
	var r1 := Rect2(sx, 72, 136, 76)
	tus_ciz(r1, "Döndür")
	tus_ekle(r1, "dondur")
	var r2 := Rect2(sx, 158, 64, 76)
	tus_ciz(r2, "<")
	tus_ekle(r2, "sol")
	var r3 := Rect2(sx + 72, 158, 64, 76)
	tus_ciz(r3, ">")
	tus_ekle(r3, "sag")
	var r4 := Rect2(sx, 244, 64, 76)
	tus_ciz(r4, "v")
	tus_ekle(r4, "asagi")
	var r5 := Rect2(sx + 72, 244, 64, 76)
	tus_ciz(r5, "Bırak", true)
	tus_ekle(r5, "birak")
	metin(Vector2(sx, 356), "Sıradaki", 20, SOLUK)
	for c in SEKILLER[sonraki]:
		hucre_ciz(Rect2(Vector2(sx + 14, 372) + Vector2(c) * 26.0, Vector2(26, 26)), RENKLER[sonraki])
	metin(Vector2(sx, 470), "Sıra: " + str(satirlar), 22)
	metin(Vector2(sx, 500), "Puan: " + str(puan), 22)
	if gemi != null:
		metin(Vector2(sx, 548), "Rüzgar", 20, SOLUK)
		draw_rect(Rect2(sx, 558, 136, 18), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(sx, 558, 136 * gemi.ruzgar / 100.0, 18), Color(0.95, 0.9, 0.6))


## Önizleme/test botu: rastgele birkaç hamle yapar.
func bot_hamle() -> void:
	for i in randi() % 4:
		dondur()
	var d := randi() % 7 - 3
	for i in absi(d):
		_kaydir(Vector2i(signi(d), 0))
	birak()
