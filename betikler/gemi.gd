extends Node2D
## Oyuncunun gemisi: dokunulan noktaya gider. Hız rüzgara, gövde hasarına ve sintinedeki suya bağlıdır.
## Yapay zekâ tayfa boş istasyonları yavaşça çalıştırır; oyuncunun puzzle'ları çok daha etkilidir.

signal hasar_aldi(miktar: float)

const V := preload("res://betikler/varlik.gd")
const OLCEK := 0.85
const HIZ_TABAN := 175.0
const DONUS_HIZI := 2.4

var hedef := Vector2.ZERO
var hareketli := false
var govde := 100.0   # gövde sağlığı (Tamir puzzle'ı onarır)
var su := 0.0        # sintinedeki su (Pompa puzzle'ı boşaltır)
var ruzgar := 55.0   # yelken gücü (Yelken puzzle'ı doldurur)
var yapay_tayfa := true
var renk := 4        # oyuncu: mavi yelkenli
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
	# Kenney gemi sprite'ı: pruva aşağı baktığı için -90° döndürülür.
	# Renk: 0 beyaz, 1 siyah, 2 kırmızı, 3 yeşil, 4 mavi, 5 sarı. Hasar arttıkça görüntü değişir.
	var seviye := 0
	if govde < 30.0:
		seviye = 2
	elif govde < 65.0:
		seviye = 1
	var t: Texture2D = V.doku("gemiler/gemi_%02d.png" % (renk + 1 + seviye * 6))
	var sallanma := sin(_zaman * 2.0) * 0.04
	var renk_tonu := Color(1, 1, 1).lerp(Color(0.6, 0.75, 0.95), su / 100.0 * 0.6)
	draw_set_transform(Vector2(4, 6), -PI / 2.0 + sallanma, Vector2(OLCEK, OLCEK))
	draw_texture(t, -t.get_size() / 2.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, -PI / 2.0 + sallanma, Vector2(OLCEK, OLCEK))
	draw_texture(t, -t.get_size() / 2.0, renk_tonu)
	draw_set_transform(Vector2.ZERO)
