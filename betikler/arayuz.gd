extends CanvasLayer
## Ekran arayüzü: gemi göstergeleri, altın, istasyon tuşları, mini harita ve bildirimler.

signal istasyon_secildi(ad: String)

var oyun: Node2D
var gostergeler: Control
var mini_harita: Control
var tuslar: VBoxContainer
var bildirim: Label
var _bildirim_sure := 0.0
var _tus_listesi := {}


class Gostergeler extends Control:
	var oyun: Node2D

	func _process(_d: float) -> void:
		queue_redraw()

	func _cubuk(y: float, ad: String, deger: float, renk: Color) -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(14, y + 17), ad, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.85))
		var r := Rect2(92, y + 2, 200, 18)
		draw_rect(r, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(r.position, Vector2(r.size.x * deger / 100.0, r.size.y)), renk)
		draw_string(font, Vector2(r.end.x - 40, y + 17), str(int(deger)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

	func _draw() -> void:
		if oyun == null:
			return
		var g: Node2D = oyun.gemi
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.07, 0.05, 0.78)
		sb.set_corner_radius_all(12)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		_cubuk(10, "Gövde", g.govde, Color(0.55, 0.85, 0.45))
		_cubuk(36, "Su", g.su, Color(0.3, 0.6, 0.95))
		_cubuk(62, "Rüzgar", g.ruzgar, Color(0.95, 0.9, 0.6))
		var font := ThemeDB.fallback_font
		draw_circle(Vector2(24, 104), 9, Color(1, 0.8, 0.25))
		draw_string(font, Vector2(40, 111), str(oyun.altin) + " altın", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.88, 0.45))
		draw_string(font, Vector2(170, 111), "Hız %" + str(int(g.hiz_carpani() * 100)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.85))


class MiniHarita extends Control:
	var oyun: Node2D
	var _sayac := 0.0

	func _process(d: float) -> void:
		_sayac += d
		if _sayac > 0.2:
			_sayac = 0.0
			queue_redraw()

	func _draw() -> void:
		if oyun == null:
			return
		var dz: Node2D = oyun.deniz
		var olcek: Vector2 = size / dz.boyut
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.58, 0.78, 0.92))
		for a in dz.adalar:
			if dz.acik_mi(a.merkez):
				var ar: Rect2 = a.rect
				draw_rect(Rect2(ar.position * olcek, ar.size * olcek), Color(0.95, 0.6, 0.35) if a.liman else Color(0.85, 0.78, 0.5))
		var hs: Vector2 = 200.0 * olcek
		for y in dz.sis_h:
			for x in dz.sis_w:
				if dz.acik[y * dz.sis_w + x] == 0:
					draw_rect(Rect2(Vector2(x, y) * hs, hs + Vector2(0.5, 0.5)), Color(0.02, 0.05, 0.09, 0.9))
		var g: Node2D = oyun.gemi
		draw_circle(g.position * olcek, 4.5, Color(0.3, 1, 0.4))
		if g.hareketli:
			draw_line(g.position * olcek, g.hedef * olcek, Color(1, 1, 1, 0.5), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.65, 0.35), false, 2.0)


func kur(o: Node2D) -> void:
	oyun = o
	layer = 10
	gostergeler = Gostergeler.new()
	gostergeler.oyun = o
	gostergeler.position = Vector2(16, 16)
	gostergeler.size = Vector2(310, 124)
	gostergeler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gostergeler)

	tuslar = VBoxContainer.new()
	tuslar.position = Vector2(16, 156)
	tuslar.add_theme_constant_override("separation", 10)
	add_child(tuslar)
	for bilgi in [["yelken", "Yelken"], ["tamir", "Tamir"], ["pompa", "Pompa"], ["top", "Top (yakında)"]]:
		var b := Button.new()
		b.text = bilgi[1]
		b.custom_minimum_size = Vector2(170, 62)
		b.add_theme_font_size_override("font_size", 24)
		for durum in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.21, 0.12, 0.92) if durum != "pressed" else Color(0.55, 0.36, 0.18)
			if durum == "disabled":
				sb.bg_color = Color(0.2, 0.17, 0.15, 0.7)
			sb.border_color = Color(0.85, 0.65, 0.35)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(12)
			b.add_theme_stylebox_override(durum, sb)
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
		b.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.5))
		b.disabled = bilgi[0] == "top"
		var ad: String = bilgi[0]
		b.pressed.connect(func(): istasyon_secildi.emit(ad))
		tuslar.add_child(b)
		_tus_listesi[ad] = b

	mini_harita = MiniHarita.new()
	mini_harita.oyun = o
	mini_harita.size = Vector2(170, 170)
	mini_harita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mini_harita)

	bildirim = Label.new()
	bildirim.add_theme_font_size_override("font_size", 30)
	bildirim.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	bildirim.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	bildirim.add_theme_constant_override("outline_size", 8)
	bildirim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bildirim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bildirim)


func istasyon_vurgula(ad: String) -> void:
	for k in _tus_listesi:
		var b: Button = _tus_listesi[k]
		b.modulate = Color(1.25, 1.15, 0.8) if k == ad else Color(1, 1, 1)


func bildir(metin: String) -> void:
	bildirim.text = metin
	_bildirim_sure = 2.2


func _process(delta: float) -> void:
	var ekran := get_viewport().get_visible_rect().size
	mini_harita.position = Vector2(16, ekran.y - mini_harita.size.y - 16)
	var sag_bosluk: float = oyun.panel_genisligi() if oyun != null else 0.0
	bildirim.size = Vector2(ekran.x - sag_bosluk, 40)
	bildirim.position = Vector2(0, 24)
	if _bildirim_sure > 0.0:
		_bildirim_sure -= delta
		bildirim.modulate.a = clampf(_bildirim_sure, 0.0, 1.0)
	else:
		bildirim.modulate.a = 0.0


## Dokunulan nokta bir arayüz öğesinin üstünde mi?
func ekran_dolu(p: Vector2) -> bool:
	if Rect2(tuslar.position, tuslar.size).has_point(p):
		return true
	if Rect2(mini_harita.position, mini_harita.size).has_point(p):
		return true
	if Rect2(gostergeler.position, gostergeler.size).has_point(p):
		return true
	return false
