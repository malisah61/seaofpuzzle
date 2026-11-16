extends Node2D
## Sea of Puzzle — ana oyun.
## Denizde dokunulan yere yelken açılır; gemi istasyonları (Yelken, Tamir, Pompa) puzzle ile çalışır.
## Komut satırı: -- --onizleme=klasor  (ekran görüntüsü alır)  |  -- --deneme  (kısa çalışma testi)

const DUNYA := Vector2(6000, 6000)
const DenizBetik := preload("res://betikler/deniz.gd")
const SisBetik := preload("res://betikler/sis.gd")
const HazineBetik := preload("res://betikler/hazineler.gd")
const GemiBetik := preload("res://betikler/gemi.gd")
const ArayuzBetik := preload("res://betikler/arayuz.gd")
const SesBetik := preload("res://betikler/ses.gd")
const PUZZLELER := {
	"yelken": preload("res://betikler/puzzle/yelken.gd"),
	"tamir": preload("res://betikler/puzzle/tamir.gd"),
	"pompa": preload("res://betikler/puzzle/pompa.gd"),
}

var deniz: Node2D
var sis: Node2D
var hazineler: Node2D
var gemi: Node2D
var kamera: Camera2D
var arayuz: CanvasLayer
var altin := 0
var acik_istasyon := ""
var _paneller := {}
var _carpisma_bekleme := 0.0
var _limanda := false
var ses: Node


func _ready() -> void:
	ses = SesBetik.new()
	add_child(ses)
	var su := ColorRect.new()
	su.size = DUNYA
	var mat := ShaderMaterial.new()
	mat.shader = load("res://betikler/su.gdshader")
	su.material = mat
	su.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(su)

	deniz = DenizBetik.new()
	add_child(deniz)
	deniz.olustur(DUNYA)

	hazineler = HazineBetik.new()
	hazineler.deniz = deniz
	add_child(hazineler)

	gemi = GemiBetik.new()
	gemi.position = deniz.baslangic_noktasi()
	gemi.hasar_aldi.connect(_hasar_aldi)
	add_child(gemi)

	sis = SisBetik.new()
	sis.deniz = deniz
	sis.z_index = 20
	add_child(sis)

	kamera = Camera2D.new()
	kamera.position_smoothing_enabled = true
	kamera.position_smoothing_speed = 6.0
	kamera.limit_left = 0
	kamera.limit_top = 0
	kamera.limit_right = int(DUNYA.x)
	kamera.limit_bottom = int(DUNYA.y)
	gemi.add_child(kamera)
	kamera.make_current()

	arayuz = ArayuzBetik.new()
	add_child(arayuz)
	arayuz.kur(self)
	arayuz.istasyon_secildi.connect(istasyon_ac)

	deniz.kesfet(gemi.position)
	sis.queue_redraw()
	arayuz.bildir("Denize dokun, yelken aç!")

	var argumanlar := OS.get_cmdline_user_args()
	for a in argumanlar:
		if a.begins_with("--onizleme="):
			_onizleme(a.trim_prefix("--onizleme="))
		elif a == "--deneme":
			_test()


func panel_genisligi() -> float:
	return 560.0 if acik_istasyon != "" else 0.0


func istasyon_ac(ad: String) -> void:
	if acik_istasyon == ad:
		istasyon_kapat()
		return
	if acik_istasyon != "":
		_paneller[acik_istasyon].visible = false
	ses.cal("ac", -8.0)
	if not _paneller.has(ad):
		var p: Control = PUZZLELER[ad].new()
		p.gemi = gemi
		p.katki.connect(_katki)
		p.kapat_istendi.connect(istasyon_kapat)
		arayuz.add_child(p)
		_paneller[ad] = p
	_paneller[ad].visible = true
	acik_istasyon = ad
	arayuz.istasyon_vurgula(ad)


func istasyon_kapat() -> void:
	if acik_istasyon != "":
		_paneller[acik_istasyon].visible = false
	acik_istasyon = ""
	arayuz.istasyon_vurgula("")


func _katki(tur: String, miktar: float) -> void:
	match tur:
		"ruzgar":
			gemi.ruzgar = clampf(gemi.ruzgar + miktar, 0.0, 100.0)
		"tamir":
			gemi.govde = clampf(gemi.govde + miktar, 0.0, 100.0)
		"pompa":
			gemi.su = clampf(gemi.su - miktar, 0.0, 100.0)


func _hasar_aldi(m: float) -> void:
	if m >= 5.0:
		ses.cal("carpma", -4.0)
		arayuz.bildir("Kayalığa çarptın! Gövde -" + str(int(m)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = event.position
		var ekran := get_viewport().get_visible_rect().size
		if acik_istasyon != "" and p.x > ekran.x - panel_genisligi():
			return
		if arayuz.ekran_dolu(p):
			return
		gemi.hedef_ver(get_canvas_transform().affine_inverse() * p)
		ses.cal("tik", -12.0)


func _process(delta: float) -> void:
	# Panel açıkken gemi, görünen sol alanın ortasında kalsın
	kamera.offset.x = lerpf(kamera.offset.x, panel_genisligi() / 2.0, minf(1.0, delta * 6.0))
	if deniz.kesfet(gemi.position):
		sis.queue_redraw()
	var c: Dictionary = deniz.carpisma(gemi.position)
	if c.itme != Vector2.ZERO:
		gemi.position += c.itme
		if c.hasar > 0.0 and _carpisma_bekleme <= 0.0:
			gemi.hasar_ver(c.hasar)
			_carpisma_bekleme = 1.2
			gemi.hareketli = false
	_carpisma_bekleme -= delta
	gemi.position = gemi.position.clamp(Vector2(40, 40), DUNYA - Vector2(40, 40))
	var kazanc: int = deniz.hazine_topla(gemi.position)
	if kazanc > 0:
		altin += kazanc
		ses.cal("altin")
		arayuz.bildir("Hazine! +" + str(kazanc) + " altın")
	var limanda: bool = deniz.limanda_mi(gemi.position)
	if limanda:
		gemi.govde = minf(100.0, gemi.govde + 4.0 * delta)
		gemi.su = maxf(0.0, gemi.su - 4.0 * delta)
	if limanda and not _limanda:
		arayuz.bildir("Limandasın: gemi onarılıyor")
	_limanda = limanda
	if gemi.govde <= 0.0:
		gemi.position = deniz.baslangic_noktasi()
		gemi.hareketli = false
		gemi.govde = 60.0
		gemi.su = 0.0
		arayuz.bildir("Gemi ağır hasar aldı, limana çekildi")


# --- Önizleme ve test -------------------------------------------------------

func _bekle(sn: float) -> void:
	await get_tree().create_timer(sn).timeout


func _goruntu(klasor: String, ad: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(klasor)
	img.save_png(klasor.path_join(ad + ".png"))
	print("ONIZLEME kaydedildi: ", ad)


func _onizleme(klasor: String) -> void:
	if not klasor.is_absolute_path():
		klasor = ProjectSettings.globalize_path("res://").path_join(klasor)
	gemi.hedef_ver(gemi.position + Vector2(-60, -420))
	await _bekle(2.5)
	await _goruntu(klasor, "1_deniz")
	istasyon_ac("yelken")
	for i in 7:
		_paneller["yelken"].bot_hamle()
		await _bekle(0.15)
	await _bekle(0.6)
	await _goruntu(klasor, "2_yelken")
	istasyon_ac("tamir")
	await _bekle(0.3)
	_paneller["tamir"].bot_hamle()
	await _bekle(0.12)
	await _goruntu(klasor, "3_tamir")
	gemi.su = 45.0
	istasyon_ac("pompa")
	await _bekle(0.3)
	_paneller["pompa"].bot_hamle()
	await _bekle(0.38)
	await _goruntu(klasor, "4_pompa")
	get_tree().quit()


func _test() -> void:
	gemi.hedef_ver(gemi.position + Vector2(1500, 400))
	for ad in ["yelken", "tamir", "pompa"]:
		istasyon_ac(ad)
		for i in 30:
			_paneller[ad].bot_hamle()
			await _bekle(0.05)
		await _bekle(0.8)
	istasyon_kapat()
	await _bekle(1.0)
	print("TEST TAMAM | govde=%.1f su=%.1f ruzgar=%.1f altin=%d konum=%s" % [gemi.govde, gemi.su, gemi.ruzgar, altin, str(gemi.position.round())])
	get_tree().quit()
