extends "res://betikler/puzzle/puzzle_taban.gd"
## TAMİR istasyonu — gövdedeki delikleri tahta yamalarla kapat.
## Sağdaki tepsiden bir yama seç (tekrar dokununca döner), sonra uyan deliğe dokun.
## Yama deliği tam doldurmalı; yanlış yere koymak zaman kaybettirir.

const N := 8
const H := 46.0
const TAHTA := Vector2(24, 80)
const SEKILLER := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
]
const TEPSI_X := 408.0

var tahta := PackedInt32Array()   # 0 sağlam tahta, -1 yeni yama, >0 delik numarası
var delik_boyu := {}              # delik no -> hücre sayısı
var tepsi: Array = []             # her eleman: Array[Vector2i] (dönmüş şekil) ya da null
var kuyruk: Array = []
var secili := -1
var bolum := 1
var _hata_sure := 0.0
var _hata_hucreler: Array = []


func baslat() -> void:
	baslik = "Tamir"
	aciklama = "Yamayı seç (tekrar dokun: döndür), sonra deliğe dokun"
	_yeni_govde()


func _yeni_govde() -> void:
	tahta.resize(N * N)
	tahta.fill(0)
	delik_boyu.clear()
	kuyruk.clear()
	var hedef_delik := mini(3 + bolum, 8)
	var no := 1
	var deneme := 0
	while no <= hedef_delik and deneme < 400:
		deneme += 1
		var sekil: Array = SEKILLER[randi() % SEKILLER.size()]
		var konum := Vector2i(randi() % N, randi() % N)
		var hucreler: Array = []
		var uygun := true
		for c in sekil:
			var p: Vector2i = c + konum
			if p.x >= N or p.y >= N or not _cevresi_saglam(p):
				uygun = false
				break
			hucreler.append(p)
		if not uygun:
			continue
		for p in hucreler:
			tahta[p.y * N + p.x] = no
		delik_boyu[no] = hucreler.size()
		kuyruk.append(_dondur_rastgele(sekil))
		no += 1
	kuyruk.shuffle()
	tepsi = [null, null, null]
	for i in 3:
		_tepsi_doldur(i)
	secili = -1


## Delikler birbirine değmesin diye çevredeki 8 hücre de sağlam olmalı.
func _cevresi_saglam(p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := p + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N and tahta[q.y * N + q.x] != 0:
				return false
	return true


func _normallestir(hs: Array) -> Array:
	var minx := 99
	var miny := 99
	for c in hs:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
	var sonuc: Array = []
	for c in hs:
		sonuc.append(c - Vector2i(minx, miny))
	return sonuc


func _dondur(hs: Array) -> Array:
	var yeni: Array = []
	for c in hs:
		yeni.append(Vector2i(-c.y, c.x))
	return _normallestir(yeni)


func _dondur_rastgele(hs: Array) -> Array:
	var s := hs.duplicate()
	for i in randi() % 4:
		s = _dondur(s)
	return s


func _tepsi_doldur(i: int) -> void:
	tepsi[i] = kuyruk.pop_back() if not kuyruk.is_empty() else null


func _slot_rect(i: int) -> Rect2:
	return Rect2(TEPSI_X, 80 + i * 124, 132, 114)


func dokun(p: Vector2) -> void:
	for i in 3:
		if _slot_rect(i).has_point(p) and tepsi[i] != null:
			if secili == i:
				tepsi[i] = _dondur(tepsi[i])
			secili = i
			return
	var alan := Rect2(TAHTA, Vector2(N * H, N * H))
	if not alan.has_point(p) or secili == -1:
		return
	var hucre := Vector2i(int((p.x - TAHTA.x) / H), int((p.y - TAHTA.y) / H))
	var sekil: Array = tepsi[secili]
	# Yamanın herhangi bir hücresi dokunulan hücreye gelecek şekilde dene
	for capa in sekil:
		var konum: Vector2i = hucre - capa
		var hedefler: Array = []
		for c in sekil:
			hedefler.append(c + konum)
		if _tam_oturur_mu(hedefler):
			for q in hedefler:
				tahta[q.y * N + q.x] = -1
			puan += hedefler.size() * 10
			katki.emit("tamir", hedefler.size() * 3.0)
			tepsi[secili] = null
			_tepsi_doldur(secili)
			secili = -1
			if _delik_kalmadi():
				bolum += 1
				katki.emit("tamir", 6.0)
				bildir("Gövde onarıldı! +6")
				_yeni_govde()
			return
	# Uymadı
	_hata_hucreler = [hucre]
	_hata_sure = 0.4
	katki.emit("tamir", -0.5)


func _tam_oturur_mu(hs: Array) -> bool:
	var no := -99
	for q in hs:
		if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
			return false
		var d := tahta[q.y * N + q.x]
		if d <= 0:
			return false
		if no == -99:
			no = d
		elif d != no:
			return false
	return delik_boyu.get(no, -1) == hs.size()


func _delik_kalmadi() -> bool:
	for v in tahta:
		if v > 0:
			return false
	return true


func _process(delta: float) -> void:
	super._process(delta)
	if _hata_sure > 0.0:
		_hata_sure -= delta


func ciz() -> void:
	var alan := Rect2(TAHTA, Vector2(N * H, N * H))
	draw_rect(alan.grow(5), Color(0.25, 0.15, 0.08))
	for y in N:
		for x in N:
			var r := Rect2(TAHTA + Vector2(x, y) * H, Vector2(H, H))
			var v := tahta[y * N + x]
			if v == 0:
				draw_rect(r, Color(0.55, 0.36, 0.19))
				draw_line(r.position + Vector2(0, H - 1), r.position + Vector2(H, H - 1), Color(0.35, 0.22, 0.1), 2.0)
				if (x + y) % 3 == 0:
					draw_circle(r.position + Vector2(10, 12), 2.0, Color(0.3, 0.18, 0.08))
			elif v == -1:
				draw_rect(r, Color(0.78, 0.6, 0.36))
				draw_line(r.position + Vector2(4, H / 2), r.position + Vector2(H - 4, H / 2), Color(0.6, 0.44, 0.24), 2.0)
				draw_circle(r.position + Vector2(8, 8), 2.5, Color(0.4, 0.4, 0.42))
				draw_circle(r.position + Vector2(H - 8, H - 8), 2.5, Color(0.4, 0.4, 0.42))
			else:
				draw_rect(r, Color(0.04, 0.08, 0.12))
				draw_rect(r.grow(-6), Color(0.1, 0.3, 0.45, 0.7))
	if _hata_sure > 0.0:
		for h in _hata_hucreler:
			draw_rect(Rect2(TAHTA + Vector2(h) * H, Vector2(H, H)), Color(1, 0.2, 0.15, _hata_sure * 1.5), false, 4.0)
	# Tepsi
	for i in 3:
		var r := _slot_rect(i)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.17, 0.1)
		sb.border_color = Color(1, 0.85, 0.35) if secili == i else Color(0.5, 0.35, 0.2)
		sb.set_border_width_all(4 if secili == i else 2)
		sb.set_corner_radius_all(10)
		draw_style_box(sb, r)
		if tepsi[i] != null:
			var mh := 26.0
			var gen := 0
			var yuk := 0
			for c in tepsi[i]:
				gen = maxi(gen, c.x + 1)
				yuk = maxi(yuk, c.y + 1)
			var baslangic := r.position + (r.size - Vector2(gen, yuk) * mh) / 2.0
			for c in tepsi[i]:
				hucre_ciz(Rect2(baslangic + Vector2(c) * mh, Vector2(mh, mh)), Color(0.82, 0.62, 0.36))
	metin(Vector2(TEPSI_X, 470), "Bölüm " + str(bolum), 22)
	metin(Vector2(TEPSI_X, 500), "Puan: " + str(puan), 22)
	if gemi != null:
		metin(Vector2(TEPSI_X, 548), "Gövde", 20, SOLUK)
		draw_rect(Rect2(TEPSI_X, 558, 132, 18), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(TEPSI_X, 558, 132 * gemi.govde / 100.0, 18), Color(0.55, 0.85, 0.45))


## Önizleme/test botu: uyan bir yamayı bulup yerleştirir.
func bot_hamle() -> void:
	for i in 3:
		if tepsi[i] == null:
			continue
		for rot in 4:
			for y in N:
				for x in N:
					var hs: Array = []
					for c in tepsi[i]:
						hs.append(c + Vector2i(x, y))
					if _tam_oturur_mu(hs):
						secili = i
						dokun(TAHTA + (Vector2(hs[0]) + Vector2(0.5, 0.5)) * H)
						return
			tepsi[i] = _dondur(tepsi[i])
