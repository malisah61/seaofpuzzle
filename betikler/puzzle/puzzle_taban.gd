extends Control
## Tüm gemi istasyonu puzzle'larının ortak paneli.
## Ekranın sağında açılır; deniz solda görünmeye devam eder.

signal katki(tur: String, miktar: float)
signal kapat_istendi

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
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		accept_event()
		if Rect2(GENISLIK - 58, 8, 50, 50).has_point(p):
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
	metin(Vector2(24, 44), baslik, 30)
	if aciklama != "":
		metin(Vector2(24, size.y - 16), aciklama, 17, SOLUK)
	# Kapat düğmesi
	var kr := Rect2(GENISLIK - 58, 8, 50, 50)
	draw_rect(kr, Color(0.45, 0.15, 0.12))
	draw_line(kr.position + Vector2(14, 14), kr.end - Vector2(14, 14), YAZI, 4.0)
	draw_line(kr.position + Vector2(36, 14), kr.position + Vector2(14, 36), YAZI, 4.0)
	_tusler.clear()
	ciz()
	if _bildirim_sure > 0.0:
		var a := clampf(_bildirim_sure, 0.0, 1.0)
		var r := Rect2(24, size.y * 0.42, GENISLIK - 48, 64)
		draw_rect(r, Color(0, 0, 0, 0.6 * a))
		metin_ortala(r, _bildirim, 28, Color(1, 0.88, 0.4, a))
