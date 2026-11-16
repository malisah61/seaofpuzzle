extends Node2D
## NPC korsan gemileri: açık denizde dolaşır, oyuncuyu görünce kovalar, yakına gelince savaş başlar.
## Sis altındaki korsanlar çizilmez. Yenilen korsan batar ve bir süre sonra başka yerde yeniden doğar.

signal saldiri(korsan: Dictionary)

const V := preload("res://betikler/varlik.gd")
const ADLAR := ["Kara Martı", "Paslı Çapa", "Kızıl Dalga", "Kör Ahtapot", "Yırtık Sancak", "Tuzlu Diş", "Gece Köpeği", "Demir Kanca"]
const ADET := 6
const GORUS := 520.0
const SALDIRI_MESAFE := 150.0

var deniz: Node2D
var gemi: Node2D
var liste: Array = []      # {p, hedef, aci, ad, renk, guc, bekleme, batik, dogus}
var etkin := true          # savaş sırasında dolaşma durur
var _rng := RandomNumberGenerator.new()
var _zaman := 0.0


func kur() -> void:
	_rng.seed = 61
	for i in ADET:
		liste.append(_yeni(i))


func _yeni(i: int) -> Dictionary:
	var p := _bos_nokta()
	return {
		"p": p, "hedef": p, "aci": _rng.randf() * TAU, "ad": ADLAR[i % ADLAR.size()],
		"renk": [1, 2][i % 2], "guc": 1 + i % 3, "bekleme": 0.0, "batik": 0.0, "no": i,
	}


func _bos_nokta() -> Vector2:
	for deneme in 200:
		var p := Vector2(_rng.randf_range(300, deniz.boyut.x - 300), _rng.randf_range(300, deniz.boyut.y - 300))
		if p.distance_to(deniz.baslangic_noktasi()) < 1300.0:
			continue
		if deniz.carpisma(p).itme == Vector2.ZERO and not deniz.limanda_mi(p):
			return p
	return deniz.boyut * 0.5


## Savaşta yenilen korsan batar; 60 sn sonra başka yerde yeniden doğar.
func batir(k: Dictionary) -> void:
	k.batik = 60.0
	k.bekleme = 0.0


func _process(delta: float) -> void:
	_zaman += delta
	if not etkin:
		queue_redraw()
		return
	for k in liste:
		if k.batik > 0.0:
			k.batik -= delta
			if k.batik <= 0.0:
				var y := _yeni(k.no)
				k.p = y.p
				k.hedef = y.p
				k.guc = mini(3, k.guc + 1)
			continue
		k.bekleme = maxf(0.0, k.bekleme - delta)
		var mesafe: float = k.p.distance_to(gemi.position)
		var hiz := 60.0
		if mesafe < GORUS and k.bekleme <= 0.0 and not deniz.limanda_mi(gemi.position):
			k.hedef = gemi.position   # kovala
			hiz = 105.0
		elif k.p.distance_to(k.hedef) < 30.0:
			k.hedef = k.p + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(200, 600)
			k.hedef = k.hedef.clamp(Vector2(200, 200), deniz.boyut - Vector2(200, 200))
		var fark: Vector2 = k.hedef - k.p
		if fark.length() > 1.0:
			k.aci = rotate_toward(k.aci, fark.angle(), 1.8 * delta)
			k.p += Vector2.from_angle(k.aci) * hiz * delta
		var c: Dictionary = deniz.carpisma(k.p)
		if c.itme != Vector2.ZERO:
			k.p += c.itme
			k.hedef = k.p + Vector2.from_angle(_rng.randf() * TAU) * 300.0
		if mesafe < SALDIRI_MESAFE and k.bekleme <= 0.0 and not deniz.limanda_mi(gemi.position):
			k.bekleme = 20.0
			saldiri.emit(k)
	queue_redraw()


func gorunur_mu(k: Dictionary) -> bool:
	return k.batik <= 0.0 and deniz.acik_mi(k.p)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var ekran := get_viewport_rect().size
	var kamera_merkez := gemi.position
	for k in liste:
		if not gorunur_mu(k):
			continue
		if absf(k.p.x - kamera_merkez.x) > ekran.x + 200 or absf(k.p.y - kamera_merkez.y) > ekran.y + 200:
			continue   # ekran dışı: çizme (telefon performansı)
		var t: Texture2D = V.doku("gemiler/gemi_%02d.png" % (k.renk + 1))
		var sallanma := sin(_zaman * 2.0 + k.no) * 0.05
		draw_set_transform(k.p + Vector2(4, 6), k.aci - PI / 2.0 + sallanma, Vector2(0.8, 0.8))
		draw_texture(t, -t.get_size() / 2.0, Color(0, 0, 0, 0.22))
		draw_set_transform(k.p, k.aci - PI / 2.0 + sallanma, Vector2(0.8, 0.8))
		draw_texture(t, -t.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
		var yazi_s: String = "Korsan " + k.ad + " (" + str(k.guc) + ")"
		var gen := font.get_string_size(yazi_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var yp: Vector2 = k.p + Vector2(-gen / 2.0, -62)
		draw_string_outline(font, yp, yazi_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.25, 0.02, 0.02, 0.9))
		draw_string(font, yp, yazi_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.75, 0.65))
		# Kovalama uyarısı
		if k.p.distance_to(gemi.position) < GORUS and k.bekleme <= 0.0:
			draw_string_outline(font, k.p + Vector2(-6, -84), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0))
			draw_string(font, k.p + Vector2(-6, -84), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.3, 0.2))
