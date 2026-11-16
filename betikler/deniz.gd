extends Node2D
## Deniz haritası: adalar, kayalıklar, hazineler ve sis verisi.
## Adalar ve kayalıklar bir kez çizilir; hazine ve sis ayrı düğümlerde canlı çizilir.

const HUCRE := 200.0
const KESIF_YARICAP := 650.0
const ADA_ADLARI := [
	"Martı Adası", "Kırık Pusula", "Mercan Koyu", "Fırtına Burnu", "Yeşil Kaplumbağa",
	"Rom Adası", "Sisli Kayalar", "İnci Körfezi", "Kartal Yuvası", "Tuzlu Liman",
	"Kemik Burnu", "Altın Kum", "Rüzgarlı Tepe", "Yalnız Palmiye", "Kara Mercan", "Ay Koyu",
]

var boyut := Vector2(6000, 6000)
var adalar: Array = []        # {merkez, r, kum, cim, sig, palmiyeler, ad, liman}
var kayaliklar: Array = []    # {merkez, r}
var hazineler: Array = []     # Vector2
var sis_w := 0
var sis_h := 0
var acik := PackedByteArray()
var _rng := RandomNumberGenerator.new()


func olustur(b: Vector2) -> void:
	boyut = b
	_rng.seed = 20261116
	adalar.append(_ada(Vector2(800, 3000), 260.0, "Başlangıç Limanı", true))
	var deneme := 0
	while adalar.size() < 17 and deneme < 2000:
		deneme += 1
		var r := _rng.randf_range(130.0, 330.0)
		var m := Vector2(_rng.randf_range(r + 200, boyut.x - r - 200), _rng.randf_range(r + 200, boyut.y - r - 200))
		if _bos_mu(m, r + 260.0):
			var ad: String = ADA_ADLARI[(adalar.size() - 1) % ADA_ADLARI.size()]
			adalar.append(_ada(m, r, ad, adalar.size() % 4 == 0))
	deneme = 0
	while kayaliklar.size() < 45 and deneme < 3000:
		deneme += 1
		var kr := _rng.randf_range(16.0, 34.0)
		var km := Vector2(_rng.randf_range(150, boyut.x - 150), _rng.randf_range(150, boyut.y - 150))
		if _bos_mu(km, kr + 160.0) and km.distance_to(baslangic_noktasi()) > 500.0:
			kayaliklar.append({"merkez": km, "r": 22.0, "karo": [49, 50, 51][_rng.randi() % 3], "aci": _rng.randf() * TAU})
	deneme = 0
	while hazineler.size() < 32 and deneme < 3000:
		deneme += 1
		var hm := Vector2(_rng.randf_range(150, boyut.x - 150), _rng.randf_range(150, boyut.y - 150))
		if _bos_mu(hm, 120.0):
			hazineler.append(hm)
	sis_w = int(ceil(boyut.x / HUCRE))
	sis_h = int(ceil(boyut.y / HUCRE))
	acik.resize(sis_w * sis_h)
	acik.fill(0)
	queue_redraw()


func _bos_mu(m: Vector2, mesafe: float) -> bool:
	for a in adalar:
		if m.distance_to(a.merkez) < a.r + mesafe:
			return false
	for k in kayaliklar:
		if m.distance_to(k.merkez) < k.r + mesafe * 0.5:
			return false
	return true


const K := 64.0
const V := preload("res://betikler/varlik.gd")
# Kenney Pirate Pack karo numaraları (9 dilim)
const CIMLI := {"sol_ust": 6, "ust": [7, 8], "sag_ust": 9, "sol": [22, 38], "orta": [23, 24, 39, 40], "sag": [25, 41], "sol_alt": 54, "alt": [55, 56], "sag_alt": 57}
const KUMLU := {"sol_ust": 1, "ust": [2], "sag_ust": 3, "sol": [17], "orta": [18, 4, 20], "sag": [19], "sol_alt": 33, "alt": [34], "sag_alt": 35}
const SIG := {"sol_ust": 10, "ust": [11], "sag_ust": 12, "sol": [26], "orta": [27], "sag": [28], "sol_alt": 42, "alt": [43], "sag_alt": 44}


func _secim(kume: Dictionary, x: int, y: int, w: int, h: int) -> int:
	var anahtar := "orta"
	if y == 0:
		anahtar = "sol_ust" if x == 0 else ("sag_ust" if x == w - 1 else "ust")
	elif y == h - 1:
		anahtar = "sol_alt" if x == 0 else ("sag_alt" if x == w - 1 else "alt")
	elif x == 0:
		anahtar = "sol"
	elif x == w - 1:
		anahtar = "sag"
	var v = kume[anahtar]
	if v is Array:
		return v[_rng.randi() % v.size()]
	return v


func _ada(m: Vector2, r: float, ad: String, liman: bool) -> Dictionary:
	var w := clampi(int(round(r / 55.0)), 3, 8)
	var h := clampi(int(round(r / 55.0 * _rng.randf_range(0.7, 1.1))), 3, 7)
	var kose := (m - Vector2(w, h) * K / 2.0).snapped(Vector2(K, K))
	var rect := Rect2(kose, Vector2(w, h) * K)
	var kume := CIMLI if (w >= 4 and h >= 4) else KUMLU
	var karolar: Array = []
	for y in h:
		for x in w:
			karolar.append([kose + Vector2(x, y) * K, _secim(kume, x, y, w, h)])
	var sig: Array = []
	for y in h + 2:
		for x in w + 2:
			sig.append([kose + Vector2(x - 1, y - 1) * K, _secim(SIG, x, y, w + 2, h + 2)])
	var suslar: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var zar := _rng.randf()
			var p := kose + (Vector2(x, y) + Vector2(_rng.randf_range(0.3, 0.7), _rng.randf_range(0.3, 0.7))) * K
			if zar < 0.35:
				suslar.append([p, [70, 71, 72][_rng.randi() % 3], _rng.randf_range(0.8, 1.15), _rng.randf() * TAU])
			elif zar < 0.45:
				suslar.append([p, [65, 66, 67][_rng.randi() % 3], 0.8, _rng.randf() * TAU])
			elif zar < 0.6 and kume == CIMLI:
				suslar.append([p, [87, 88][_rng.randi() % 2], 1.0, _rng.randf() * TAU])
	if liman:
		suslar.append([kose + Vector2(1.5, 1.5) * K, 14, 1.0, 0.0])
	return {
		"merkez": rect.get_center(), "r": rect.size.length() / 2.0, "rect": rect, "ad": ad, "liman": liman,
		"karolar": karolar, "sig": sig, "suslar": suslar,
		"iskele": rect.position + Vector2(w * K, floor(h / 2.0) * K),
	}


func baslangic_noktasi() -> Vector2:
	var r: Rect2 = adalar[0].rect
	return Vector2(r.end.x + 230.0, r.get_center().y + 90.0)


## Gemi çevresindeki sisi açar. Yeni hücre açıldıysa true döner.
func kesfet(p: Vector2) -> bool:
	var degisti := false
	var hr := int(ceil(KESIF_YARICAP / HUCRE))
	var cx := int(p.x / HUCRE)
	var cy := int(p.y / HUCRE)
	for y in range(max(0, cy - hr), min(sis_h, cy + hr + 1)):
		for x in range(max(0, cx - hr), min(sis_w, cx + hr + 1)):
			var i := y * sis_w + x
			if acik[i] == 0:
				var merkez := Vector2((x + 0.5) * HUCRE, (y + 0.5) * HUCRE)
				if merkez.distance_to(p) <= KESIF_YARICAP:
					acik[i] = 1
					degisti = true
	return degisti


func acik_mi(p: Vector2) -> bool:
	var x := int(p.x / HUCRE)
	var y := int(p.y / HUCRE)
	if x < 0 or y < 0 or x >= sis_w or y >= sis_h:
		return false
	return acik[y * sis_w + x] == 1


## Gemiyi karadan ve kayalıklardan iter. {"itme": Vector2, "hasar": float}
func carpisma(p: Vector2) -> Dictionary:
	var itme := Vector2.ZERO
	var hasar := 0.0
	for a in adalar:
		var r: Rect2 = a.rect.grow(18.0)
		if r.has_point(p):
			var sol := p.x - r.position.x
			var sag := r.end.x - p.x
			var ust := p.y - r.position.y
			var alt := r.end.y - p.y
			var en_az := minf(minf(sol, sag), minf(ust, alt))
			if en_az == sol:
				itme.x -= sol
			elif en_az == sag:
				itme.x += sag
			elif en_az == ust:
				itme.y -= ust
			else:
				itme.y += alt
	for k in kayaliklar:
		var d2: Vector2 = p - k.merkez
		var sinir2: float = k.r + 20.0
		if d2.length() < sinir2:
			itme += d2.normalized() * (sinir2 - d2.length() + 10.0)
			hasar = 7.0
	return {"itme": itme, "hasar": hasar}


func hazine_topla(p: Vector2) -> int:
	for i in range(hazineler.size() - 1, -1, -1):
		if p.distance_to(hazineler[i]) < 70.0:
			hazineler.remove_at(i)
			return _rng.randi_range(20, 80)
	return 0


func limanda_mi(p: Vector2) -> bool:
	for a in adalar:
		if a.liman and (a.rect as Rect2).grow(240.0).has_point(p):
			return true
	return false


func _karo_ciz(no: int, p: Vector2) -> void:
	draw_texture_rect(V.karo(no), Rect2(p, Vector2(K, K)), false)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for a in adalar:
		for k in a.sig:
			_karo_ciz(k[1], k[0])
	for a in adalar:
		if a.liman:
			for i in 3:
				_karo_ciz(76, a.iskele + Vector2(i * K, 0))
		for k in a.karolar:
			_karo_ciz(k[1], k[0])
		for su in a.suslar:
			var t: Texture2D = V.karo(su[1])
			draw_set_transform(su[0], su[3], Vector2(su[2], su[2]))
			draw_texture(t, -t.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
		var yazi: String = a.ad
		var gen := font.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var r: Rect2 = a.rect
		var yp := Vector2(r.get_center().x - gen / 2.0, r.end.y + K + 34.0)
		draw_string_outline(font, yp, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, Color(0.08, 0.2, 0.3, 0.85))
		draw_string(font, yp, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.97, 0.88))
	for k in kayaliklar:
		var t: Texture2D = V.karo(k.karo)
		draw_circle(k.merkez, 34.0, Color(1, 1, 1, 0.18))
		draw_set_transform(k.merkez, k.aci, Vector2.ONE)
		draw_texture(t, -t.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
