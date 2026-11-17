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
const KorsanBetik := preload("res://betikler/korsanlar.gd")
const SavasBetik := preload("res://betikler/savas.gd")
const CanavarBetik := preload("res://betikler/canavarlar.gd")
const DuelloBetik := preload("res://betikler/puzzle/duello.gd")
const PUZZLELER := {
	"yelken": preload("res://betikler/puzzle/yelken.gd"),
	"tamir": preload("res://betikler/puzzle/tamir.gd"),
	"pompa": preload("res://betikler/puzzle/pompa.gd"),
	"top": preload("res://betikler/puzzle/top.gd"),
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
var korsanlar: Node2D
var savas: Control
var savasta := false
var _savas_korsan: Dictionary = {}
var son_savas_sonucu := ""
var canavarlar: Node2D
var duello: Control              # rampa düellosu paneli (savaşta kanca tutunca)
var son_duello_sonucu := 0.0


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

	korsanlar = KorsanBetik.new()
	korsanlar.deniz = deniz
	korsanlar.gemi = gemi
	korsanlar.kur()
	korsanlar.saldiri.connect(savas_baslat)
	add_child(korsanlar)

	canavarlar = CanavarBetik.new()
	canavarlar.deniz = deniz
	canavarlar.gemi = gemi
	canavarlar.kur()
	canavarlar.saldiri.connect(savas_baslat)
	add_child(canavarlar)

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
	return 560.0 if acik_istasyon != "" or duello != null else 0.0


func istasyon_ac(ad: String) -> void:
	if duello != null:
		return   # düello sürerken istasyon değiştirilemez
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
		"hareket", "demir", "zincir", "ates", "harpun":
			gemi.jeton_ekle(tur, int(miktar))
		"duello":
			duello_bitti(miktar > 0.0)


# --- Savaş (2. aşama) -------------------------------------------------------

func savas_baslat(k: Dictionary, tohum := -1) -> void:
	if savasta:
		return
	savasta = true
	_savas_korsan = k
	gemi.hareketli = false
	korsanlar.etkin = false
	canavarlar.etkin = false
	ses.cal("carpma", -2.0)
	savas = SavasBetik.new()
	arayuz.add_child(savas)
	arayuz.move_child(savas, 0)   # puzzle panelleri savaş tahtasının üstünde kalsın
	arayuz.savas_modu(true)
	savas.baslat(gemi, k, tohum)
	savas.bitti.connect(savas_bitti)
	savas.istasyon_istendi.connect(istasyon_ac)
	savas.duello_istendi.connect(duello_baslat)
	istasyon_ac("top" if gemi.hareket >= 3 else "yelken")


## Kanca tuttu: sağ panelde rampa düellosu açılır, savaş tahtası bekler.
func duello_baslat(ad: String, guc: int, tohum := -1) -> void:
	if duello != null:
		return
	istasyon_kapat()
	duello = DuelloBetik.new()
	duello.gemi = gemi
	duello.kur(ad, guc, tohum)
	duello.katki.connect(_katki)
	duello.kapat_istendi.connect(func(): duello.teslim())
	arayuz.add_child(duello)
	acik_istasyon = ""


func duello_bitti(kazandi: bool) -> void:
	son_duello_sonucu = 1.0 if kazandi else -1.0
	if duello != null:
		duello.queue_free()
		duello = null
	if savas != null:
		savas.duello_bitti(kazandi)


func savas_bitti(sonuc: String, ganimet: int) -> void:
	if not savasta:
		return
	savasta = false
	son_savas_sonucu = sonuc
	savas.queue_free()
	savas = null
	arayuz.savas_modu(false)
	korsanlar.etkin = true
	canavarlar.etkin = true
	if duello != null:
		duello.queue_free()
		duello = null
	istasyon_kapat()
	var canavar_mi: bool = _savas_korsan.get("canavar", false)
	if sonuc == "zafer":
		altin += ganimet
		if canavar_mi:
			canavarlar.avla(_savas_korsan)
			arayuz.bildir("Canavar avlandı! +" + str(ganimet) + " altın")
		else:
			korsanlar.batir(_savas_korsan)
			arayuz.bildir("Zafer! Korsan battı, +" + str(ganimet) + " altın")
		ses.cal("altin")
	elif sonuc == "kacis":
		_savas_korsan.bekleme = 30.0
		# Kaçan gemi rakipten uzaklaşmış olarak denize döner
		var uzak: Vector2 = (gemi.position - _savas_korsan.p).normalized()
		if uzak == Vector2.ZERO:
			uzak = Vector2.RIGHT
		gemi.position += uzak * 220.0
		arayuz.bildir("Kaçtın! " + str(_savas_korsan.ad) + " geride kaldı")
	else:
		_savas_korsan.bekleme = 30.0


func _hasar_aldi(m: float) -> void:
	if m >= 5.0:
		ses.cal("carpma", -4.0)
		arayuz.bildir("Kayalığa çarptın! Gövde -" + str(int(m)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not savasta:
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
	if savasta:
		return
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
	# 2. aşama: Top puzzle'ı, korsan, savaş tahtası
	gemi.su = 10.0
	istasyon_ac("top")
	await _bekle(0.3)
	_paneller["top"].bot_hamle()
	await _bekle(0.9)
	_paneller["top"].bot_hamle(false)
	await _bekle(0.1)
	await _goruntu(klasor, "5_top")
	_paneller["top"].doldur()
	istasyon_kapat()
	var k: Dictionary = korsanlar.liste[1]
	k.p = gemi.position + Vector2(330, -40)
	k.aci = PI
	k.bekleme = 0.0
	await _bekle(0.35)
	await _goruntu(klasor, "6_korsan")
	gemi.jeton_ekle("hareket", 8)
	gemi.jeton_ekle("demir", 4)
	gemi.jeton_ekle("zincir", 1)
	gemi.jeton_ekle("ates", 1)
	savas_baslat(k, 7)
	istasyon_kapat()
	await _bekle(1.8)
	savas.bot_plan()
	await _bekle(0.2)
	await _goruntu(klasor, "7_savas")
	istasyon_ac("top")
	# Görüntü için rakibi bordaya yakın bir yere koy
	savas.rakip.p = Vector2i(7, 11)
	savas.rakip.yon = 0
	savas.rakip_plan = savas._planla(savas.rakip, savas.oyuncu.p, 4, ["demir", "zincir"])
	for i in 4:
		if savas.plan[i].h != "":
			savas._slot_tikla(i, "orta")
	savas.hareket_ekle("ileri")
	savas.secili_mermi = "ates"
	savas.atis_degistir(0, "sag")
	savas.sure = 0.0
	# Gülleler uçarken görüntü al
	var bekleme := 0.0
	while bekleme < 12.0 and not (savas.asama == "cozum" and savas._faz == 2 and not savas._toplar.is_empty() and savas._faz_t > 0.45):
		await _bekle(0.03)
		bekleme += 0.03
	await _goruntu(klasor, "8_savas_atis")
	# Rampa düellosu (kanca)
	istasyon_kapat()
	savas.asama = "duello"
	duello_baslat(str(k.ad), 2, 5)
	for i in 4:
		duello._rakip_hamle()
	for i in 8:
		duello.bot_hamle()
		await _bekle(0.1)
	await _bekle(0.5)
	duello.bot_hamle()
	await _bekle(0.12)
	await _goruntu(klasor, "9_duello")
	duello._bitir(true, "Rakibin yığını taştı!")
	var b2 := 0.0
	while savas != null and savas.asama != "son" and b2 < 6.0:
		await _bekle(0.05)
		b2 += 0.05
	await _bekle(0.6)
	await _goruntu(klasor, "10_savas_ozet")
	while savasta:
		await _bekle(0.1)
	# Deniz canavarı ve harpun
	gemi.govde = 90.0
	var c: Dictionary = canavarlar.liste[1]
	c.p = gemi.position + Vector2(320, 30)
	c.aci = PI
	c.bekleme = 8.0
	await _bekle(0.5)
	await _goruntu(klasor, "11_canavar")
	gemi.jeton_ekle("harpun", 4)
	gemi.jeton_ekle("hareket", 6)
	savas_baslat(c, 11)
	istasyon_kapat()
	await _bekle(1.8)
	savas.rakip.p = Vector2i(5, 11)
	savas.rakip.yon = 3
	for i in 4:
		savas.rakip_plan[i] = {"h": "", "sol": "", "sag": ""}
	for i in 4:
		if savas.plan[i].h != "":
			savas._slot_tikla(i, "orta")
	savas.hareket_ekle("ileri")
	savas.secili_mermi = "harpun"
	savas.atis_degistir(0, "sag")
	savas.sure = 0.0
	var b3 := 0.0
	while b3 < 12.0 and not (savas.asama == "cozum" and savas._faz == 2 and not savas._toplar.is_empty() and savas._faz_t > 0.5):
		await _bekle(0.03)
		b3 += 0.03
	await _goruntu(klasor, "12_canavar_savas")
	get_tree().quit()


func _test() -> void:
	gemi.hedef_ver(gemi.position + Vector2(1500, 400))
	for ad in ["yelken", "tamir", "pompa", "top"]:
		istasyon_ac(ad)
		for i in 30:
			_paneller[ad].bot_hamle()
			await _bekle(0.05)
		await _bekle(0.8)
	istasyon_kapat()
	await _bekle(1.0)
	# Savaş testi: bot oyuncu korsanla savaşır (zaman 4 kat hızlı)
	var mermi_once: int = gemi.mermi.demir + gemi.mermi.zincir + gemi.mermi.ates
	print("TEST jetonlar: hareket=%d mermi=%s" % [gemi.hareket, str(gemi.mermi)])
	Engine.time_scale = 4.0
	gemi.govde = 100.0
	var k: Dictionary = korsanlar.liste[0]
	savas_baslat(k, 3)
	var tur_sayisi := 0
	var son_istatistik := {}
	while savasta and tur_sayisi < 10:
		await _bekle(0.3)
		if not savasta:
			break
		son_istatistik = savas.istatistik.duplicate()
		if savas.asama == "plan":
			_paneller["yelken"].bot_hamle()
			if not _paneller.has("top"):
				istasyon_ac("top")
			_paneller["top"].bot_hamle()
			_paneller["top"].bot_hamle()
			for ad in ["tamir", "pompa"]:
				if _paneller.has(ad):
					_paneller[ad].bot_hamle()
			gemi.jeton_ekle("hareket", 3)   # test botu Yelken'de insan kadar hızlı değil
			savas.bot_plan()
			savas.sure = 0.0
			tur_sayisi += 1
	if savasta:
		print("TEST savaş 10 turda bitmedi: rakip can=%.0f govde=%.0f atışlar=%s mermi=%s" % [savas.rakip.can, gemi.govde, str(savas.istatistik), str(gemi.mermi)])
		savas_bitti("kacis", 0)
	else:
		print("TEST savaş bitti: sonuç=%s tur=%d altin=%d govde=%.0f atışlar=%s" % [son_savas_sonucu, tur_sayisi, altin, gemi.govde, str(son_istatistik)])
	# Kaçış testi: kenardan dışarı sürmek savaşı bitirir
	gemi.govde = 100.0
	savas_baslat(korsanlar.liste[3], 4)
	await _bekle(0.3)
	savas.oyuncu.p = Vector2i(0, 8)
	savas.oyuncu.yon = 3
	savas.harita[8 * 16] = 0
	gemi.jeton_ekle("hareket", 2)
	savas.hareket_ekle("ileri")
	savas.sure = 0.0
	var bekle := 0.0
	while savasta and bekle < 12.0:
		await _bekle(0.1)
		bekle += 0.1
	print("TEST kaçış: sonuç=%s" % son_savas_sonucu)
	if son_savas_sonucu != "kacis":
		push_error("Kaçış çalışmadı")
	# Rampa düellosu testi: kanca at, bot düello oynar
	gemi.govde = 100.0
	savas_baslat(korsanlar.liste[4], 8)
	await _bekle(0.3)
	if savas.asama == "plan":
		savas.rakip.p = savas.oyuncu.p + Vector2i(1, 0)
		savas.kanca_at()
	bekle = 0.0
	var hamle := 0
	while duello != null and bekle < 60.0:
		duello.bot_hamle()
		hamle += 1
		await _bekle(0.3)
		bekle += 0.3
	bekle = 0.0
	while savasta and son_duello_sonucu > 0.0 and bekle < 8.0:
		await _bekle(0.1)
		bekle += 0.1
	print("TEST düello: sonuç=%s hamle=%d savaş sonucu=%s" % [str(son_duello_sonucu), hamle, son_savas_sonucu if not savasta else "sürüyor"])
	if son_duello_sonucu == 0.0:
		push_error("Düello bitmedi")
	if savasta:
		savas_bitti("kacis", 0)
	# Canavar avı: bot harpunla avlar
	gemi.govde = 100.0
	istasyon_ac("top")
	_paneller["top"].secili = 3
	for i in 6:
		_paneller["top"].bot_hamle()
	istasyon_kapat()
	print("TEST harpun=%d" % gemi.mermi.harpun)
	var cv: Dictionary = canavarlar.liste[0]
	var altin_once := altin
	savas_baslat(cv, 6)
	var ct := 0
	var cist := {}
	while savasta and ct < 12:
		await _bekle(0.3)
		if not savasta:
			break
		cist = savas.istatistik.duplicate()
		if savas.asama == "plan":
			_paneller["top"].bot_hamle()
			for ad in ["tamir", "pompa"]:
				_paneller[ad].bot_hamle()
			gemi.jeton_ekle("hareket", 3)
			gemi.jeton_ekle("harpun", 1)
			savas.bot_plan()
			savas.sure = 0.0
			ct += 1
	if savasta:
		print("TEST canavar 12 turda bitmedi: can=%.0f govde=%.0f atışlar=%s" % [savas.rakip.can, gemi.govde, str(savas.istatistik)])
		savas_bitti("kacis", 0)
	else:
		print("TEST canavar: sonuç=%s tur=%d altın+%d atışlar=%s" % [son_savas_sonucu, ct, altin - altin_once, str(cist)])
	Engine.time_scale = 1.0
	print("TEST canavar sayısı=%d" % canavarlar.liste.size())
	print("TEST korsan sayısı=%d ilk korsan=%s mermi_once=%d" % [korsanlar.liste.size(), str(korsanlar.liste[0].p.round()), mermi_once])
	print("TEST TAMAM | govde=%.1f su=%.1f ruzgar=%.1f altin=%d konum=%s" % [gemi.govde, gemi.su, gemi.ruzgar, altin, str(gemi.position.round())])
	get_tree().quit()
