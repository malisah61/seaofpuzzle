extends Control
## Tüm gemi istasyonu puzzle'larının ortak paneli.
## Ekranın sağında açılır; deniz solda görünmeye devam eder.

signal katki(tur: String, miktar: float)
signal kapat_istendi

const V := preload("res://betikler/varlik.gd")
const PARCACIK_RENK := {"sari": "Yellow", "beyaz": "White", "mavi": "Blue"}

const GENISLIK := 560.0
const AHSAP := Color(0.17, 0.11, 0.07, 0.96)
const AHSAP_ACIK := Color(0.32, 0.21, 0.12)
const YAZI := Color(1.0, 0.95, 0.84)
const SOLUK := Color(0.85, 0.78, 0.65)

var baslik := "İstasyon"
var aciklama := ""
var puan := 0
var gemi: Node2D   # su seviyesi gibi bilgiler için
var _tusler: Array = []   # [Rect2, ad]
var _bildirim := ""
var _bildirim_sure := 0.0
var _parcaciklar: Array = []   # {doku, p, h, omur, yas, boy, don}
var _patlamalar: Array = []    # {p, metin, renk, yas, aci}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -GENISLIK
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	baslat()


## Alt sınıflar puzzle'ı burada kurar.
func baslat() -> void:
	pass


## Alt sınıflar dokunuşları burada işler (panel içi koordinat).
func dokun(_p: Vector2) -> void:
	pass


## Alt sınıflar tahtayı burada çizer.
func ciz() -> void:
	pass


func bildir(metin: String) -> void:
	_bildirim = metin
	_bildirim_sure = 1.4


func _process(delta: float) -> void:
	if _bildirim_sure > 0.0:
		_bildirim_sure -= delta
	for i in range(_parcaciklar.size() - 1, -1, -1):
		var q: Dictionary = _parcaciklar[i]
		q.yas += delta
		q.h.y += 700.0 * delta
		q.p += q.h * delta
		q.don += delta * 4.0
		if q.yas >= q.omur:
			_parcaciklar.remove_at(i)
	for i in range(_patlamalar.size() - 1, -1, -1):
		_patlamalar[i].yas += delta
		if _patlamalar[i].yas > 0.9:
			_patlamalar.remove_at(i)
	queue_redraw()


## Kenney parıltılarıyla küçük bir patlama (eşleşme, sıra silme, yama).
func parcacik_patlat(merkez: Vector2, renk := "sari", adet := 8, guc := 260.0) -> void:
	var kod: String = PARCACIK_RENK.get(renk, "Yellow")
	for i in adet:
		var no := randi_range(1, 7)
		_parcaciklar.append({
			"doku": V.doku("parcacik/particle%s_%d.png" % [kod, no]),
			"p": merkez, "h": Vector2.from_angle(randf() * TAU) * randf_range(guc * 0.4, guc) + Vector2(0, -guc * 0.6),
			"omur": randf_range(0.45, 0.8), "yas": 0.0, "boy": randf_range(0.08, 0.16), "don": randf() * TAU,
		})
	if _parcaciklar.size() > 160:
		_parcaciklar = _parcaciklar.slice(_parcaciklar.size() - 160)


## Çizgi roman tarzı patlama yazısı ("ÇAT!", "BAM!").
func patlama_yazisi(merkez: Vector2, metin: String, renk := Color(1.0, 0.78, 0.2)) -> void:
	_patlamalar.append({"p": merkez, "metin": metin, "renk": renk, "yas": 0.0, "aci": randf_range(-0.25, 0.25)})


func ses_cal(ad: String, db := 0.0) -> void:
	var s := get_tree().get_first_node_in_group("ses")
	if s != null:
		s.cal(ad, db)


func _efektleri_ciz() -> void:
	for q in _parcaciklar:
		var t: Texture2D = q.doku
		var a: float = 1.0 - q.yas / q.omur
		var boyut: Vector2 = t.get_size() * q.boy
		draw_set_transform(q.p, q.don, Vector2.ONE)
		draw_texture_rect(t, Rect2(-boyut / 2.0, boyut), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
	var font := V.font()
	for b in _patlamalar:
		var y: float = b.yas
		var olcek := 0.0
		if y < 0.12:
			olcek = lerpf(0.2, 1.2, y / 0.12)
		elif y < 0.22:
			olcek = lerpf(1.2, 1.0, (y - 0.12) / 0.1)
		else:
			olcek = 1.0
		var a := clampf((0.9 - y) / 0.3, 0.0, 1.0)
		draw_set_transform(b.p, b.aci, Vector2(olcek, olcek))
		var yildiz := PackedVector2Array()
		var golge := PackedVector2Array()
		for i in 24:
			var r := 74.0 if i % 2 == 0 else 46.0
			var v := Vector2.from_angle(TAU * i / 24.0) * Vector2(r * 1.25, r)
			yildiz.append(v)
			golge.append(v * 1.12)
		draw_colored_polygon(golge, Color(0.15, 0.05, 0.02, a * 0.85))
		draw_colored_polygon(yildiz, Color(b.renk, a))
		var s := font.get_string_size(b.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
		var tp := Vector2(-s.x / 2.0, 12)
		draw_string_outline(font, tp, b.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0.25, 0.05, 0.02, a))
		draw_string(font, tp, b.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


## Kenney taşı çizer (renk adı: Red, Blue...; no: 01 kare, 04 elmas, 09 yıldız ...).
func tas_ciz(r: Rect2, renk: String, no := "01", alfa := 1.0) -> void:
	draw_texture_rect(V.doku("puzzle/tile%s_%s.png" % [renk, no]), r, false, Color(1, 1, 1, alfa))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		accept_event()
		if Rect2(GENISLIK - 58, 8, 50, 50).has_point(p):
			ses_cal("tik")
			kapat_istendi.emit()
			return
		dokun(p)


func tus_ekle(r: Rect2, ad: String) -> void:
	_tusler.append([r, ad])


func tus_bul(p: Vector2) -> String:
	for t in _tusler:
		if (t[0] as Rect2).has_point(p):
			return t[1]
	return ""


func tus_ciz(r: Rect2, yazi: String, vurgulu := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.36, 0.18) if vurgulu else AHSAP_ACIK
	sb.border_color = Color(0.85, 0.65, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, r)
	metin_ortala(r, yazi, 22, YAZI)


func metin_ortala(r: Rect2, yazi: String, boy: int, renk: Color) -> void:
	var font := ThemeDB.fallback_font
	var s := font.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy)
	draw_string(font, r.position + Vector2((r.size.x - s.x) / 2.0, (r.size.y + boy * 0.75) / 2.0), yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy, renk)


func metin(p: Vector2, yazi: String, boy: int, renk := YAZI) -> void:
	draw_string(ThemeDB.fallback_font, p, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy, renk)


func hucre_ciz(r: Rect2, renk: Color) -> void:
	draw_rect(r.grow(-2), renk.darkened(0.35))
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 8)), renk)
	draw_rect(Rect2(r.position + Vector2(6, 5), Vector2(r.size.x - 12, 4)), renk.lightened(0.35))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), AHSAP)
	draw_rect(Rect2(0, 0, 6, size.y), Color(0.55, 0.36, 0.18))
	var bf := ThemeDB.fallback_font
	draw_string_outline(bf, Vector2(24, 46), baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 8, Color(0.1, 0.05, 0.02))
	draw_string(bf, Vector2(24, 46), baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.85, 0.4))
	if aciklama != "":
		metin(Vector2(24, size.y - 16), aciklama, 17, SOLUK)
	# Kapat düğmesi
	var kr := Rect2(GENISLIK - 58, 8, 50, 50)
	draw_rect(kr, Color(0.45, 0.15, 0.12))
	draw_line(kr.position + Vector2(14, 14), kr.end - Vector2(14, 14), YAZI, 4.0)
	draw_line(kr.position + Vector2(36, 14), kr.position + Vector2(14, 36), YAZI, 4.0)
	_tusler.clear()
	ciz()
	_efektleri_ciz()
	if _bildirim_sure > 0.0:
		var a := clampf(_bildirim_sure, 0.0, 1.0)
		var r := Rect2(24, size.y * 0.42, GENISLIK - 48, 64)
		draw_rect(r, Color(0, 0, 0, 0.6 * a))
		metin_ortala(r, _bildirim, 28, Color(1, 0.88, 0.4, a))
