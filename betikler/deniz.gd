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
			kayaliklar.append({"merkez": km, "r": kr})
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


func _halka(m: Vector2, r: float, oran: float, titresim: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var aci := TAU * float(i) / float(n)
		var rr := r * oran * _rng.randf_range(1.0 - titresim, 1.0 + titresim)
		p.append(m + Vector2.RIGHT.rotated(aci) * rr)
	return p


func _ada(m: Vector2, r: float, ad: String, liman: bool) -> Dictionary:
	var palmiyeler: Array = []
	for i in int(r / 60.0) + 2:
		palmiyeler.append(m + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, r * 0.5))
	return {
		"merkez": m, "r": r, "ad": ad, "liman": liman,
		"sig": _halka(m, r, 1.35, 0.08, 18),
		"kum": _halka(m, r, 1.0, 0.12, 16),
		"cim": _halka(m, r, 0.74, 0.14, 14),
		"palmiyeler": palmiyeler,
	}


func baslangic_noktasi() -> Vector2:
	return adalar[0].merkez + Vector2(adalar[0].r + 160.0, 0.0)


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
		var d: Vector2 = p - a.merkez
		var sinir: float = a.r * 1.12
		if d.length() < sinir:
			itme += d.normalized() * (sinir - d.length())
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
		if a.liman and p.distance_to(a.merkez) < a.r + 240.0:
			return true
	return false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for a in adalar:
		draw_colored_polygon(a.sig, Color(0.35, 0.75, 0.82, 0.35))
		draw_colored_polygon(a.kum, Color(0.89, 0.80, 0.56))
		draw_colored_polygon(a.cim, Color(0.30, 0.58, 0.28))
		for pm in a.palmiyeler:
			draw_circle(pm + Vector2(4, 5), 15.0, Color(0, 0, 0, 0.18))
			draw_circle(pm, 15.0, Color(0.18, 0.45, 0.20))
			draw_circle(pm + Vector2(-4, -4), 7.0, Color(0.32, 0.62, 0.30))
		if a.liman:
			var iskele: Vector2 = a.merkez + Vector2(a.r * 0.85, -14.0)
			draw_rect(Rect2(iskele, Vector2(110, 28)), Color(0.45, 0.30, 0.16))
			for i in 5:
				draw_line(iskele + Vector2(i * 22 + 10, 0), iskele + Vector2(i * 22 + 10, 28), Color(0.32, 0.20, 0.10), 2.0)
			draw_circle(a.merkez + Vector2(-a.r * 0.2, -a.r * 0.2), 22.0, Color(0.75, 0.35, 0.25))
			draw_circle(a.merkez + Vector2(a.r * 0.15, -a.r * 0.3), 18.0, Color(0.85, 0.75, 0.55))
		var yazi: String = a.ad
		var gen := font.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var yp: Vector2 = a.merkez + Vector2(-gen / 2.0, a.r + 52.0)
		draw_string(font, yp + Vector2(2, 2), yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.5))
		draw_string(font, yp, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.96, 0.85))
	for k in kayaliklar:
		draw_circle(k.merkez, k.r + 14.0, Color(0.85, 0.95, 1.0, 0.25))
		draw_circle(k.merkez, k.r, Color(0.36, 0.36, 0.38))
		draw_circle(k.merkez + Vector2(-k.r * 0.3, -k.r * 0.3), k.r * 0.45, Color(0.5, 0.5, 0.52))
