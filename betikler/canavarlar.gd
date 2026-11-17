extends Node2D
## DENİZ CANAVARLARI (2. aşama): açık denizde yavaşça dolaşır, yaklaşan gemiye saldırır.
## Savaş tahtasında topla yaralanır ama asıl silah HARPUN'dur (Top puzzle'ında doldurulur).
## Canavar gülle atmaz; yanına gelirse ısırır (Dev Ahtapot ayrıca kollarıyla sarıp bir hamleni çalar).
## Görseller tamamen kodla çizilir (özgün, çizgi film tarzı).

signal saldiri(canavar: Dictionary)

const TURLER := [
	{"tur": "yilan", "ad": "Derin Yılanı", "renk": Color(0.2, 0.62, 0.52)},
	{"tur": "ahtapot", "ad": "Dev Ahtapot", "renk": Color(0.62, 0.32, 0.72)},
]
const ADET := 4
const GORUS := 380.0
const SALDIRI_MESAFE := 140.0

var deniz: Node2D
var gemi: Node2D
var liste: Array = []      # {p, hedef, aci, ad, tur, guc, bekleme, batik, no, canavar}
var etkin := true
var _rng := RandomNumberGenerator.new()
var _zaman := 0.0


func kur() -> void:
	_rng.seed = 1453
	for i in ADET:
		liste.append(_yeni(i))


func _yeni(i: int) -> Dictionary:
	var p := _bos_nokta()
	var t: Dictionary = TURLER[i % TURLER.size()]
	return {
		"p": p, "hedef": p, "aci": _rng.randf() * TAU, "ad": t.ad, "tur": t.tur, "guc": 1 + (i / 2) % 3,
		"bekleme": 0.0, "batik": 0.0, "no": i, "canavar": true,
	}


func _bos_nokta() -> Vector2:
	for deneme in 200:
		var p := Vector2(_rng.randf_range(400, deniz.boyut.x - 400), _rng.randf_range(400, deniz.boyut.y - 400))
		if p.distance_to(deniz.baslangic_noktasi()) < 1600.0:
			continue
		if deniz.carpisma(p).itme == Vector2.ZERO and not deniz.limanda_mi(p):
			return p
	return deniz.boyut * 0.7


## Avlanan canavar dalar; 90 sn sonra başka yerde, daha güçlü çıkar.
func avla(c: Dictionary) -> void:
	c.batik = 90.0
	c.bekleme = 0.0


func gorunur_mu(c: Dictionary) -> bool:
	return c.batik <= 0.0 and deniz.acik_mi(c.p)


func _process(delta: float) -> void:
	_zaman += delta
	if not etkin:
		queue_redraw()
		return
	for c in liste:
		if c.batik > 0.0:
			c.batik -= delta
			if c.batik <= 0.0:
				var y := _yeni(c.no)
				c.p = y.p
				c.hedef = y.p
				c.guc = mini(3, c.guc + 1)
			continue
		c.bekleme = maxf(0.0, c.bekleme - delta)
		var mesafe: float = c.p.distance_to(gemi.position)
		var hiz := 40.0
		var limanda: bool = deniz.limanda_mi(gemi.position)
		if mesafe < GORUS and c.bekleme <= 0.0 and not limanda:
			c.hedef = gemi.position
			hiz = 85.0
		elif c.p.distance_to(c.hedef) < 30.0:
			c.hedef = c.p + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(150, 400)
			c.hedef = c.hedef.clamp(Vector2(250, 250), deniz.boyut - Vector2(250, 250))
		var fark: Vector2 = c.hedef - c.p
		if fark.length() > 1.0:
			c.aci = rotate_toward(c.aci, fark.angle(), 1.4 * delta)
			c.p += Vector2.from_angle(c.aci) * hiz * delta
		var cp: Dictionary = deniz.carpisma(c.p)
		if cp.itme != Vector2.ZERO:
			c.p += cp.itme
			c.hedef = c.p + Vector2.from_angle(_rng.randf() * TAU) * 300.0
		if mesafe < SALDIRI_MESAFE and c.bekleme <= 0.0 and not limanda:
			c.bekleme = 25.0
			saldiri.emit(c)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var ekran := get_viewport_rect().size
	for c in liste:
		if not gorunur_mu(c):
			continue
		if absf(c.p.x - gemi.position.x) > ekran.x + 200 or absf(c.p.y - gemi.position.y) > ekran.y + 200:
			continue   # ekran dışı: çizme (telefon performansı)
		canavar_ciz(self, c.tur, c.p, c.aci, 1.0, _zaman + c.no)
		var yazi: String = c.ad + " (" + str(c.guc) + ")"
		var gen := font.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var yp: Vector2 = c.p + Vector2(-gen / 2.0, -64)
		draw_string_outline(font, yp, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.15, 0.02, 0.2, 0.9))
		draw_string(font, yp, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.75, 1.0))
		if c.p.distance_to(gemi.position) < GORUS and c.bekleme <= 0.0:
			draw_string_outline(font, c.p + Vector2(-6, -86), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0))
			draw_string(font, c.p + Vector2(-6, -86), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.85, 0.4, 1.0))


## Canavarı herhangi bir CanvasItem'ın _draw'ı içinde çizer (deniz ve savaş tahtası ortak kullanır).
## aci: baktığı yön (radyan), olcek: 1 = denizdeki boyut, zaman: animasyon, oran: kalan can (renk solar).
static func canavar_ciz(ci: CanvasItem, tur: String, p: Vector2, aci: float, olcek: float, zaman: float, oran := 1.0) -> void:
	var ileri := Vector2.from_angle(aci)
	var yan := ileri.orthogonal()
	var renk: Color = TURLER[0].renk if tur == "yilan" else TURLER[1].renk
	renk = renk.lerp(Color(0.55, 0.45, 0.45), (1.0 - oran) * 0.5)
	var koyu := renk.darkened(0.35)
	# Su halkaları
	for k in 2:
		var r := (34.0 + k * 14.0 + fmod(zaman * 12.0, 14.0)) * olcek
		ci.draw_arc(p, r, 0, TAU, 24, Color(1, 1, 1, 0.22 - k * 0.08), 2.0 * olcek)
	if tur == "yilan":
		# Sudan çıkan kıvrımlar (kuyruktan başa)
		var parcalar := 7
		for i in range(parcalar, -1, -1):
			var t := float(i) / parcalar
			var q := p - ileri * (t * 70.0 * olcek) + yan * sin(zaman * 3.0 - t * 6.0) * 14.0 * olcek
			var r := lerpf(15.0, 6.0, t) * olcek
			ci.draw_circle(q + Vector2(3, 4) * olcek, r, Color(0, 0, 0, 0.2))
			ci.draw_circle(q, r, koyu if i % 2 == 0 else renk)
			ci.draw_circle(q - yan * r * 0.3, r * 0.45, renk.lightened(0.25))
		# Baş: sırt yüzgeci, gözler, dişler
		var bas := p + ileri * 14.0 * olcek
		ci.draw_colored_polygon(PackedVector2Array([bas - ileri * 30 * olcek, bas - ileri * 6 * olcek + yan * 4 * olcek, bas - ileri * 18 * olcek + yan * 16 * olcek]), Color(0.95, 0.55, 0.25))
		ci.draw_circle(bas, 18.0 * olcek, renk)
		ci.draw_circle(bas + ileri * 10 * olcek, 12.0 * olcek, renk.lightened(0.1))
		for s in [-1.0, 1.0]:
			var g: Vector2 = bas + yan * s * 9.0 * olcek + ileri * 4.0 * olcek
			ci.draw_circle(g, 5.5 * olcek, Color(1, 0.95, 0.6))
			ci.draw_circle(g + ileri * 1.5 * olcek, 2.6 * olcek, Color(0.1, 0.05, 0.05))
			var d: Vector2 = bas + ileri * 20 * olcek + yan * s * 5 * olcek
			ci.draw_colored_polygon(PackedVector2Array([d, d + yan * s * 4 * olcek, d + ileri * 6 * olcek]), Color(1, 1, 0.95))
	else:
		# Dalgalanan 6 kol
		for i in 6:
			var a := aci + PI + (i - 2.5) * 0.42
			var nokta := PackedVector2Array()
			for j in 7:
				var t := float(j) / 6.0
				var dalga := sin(zaman * 3.5 + i * 1.3 + t * 5.0) * 0.5 * t
				nokta.append(p + Vector2.from_angle(a + dalga) * (14.0 + t * 52.0) * olcek)
			ci.draw_polyline(nokta, koyu, 11.0 * olcek)
			ci.draw_polyline(nokta, renk, 7.0 * olcek)
			for j in [2, 4]:
				ci.draw_circle(nokta[j], 2.5 * olcek, renk.lightened(0.4))
		ci.draw_circle(p + Vector2(3, 5) * olcek, 26.0 * olcek, Color(0, 0, 0, 0.2))
		ci.draw_circle(p, 26.0 * olcek, renk)
		ci.draw_circle(p + ileri * 6 * olcek - yan * 8 * olcek, 9.0 * olcek, renk.lightened(0.3))
		for s in [-1.0, 1.0]:
			var g: Vector2 = p + yan * s * 10.0 * olcek + ileri * 10.0 * olcek
			ci.draw_circle(g, 7.0 * olcek, Color(1, 0.95, 0.6))
			ci.draw_circle(g + ileri * 2.0 * olcek, 3.5 * olcek, Color(0.1, 0.05, 0.05))
