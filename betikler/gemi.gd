extends Node2D
## Oyuncunun gemisi: dokunulan noktaya gider. Hız rüzgara, gövde hasarına ve sintinedeki suya bağlıdır.
## Yapay zekâ tayfa boş istasyonları yavaşça çalıştırır; oyuncunun puzzle'ları çok daha etkilidir.

signal hasar_aldi(miktar: float)

const HIZ_TABAN := 175.0
const DONUS_HIZI := 2.4

var hedef := Vector2.ZERO
var hareketli := false
var govde := 100.0   # gövde sağlığı (Tamir puzzle'ı onarır)
var su := 0.0        # sintinedeki su (Pompa puzzle'ı boşaltır)
var ruzgar := 55.0   # yelken gücü (Yelken puzzle'ı doldurur)
var yapay_tayfa := true
var _iz: Array = []  # [konum, yaş]
var _iz_sayac := 0.0
var _zaman := 0.0


func hedef_ver(p: Vector2) -> void:
	hedef = p
	hareketli = true


func hiz_carpani() -> float:
	return (0.4 + 0.6 * ruzgar / 100.0) * (1.0 - 0.55 * su / 100.0) * (0.6 + 0.4 * govde / 100.0)


func hasar_ver(m: float) -> void:
	govde = clampf(govde - m, 0.0, 100.0)
	hasar_aldi.emit(m)


func _process(delta: float) -> void:
	_zaman += delta
	# Doğal yıpranma: seyir rüzgarı tüketir ve gövdeyi yorar.
	if hareketli:
		ruzgar -= 3.2 * delta
		govde -= 0.22 * delta
	# Hasarlı gövde su alır.
	su += (100.0 - govde) * 0.014 * delta
	if yapay_tayfa:
		ruzgar += 1.3 * delta
		govde += 0.12 * delta
		su -= 0.3 * delta
	ruzgar = clampf(ruzgar, 0.0, 100.0)
	govde = clampf(govde, 0.0, 100.0)
	su = clampf(su, 0.0, 100.0)

	if hareketli:
		var fark := hedef - position
		if fark.length() < 10.0:
			hareketli = false
		else:
			rotation = rotate_toward(rotation, fark.angle(), DONUS_HIZI * delta)
			var ileri := Vector2.RIGHT.rotated(rotation)
			var hizalama := maxf(0.15, ileri.dot(fark.normalized()))
			position += ileri * HIZ_TABAN * hiz_carpani() * hizalama * delta
			_iz_sayac += delta
			if _iz_sayac > 0.06:
				_iz_sayac = 0.0
				_iz.append([position - ileri * 36.0, 0.0])
	for i in range(_iz.size() - 1, -1, -1):
		_iz[i][1] += delta
		if _iz[i][1] > 1.6:
			_iz.remove_at(i)
	queue_redraw()


func _draw() -> void:
	# Köpük izi (dünya koordinatından yerel koordinata çevrilir)
	for nokta in _iz:
		var yas: float = nokta[1]
		var p := to_local(nokta[0])
		draw_circle(p, 6.0 + yas * 14.0, Color(1, 1, 1, 0.35 * (1.0 - yas / 1.6)))
	var sallanma := sin(_zaman * 2.0) * 1.5
	var batma := su / 100.0 * 4.0
	# Gölge
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -8), Vector2(26, -8), Vector2(44, 6), Vector2(26, 20), Vector2(-34, 20), Vector2(-40, 6)]), Color(0, 0, 0, 0.22))
	# Gövde
	var govde_rengi := Color(0.48, 0.29, 0.14).lerp(Color(0.25, 0.16, 0.1), 1.0 - govde / 100.0)
	var gv := PackedVector2Array([Vector2(-38, -14), Vector2(22, -14), Vector2(44, 0), Vector2(22, 14), Vector2(-38, 14), Vector2(-42, 0)])
	draw_colored_polygon(gv, govde_rengi)
	draw_colored_polygon(PackedVector2Array([Vector2(-33, -9), Vector2(20, -9), Vector2(35, 0), Vector2(20, 9), Vector2(-33, 9)]), Color(0.72, 0.55, 0.33))
	for x in [-24, -12, 0, 12]:
		draw_line(Vector2(x, -9), Vector2(x, 9), Color(0.6, 0.44, 0.25), 1.0)
	# Sudaki çizgi (su aldıkça gövde kararır)
	if batma > 0.5:
		draw_polyline(gv + PackedVector2Array([gv[0]]), Color(0.1, 0.35, 0.55, batma / 4.0), 3.0)
	# Hasar çatlakları
	if govde < 60.0:
		draw_line(Vector2(-20, -14), Vector2(-14, -6), Color(0.1, 0.05, 0.02), 2.0)
		draw_line(Vector2(6, 14), Vector2(12, 5), Color(0.1, 0.05, 0.02), 2.0)
	if govde < 30.0:
		draw_line(Vector2(-30, 8), Vector2(-22, 2), Color(0.1, 0.05, 0.02), 2.0)
	# Direkler ve yelkenler (rüzgar dolduğunda şişer)
	var siskinlik := 4.0 + ruzgar / 100.0 * 12.0
	for mx in [-12.0, 12.0]:
		var yelken := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var yy := lerpf(-26.0, 26.0, t)
			yelken.append(Vector2(mx + sin(t * PI) * siskinlik + sallanma * 0.3, yy))
		yelken.append(Vector2(mx - 2, 26))
		yelken.append(Vector2(mx - 2, -26))
		draw_colored_polygon(yelken, Color(0.97, 0.94, 0.86))
		draw_line(Vector2(mx - 2, -27), Vector2(mx - 2, 27), Color(0.35, 0.22, 0.1), 3.0)
		draw_circle(Vector2(mx - 2, 0), 3.5, Color(0.35, 0.22, 0.1))
	# Bayrak
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -2), Vector2(-54, -6 + sallanma), Vector2(-54, 4 + sallanma)]), Color(0.8, 0.15, 0.15))
