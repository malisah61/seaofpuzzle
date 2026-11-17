extends Control
## SAVAŞ TAHTASI — 16x16 ızgara, 20 saniyelik turlar.
## Her tur 4 adım planlanır: hareket jetonu (Yelken'den) ile Sol / İleri / Sağ, gülle (Top'tan) ile sola / sağa ateş.
## Süre bitince (ya da "Hazır") iki gemi aynı anda hareket eder; rüzgar kareleri iter, girdaplar döndürüp fırlatır,
## kayalar gövdeye zarar verir. Bordadan atılan gülleler 3 kare menzillidir.
## Mühimmat: Demir (9 hasar), Zincir (5 hasar + yelken yırtar: rakip sonraki tur 1 hamle eksik), Ateşli (6 + 2 tur yanma).
## Oyuncunun canı gemi gövdesidir: savaş sürerken Tamir ve Pompa puzzle'ları hayati önemdedir.
## Harpun (Top'ta doldurulur) gemilere zayıf ama deniz canavarlarına 4 kat etkilidir; canavar gülle atmaz, yanına gelince ısırır.
## Rakip gemiye bitişikken KANCA atılırsa Rampa Düellosu (blok düellosu) başlar: kazanan savaşı bitirir.
## Tahtanın kenarından dışarı sürersen savaştan KAÇARSIN.

signal bitti(sonuc: String, ganimet: int)
signal istasyon_istendi(ad: String)
signal duello_istendi(ad: String, guc: int)

const V := preload("res://betikler/varlik.gd")
const N := 16
const C := 34.0
const TAHTA := Vector2(110, 72)
const TUR_SURE := 20.0
const ADIM := 4
const YON := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SU := 0
const KAYA := 1
const RUZGAR := 2
const GIRDAP := 3
const MERMI_HASAR := {"demir": 9.0, "zincir": 5.0, "ates": 6.0, "harpun": 4.0}
const MERMI_ADI := {"demir": "Demir", "zincir": "Zincir", "ates": "Ateşli", "harpun": "Harpun"}
const MERMI_RENK := {"demir": Color(0.2, 0.2, 0.22), "zincir": Color(0.55, 0.6, 0.7), "ates": Color(1.0, 0.45, 0.15), "harpun": Color(0.85, 0.7, 0.45)}
const MERMILER := ["demir", "zincir", "ates", "harpun"]
const CANAVAR_CARPAN := {"demir": 0.6, "zincir": 0.5, "ates": 0.8, "harpun": 4.0}   # canavara karşı hasar çarpanı
const CanavarBetik := preload("res://betikler/canavarlar.gd")
const FAZ_SURE := [0.5, 0.3, 0.55]
const ISTASYONLAR := [["yelken", "Yelken"], ["top", "Top"], ["tamir", "Tamir"], ["pompa", "Pompa"]]

var gemi: Node2D                # oyuncu gemisi (gövde = can, jetonlar)
var korsan: Dictionary          # denizdeki NPC kaydı
var harita := PackedInt32Array()
var ruzgar_yon := PackedInt32Array()
var oyuncu := {}
var rakip := {}
var plan: Array = []
var rakip_plan: Array = []
var asama := "plan"             # plan | cozum | son
var sure := TUR_SURE
var tur := 1
var secili_mermi := "demir"
var sonuc := ""
var ganimet := 0
var _adim := 0
var _faz := 0
var _faz_t := 0.0
var _toplar: Array = []         # uçan gülleler {bas, son, isabet, hedef, tur}
var _patlamalar: Array = []     # {p, yas, buyuk}
var _yazilar: Array = []        # {p, metin, yas, renk}
var _mesaj := ""
var _mesaj_sure := 0.0
var _son_sure := 0.0
var _zaman := 0.0
var _tuslar: Array = []
var _rng := RandomNumberGenerator.new()
var istatistik := {"oyuncu_atis": 0, "oyuncu_isabet": 0, "rakip_atis": 0, "rakip_isabet": 0}
var _su_zemin: ColorRect
var canavar_mi := false         # rakip bir deniz canavarı mı?
var _kacti := false
var _teslim := false            # rampa düellosu kazanıldı
var _kanca_tur := 0             # bu turdan önce yeniden kanca atılamaz
var _sarsinti := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var arka := ColorRect.new()
	arka.color = Color(0.05, 0.12, 0.2)
	arka.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arka.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arka.show_behind_parent = true
	add_child(arka)
	_su_zemin = ColorRect.new()
	_su_zemin.position = TAHTA
	_su_zemin.size = Vector2(N * C, N * C)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://betikler/su.gdshader")
	mat.set_shader_parameter("olcek", 22.0)
	_su_zemin.material = mat
	_su_zemin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_su_zemin.show_behind_parent = true
	add_child(_su_zemin)


## Yeni savaş kurar. tohum verilirse harita tekrarlanabilir (test/önizleme).
func baslat(g: Node2D, k: Dictionary, tohum := -1) -> void:
	gemi = g
	korsan = k
	if tohum >= 0:
		_rng.seed = tohum
	else:
		_rng.randomize()
	_harita_kur()
	canavar_mi = bool(k.get("canavar", false))
	var can := 50.0 + 15.0 * float(k.get("guc", 1))
	if canavar_mi:
		can = 70.0 + 20.0 * float(k.get("guc", 1))
	oyuncu = {"p": Vector2i(3, 12), "yon": 0, "yirtik": 0, "yanma": 0, "kare": []}
	rakip = {"p": Vector2i(12, 3), "yon": 2, "yirtik": 0, "yanma": 0, "kare": [], "can": can, "can_max": can}
	_cizim_sifirla()
	tur = 1
	sonuc = ""
	_tur_baslat()
	mesaj(("CANAVAR! " if canavar_mi else "SAVAŞ! ") + str(k.get("ad", "Korsan")))


func _harita_kur() -> void:
	harita.resize(N * N)
	harita.fill(SU)
	ruzgar_yon.resize(N * N)
	ruzgar_yon.fill(0)
	var yasak := [Vector2i(3, 12), Vector2i(12, 3)]
	# Rüzgar akıntıları: düz şeritler
	for s in 3:
		var yon := _rng.randi() % 4
		var p := Vector2i(_rng.randi_range(2, N - 3), _rng.randi_range(2, N - 3))
		for i in _rng.randi_range(4, 6):
			if _icinde(p) and not _yakin(p, yasak, 1):
				harita[p.y * N + p.x] = RUZGAR
				ruzgar_yon[p.y * N + p.x] = yon
			p += YON[yon]
	var girdap := 0
	while girdap < 3:
		var p := Vector2i(_rng.randi_range(2, N - 3), _rng.randi_range(2, N - 3))
		if harita[p.y * N + p.x] == SU and not _yakin(p, yasak, 2):
			harita[p.y * N + p.x] = GIRDAP
			girdap += 1
	var kaya := 0
	var deneme := 0
	while kaya < 15 and deneme < 400:
		deneme += 1
		var p := Vector2i(_rng.randi_range(0, N - 1), _rng.randi_range(0, N - 1))
		if harita[p.y * N + p.x] == SU and not _yakin(p, yasak, 2):
			harita[p.y * N + p.x] = KAYA
			kaya += 1


func _yakin(p: Vector2i, liste: Array, r: int) -> bool:
	for q in liste:
		if absi(p.x - q.x) <= r and absi(p.y - q.y) <= r:
			return true
	return false


func _icinde(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < N and p.y < N


func _tur(p: Vector2i) -> int:
	return harita[p.y * N + p.x] if _icinde(p) else KAYA


func _merkez(p: Vector2i) -> Vector2:
	return TAHTA + (Vector2(p) + Vector2(0.5, 0.5)) * C


func _aci(yon: int) -> float:
	return Vector2(YON[yon]).angle() - PI / 2.0


func _cizim_sifirla() -> void:
	for s in [oyuncu, rakip]:
		s.kare = [[_merkez(s.p), _aci(s.yon)]]


func mesaj(m: String) -> void:
	_mesaj = m
	_mesaj_sure = 1.6


func _tur_baslat() -> void:
	asama = "plan"
	sure = TUR_SURE
	plan.clear()
	for i in ADIM:
		plan.append({"h": "", "sol": "", "sag": ""})
	rakip_plan = _planla(rakip, oyuncu.p, ADIM - rakip.yirtik, _rakip_mermi())
	# Yanma hasarı tur başında işler
	for s in [oyuncu, rakip]:
		if s.yanma > 0:
			s.yanma -= 1
			_hasar(s, 3.0)
			_yazilar.append({"p": _merkez(s.p), "metin": "YANIYOR", "yas": 0.0, "renk": Color(1, 0.5, 0.15)})
	_rakip_kanca_dene()


## Bitişikteyken (çapraz dahil) kanca atılabilir; canavara kanca atılmaz.
func kanca_mumkun() -> bool:
	if canavar_mi or asama != "plan" or tur < _kanca_tur:
		return false
	return absi(oyuncu.p.x - rakip.p.x) <= 1 and absi(oyuncu.p.y - rakip.p.y) <= 1


func kanca_at() -> bool:
	if not kanca_mumkun():
		mesaj("Kanca için rakibe bitişik ol")
		_ses("hata", -6.0)
		return false
	_duello_baslat("KANCA! Rampaya!")
	return true


## Güçlü korsanlar da bitişik gelince kanca atabilir.
func _rakip_kanca_dene() -> void:
	if canavar_mi or int(korsan.get("guc", 1)) < 2 or tur < _kanca_tur:
		return
	if absi(oyuncu.p.x - rakip.p.x) <= 1 and absi(oyuncu.p.y - rakip.p.y) <= 1 and _rng.randf() < 0.35:
		_duello_baslat("Korsanlar kanca attı!")


func _duello_baslat(m: String) -> void:
	asama = "duello"
	mesaj(m)
	_ses("kanca")
	duello_istendi.emit(str(korsan.get("ad", "Korsan")), int(korsan.get("guc", 1)))


## Rampa düellosu bitti: kazanırsan rakip teslim olur, kaybedersen tayfan geri püskürtülür.
func duello_bitti(kazandi: bool) -> void:
	if asama != "duello":
		return
	_kanca_tur = tur + 2
	if kazandi:
		_teslim = true
		rakip.can = 0.0
		_bitti_mi()
	else:
		asama = "plan"
		_hasar(oyuncu, 10.0)
		mesaj("Rampa püskürtüldü!")


func hamle_hakki() -> int:
	return ADIM - int(oyuncu.yirtik)


# --- Oyuncu girişi ----------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tikla(event.position)


func _tikla(p: Vector2) -> void:
	var ad := ""
	for t in _tuslar:
		if (t[0] as Rect2).has_point(p):
			ad = t[1]
			break
	if ad == "":
		return
	_ses("tik", -8.0)
	if ad.begins_with("ist_"):
		istasyon_istendi.emit(ad.substr(4))
	elif ad.begins_with("mermi_"):
		secili_mermi = ad.substr(6)
	elif asama != "plan":
		return
	elif ad == "hazir":
		sure = 0.0
	elif ad == "kanca":
		kanca_at()
	elif ad in ["sol", "ileri", "sag"]:
		hareket_ekle(ad)
	elif ad.begins_with("slot"):
		var parca := ad.split("_")
		_slot_tikla(int(parca[1]), parca[2])


func hareket_ekle(h: String) -> bool:
	for i in hamle_hakki():
		if plan[i].h == "":
			if gemi.hareket <= 0:
				mesaj("Hareket jetonu yok! Yelken oyna")
				_ses("hata", -6.0)
				return false
			gemi.hareket -= 1
			plan[i].h = h
			return true
	mesaj("Plan dolu")
	return false


func _slot_tikla(i: int, bolge: String) -> void:
	if bolge == "orta":
		if plan[i].h != "":
			plan[i].h = ""
			gemi.hareket += 1
		return
	atis_degistir(i, bolge)


func atis_degistir(i: int, taraf: String) -> bool:
	if plan[i][taraf] != "":
		gemi.mermi[plan[i][taraf]] += 1
		plan[i][taraf] = ""
		return true
	if gemi.mermi[secili_mermi] <= 0:
		mesaj(MERMI_ADI[secili_mermi] + " gülle yok! Top oyna")
		_ses("hata", -6.0)
		return false
	gemi.mermi[secili_mermi] -= 1
	plan[i][taraf] = secili_mermi
	return true


# --- Hareket benzetimi ------------------------------------------------------

func _alt_hamleler(h: String) -> Array:
	match h:
		"ileri":
			return ["F"]
		"sol":
			return ["F", "L", "F"]
		"sag":
			return ["F", "R", "F"]
	return []


## Tek gemiyi diğerini sabit kabul ederek benzetir (plan önizlemesi ve yapay zekâ için).
func _benzet(p: Vector2i, yon: int, h: String, engel: Vector2i) -> Dictionary:
	var carpti := false
	for a in _alt_hamleler(h):
		if a == "L":
			yon = (yon + 3) % 4
		elif a == "R":
			yon = (yon + 1) % 4
		elif not carpti:
			# Çarpan gemi ilerleyemez ama dönüşünü yine yapar (kayaya burnunu dayayıp kilitlenmesin)
			var q: Vector2i = p + YON[yon]
			if _tur(q) == KAYA or q == engel:
				carpti = true
			else:
				p = q
	if not carpti:
		var t := _tur(p)
		if t == RUZGAR:
			var q: Vector2i = p + YON[ruzgar_yon[p.y * N + p.x]]
			if _tur(q) != KAYA and q != engel:
				p = q
		elif t == GIRDAP:
			yon = (yon + 1) % 4
			var q: Vector2i = p + YON[yon]
			if _tur(q) != KAYA and q != engel:
				p = q
	return {"p": p, "yon": yon, "carpti": carpti}


## Bordadan atış: taraf yönünde 3 kareye kadar ilerler. {"son": Vector2i, "isabet": bool}
func _atis_izi(p: Vector2i, yon: int, taraf: String, hedef: Vector2i) -> Dictionary:
	var d: Vector2i = YON[(yon + 3) % 4] if taraf == "sol" else YON[(yon + 1) % 4]
	var q := p
	for i in 3:
		q += d
		if not _icinde(q):
			return {"son": q, "isabet": false}
		if q == hedef:
			return {"son": q, "isabet": true}
		if harita[q.y * N + q.x] == KAYA:
			return {"son": q, "isabet": false}
	return {"son": q, "isabet": false}


## Konum puanı: hedef bordaya 1-3 kare uzaklıkta hizalıysa yüksek.
func _konum_puani(p: Vector2i, yon: int, hedef: Vector2i) -> float:
	var v := hedef - p
	var f: Vector2i = YON[yon]
	var ileri := v.x * f.x + v.y * f.y
	var yan := v.x * -f.y + v.y * f.x
	var puan := -(absf(ileri) * 1.5 + maxf(0.0, absf(yan) - 3.0))
	if yan == 0:
		puan -= 2.0
	if ileri == 0 and absi(yan) >= 1 and absi(yan) <= 3:
		puan += 6.0
	return puan


## Genel planlayıcı (rakip yapay zekâsı ve test botu): 4 adımın tüm hareket dizilerini (4^4) dener.
## Her adımda bordaya hedef gelmesi ödüllenir; kayaya çarpmak cezalandırılır. mermi: kullanılabilecek gülleler.
func _planla(s: Dictionary, hedef: Vector2i, hak: int, mermi: Array) -> Array:
	var secenek := ["", "ileri", "sol", "sag"]
	var av := canavar_mi and s == rakip   # canavar: bordaya değil, dibine girmeye çalışır
	var en_iyi_dizi: Array = ["", "", "", ""]
	var en_iyi_puan := -INF
	for kod in 256:
		var dizi: Array = []
		var hamle := 0
		var k := kod
		for i in ADIM:
			var h: String = secenek[k % 4]
			k /= 4
			if h != "":
				hamle += 1
			dizi.append(h)
		if hamle > hak:
			continue
		var p: Vector2i = s.p
		var yon: int = s.yon
		var puan := 0.0
		for i in ADIM:
			var r := _benzet(p, yon, dizi[i], hedef)
			p = r.p
			yon = r.yon
			if r.carpti:
				puan -= 5.0
			if av:
				if absi(p.x - hedef.x) <= 1 and absi(p.y - hedef.y) <= 1:
					puan += 6.0
			elif _atis_izi(p, yon, "sol", hedef).isabet or _atis_izi(p, yon, "sag", hedef).isabet:
				puan += 6.0
		if av:
			puan -= (absi(p.x - hedef.x) + absi(p.y - hedef.y)) * 1.5
		else:
			puan += _konum_puani(p, yon, hedef) - absi(p.x - hedef.x) * 0.2 - absi(p.y - hedef.y) * 0.2
		puan += _rng.randf() * 1.5 - hamle * 0.1
		if puan > en_iyi_puan:
			en_iyi_puan = puan
			en_iyi_dizi = dizi
	var sonuc_plan: Array = []
	var p: Vector2i = s.p
	var yon: int = s.yon
	var kalan := mermi.duplicate()
	for i in ADIM:
		var r := _benzet(p, yon, en_iyi_dizi[i], hedef)
		p = r.p
		yon = r.yon
		var adim := {"h": en_iyi_dizi[i], "sol": "", "sag": ""}
		for taraf in ["sol", "sag"]:
			# Hedef hatta ya da bir kare yakınında ise ateş et (rakip de hareket ediyor)
			if kalan.is_empty():
				break
			var isabet: bool = _atis_izi(p, yon, taraf, hedef).isabet
			if not isabet:
				for d in YON:
					if _atis_izi(p, yon, taraf, hedef + d).isabet and _rng.randf() < 0.35:
						isabet = true
						break
			if isabet:
				adim[taraf] = kalan.pop_front()
		sonuc_plan.append(adim)
	return sonuc_plan


func _rakip_mermi() -> Array:
	var guc := int(korsan.get("guc", 1))
	var liste: Array = []
	if canavar_mi:
		return liste
	for i in 1 + guc:
		var m := "demir"
		if guc >= 2 and _rng.randf() < 0.3:
			m = "zincir"
		elif guc >= 3 and _rng.randf() < 0.3:
			m = "ates"
		liste.append(m)
	return liste


## Test/önizleme botu: oyuncu yerine jetonlarla plan yapar.
func bot_plan() -> void:
	if asama != "plan":
		return
	var mermi: Array = []
	for m in (["harpun", "ates", "demir", "zincir"] if canavar_mi else ["ates", "zincir", "demir", "harpun"]):
		for i in gemi.mermi[m]:
			mermi.append(m)
	var bp := _planla(oyuncu, rakip.p, mini(hamle_hakki(), gemi.hareket), mermi)
	for i in ADIM:
		if bp[i].h != "" and gemi.hareket > 0:
			gemi.hareket -= 1
			plan[i].h = bp[i].h
		for taraf in ["sol", "sag"]:
			if bp[i][taraf] != "":
				secili_mermi = bp[i][taraf]
				atis_degistir(i, taraf)
	secili_mermi = "demir"


# --- Tur çözümü -------------------------------------------------------------

func _process(delta: float) -> void:
	_zaman += delta
	if _sarsinti > 0.0:
		_sarsinti = maxf(0.0, _sarsinti - delta)
		position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 14.0 * _sarsinti
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	if _mesaj_sure > 0.0:
		_mesaj_sure -= delta
	for i in range(_patlamalar.size() - 1, -1, -1):
		_patlamalar[i].yas += delta
		if _patlamalar[i].yas > 0.6:
			_patlamalar.remove_at(i)
	for i in range(_yazilar.size() - 1, -1, -1):
		_yazilar[i].yas += delta
		if _yazilar[i].yas > 0.9:
			_yazilar.remove_at(i)
	match asama:
		"plan":
			sure -= delta
			if sure <= 0.0:
				_cozum_basla()
		"cozum":
			_faz_t += delta / FAZ_SURE[_faz]
			if _faz_t >= 1.0:
				_faz_bitir()
		"duello":
			pass   # düello paneli sürerken tahta bekler
		"son":
			_son_sure -= delta
			if _son_sure <= 0.0:
				asama = "bitti"
				bitti.emit(sonuc, ganimet)
	queue_redraw()


func _cozum_basla() -> void:
	asama = "cozum"
	_adim = 0
	# Yırtık yelken bu turda işledi, iyileşir
	oyuncu.yirtik = 0
	rakip.yirtik = 0
	_faz_baslat(0)


func _faz_baslat(f: int) -> void:
	_faz = f
	_faz_t = 0.0
	match f:
		0:
			_hareket_coz(plan[_adim].h, rakip_plan[_adim].h)
		1:
			_cevre_coz()
		2:
			_atis_coz()


func _faz_bitir() -> void:
	_cizim_sifirla()
	if _faz == 2:
		for t in _toplar:
			if t.isabet:
				_isabet(t)
			else:
				_patlamalar.append({"p": t.son, "yas": 0.0, "buyuk": false})
		_toplar.clear()
		if _bitti_mi():
			return
		_adim += 1
		if _adim >= ADIM:
			tur += 1
			_tur_baslat()
			mesaj("Tur " + str(tur))
			return
		_faz_baslat(0)
	else:
		_faz_baslat(_faz + 1)


func _hareket_coz(ho: String, hr: String) -> void:
	var gemiler := [oyuncu, rakip]
	var siralar := [_alt_hamleler(ho), _alt_hamleler(hr)]
	var durdu := [false, false]
	for g in gemiler:
		g.kare = [[_merkez(g.p), _aci(g.yon)]]
	for k in 3:
		var istek := [null, null]
		var eylem := [false, false]
		for g in 2:
			if k >= siralar[g].size():
				continue
			var a: String = siralar[g][k]
			if durdu[g] and a == "F":
				continue
			var s: Dictionary = gemiler[g]
			if a == "L":
				s.yon = (s.yon + 3) % 4
				eylem[g] = true
			elif a == "R":
				s.yon = (s.yon + 1) % 4
				eylem[g] = true
			else:
				istek[g] = s.p + YON[s.yon]
		# Kaya ve kenar
		for g in 2:
			if istek[g] == null:
				continue
			var s: Dictionary = gemiler[g]
			var q: Vector2i = istek[g]
			if g == 0 and not _icinde(q):
				_kacti = true   # kenardan dışarı: kaçış
			if _tur(q) == KAYA:
				durdu[g] = true
				istek[g] = null
				if _icinde(q):
					_hasar(s, 4.0)
					_yazilar.append({"p": (_merkez(s.p) + _merkez(q)) / 2.0, "metin": "ÇAT!", "yas": 0.0, "renk": Color(0.9, 0.8, 0.6)})
					_ses("carpma", -6.0)
		# Gemi gemiye: aynı kareye ya da duran/yer değiştiren gemiye çarpma
		for g in 2:
			if istek[g] == null:
				continue
			var s: Dictionary = gemiler[g]
			var o: Dictionary = gemiler[1 - g]
			var q: Vector2i = istek[g]
			var diger = istek[1 - g]
			var engel := false
			if q == o.p and (diger == null or diger == s.p):
				engel = true
			elif diger != null and q == diger:
				engel = true
			if engel:
				durdu[g] = true
				istek[g] = null
				_hasar(s, 3.0)
				_yazilar.append({"p": _merkez(s.p), "metin": "BAM!", "yas": 0.0, "renk": Color(1, 0.7, 0.3)})
				_ses("carpma", -4.0)
		for g in 2:
			var s: Dictionary = gemiler[g]
			if istek[g] != null:
				s.p = istek[g]
				eylem[g] = true
			if eylem[g]:
				s.kare.append([_merkez(s.p), _aci(s.yon)])


func _cevre_coz() -> void:
	var gemiler := [oyuncu, rakip]
	for g in 2:
		var s: Dictionary = gemiler[g]
		var o: Dictionary = gemiler[1 - g]
		s.kare = [[_merkez(s.p), _aci(s.yon)]]
		var t := _tur(s.p)
		var q: Vector2i = s.p
		if t == RUZGAR:
			q = s.p + YON[ruzgar_yon[s.p.y * N + s.p.x]]
		elif t == GIRDAP:
			s.yon = (s.yon + 1) % 4
			q = s.p + YON[s.yon]
			_yazilar.append({"p": _merkez(s.p), "metin": "VIIN!", "yas": 0.0, "renk": Color(0.5, 0.85, 1.0)})
		if q != s.p and _tur(q) != KAYA and q != o.p:
			s.p = q
		s.kare.append([_merkez(s.p), _aci(s.yon)])


func _atis_coz() -> void:
	_toplar.clear()
	var gemiler := [oyuncu, rakip]
	var planlar := [plan[_adim], rakip_plan[_adim]]
	var ses_var := false
	for g in 2:
		var s: Dictionary = gemiler[g]
		var o: Dictionary = gemiler[1 - g]
		s.kare = [[_merkez(s.p), _aci(s.yon)]]
		for taraf in ["sol", "sag"]:
			var m: String = planlar[g][taraf]
			if m == "":
				continue
			var iz := _atis_izi(s.p, s.yon, taraf, o.p)
			_toplar.append({"bas": _merkez(s.p), "son": _merkez(iz.son), "isabet": iz.isabet, "hedef": o, "tur": m})
			var kim := "oyuncu" if g == 0 else "rakip"
			istatistik[kim + "_atis"] += 1
			if iz.isabet:
				istatistik[kim + "_isabet"] += 1
			ses_var = true
	if ses_var:
		_ses("top", -4.0)
	# Canavar ısırığı: dibindeki gemiye
	if canavar_mi and absi(oyuncu.p.x - rakip.p.x) <= 1 and absi(oyuncu.p.y - rakip.p.y) <= 1:
		_hasar(oyuncu, 5.0 + float(korsan.get("guc", 1)))
		istatistik.rakip_isabet += 1
		var orta := (_merkez(oyuncu.p) + _merkez(rakip.p)) / 2.0
		_yazilar.append({"p": orta, "metin": "HAM!", "yas": 0.0, "renk": Color(0.85, 0.5, 1.0)})
		if str(korsan.get("tur", "")) == "ahtapot":
			oyuncu.yirtik = 1   # kollarıyla sarar: sonraki tur bir hamle eksik
		_ses("isirma", -2.0)


func _isabet(t: Dictionary) -> void:
	var hedef: Dictionary = t.hedef
	var m: float = MERMI_HASAR[t.tur]
	if canavar_mi and hedef == rakip:
		m *= CANAVAR_CARPAN[t.tur]
	_hasar(hedef, m)
	_patlamalar.append({"p": t.son, "yas": 0.0, "buyuk": true})
	var soz := "BAM!"
	match t.tur:
		"zincir":
			hedef.yirtik = 1
			soz = "YIRT!"
		"ates":
			hedef.yanma = 2
			soz = "BUUM!"
		"harpun":
			soz = "ZIIP!"
	_yazilar.append({"p": t.son + Vector2(0, -20), "metin": soz, "yas": 0.0, "renk": MERMI_RENK[t.tur].lightened(0.3)})
	_ses("top", 0.0)


func _hasar(s: Dictionary, m: float) -> void:
	if s == oyuncu:
		m *= 0.6 + 0.2 * float(korsan.get("guc", 1))   # zayıf korsanlar daha az vurur
		gemi.govde = maxf(0.0, gemi.govde - m)
		gemi.su = minf(100.0, gemi.su + m * 0.4)
		_sarsinti = clampf(m * 0.04, 0.12, 0.4)
	else:
		s.can = maxf(0.0, s.can - m)
	# Uçan hasar sayısı
	_yazilar.append({"p": _merkez(s.p) + Vector2(18, -14), "metin": "-" + str(int(round(m))), "yas": 0.0,
		"renk": Color(1, 0.45, 0.4) if s == oyuncu else Color(1, 0.95, 0.6)})


func _bitti_mi() -> bool:
	if rakip.can <= 0.0:
		sonuc = "zafer"
		ganimet = 60 + 40 * int(korsan.get("guc", 1)) + _rng.randi_range(0, 40)
		if canavar_mi:
			ganimet = 120 + 50 * int(korsan.get("guc", 1)) + _rng.randi_range(0, 50)
		if _teslim:
			ganimet = int(ganimet * 1.5)   # teslim alınan gemi: ambar da senin
		mesaj(("AV TAMAM! +" if canavar_mi else ("TESLİM OLDULAR! +" if _teslim else "ZAFER! +")) + str(ganimet) + " altın")
		_ses("basari")
	elif gemi.govde <= 0.0:
		sonuc = "yenilgi"
		ganimet = 0
		mesaj("Gemin battı...")
		_ses("hata")
	elif _kacti:
		sonuc = "kacis"
		ganimet = 0
		mesaj("Kaçtın! Rüzgar seninle")
		_ses("yelken")
	else:
		return false
	asama = "son"
	_mesaj_sure = 1.2
	_son_sure = 3.6
	return true


func _ses(ad: String, db := 0.0) -> void:
	var s := get_tree().get_first_node_in_group("ses")
	if s != null:
		s.cal(ad, db)


# --- Çizim ------------------------------------------------------------------

func _kare_ornek(s: Dictionary) -> Array:
	var kare: Array = s.kare
	if kare.size() <= 1 or asama != "cozum":
		return [kare[-1][0], kare[-1][1]] if asama == "cozum" else [_merkez(s.p), _aci(s.yon)]
	var t := clampf(_faz_t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var n := kare.size() - 1
	var seg := mini(int(t * n), n - 1)
	var yerel := t * n - seg
	return [kare[seg][0].lerp(kare[seg + 1][0], yerel), lerp_angle(kare[seg][1], kare[seg + 1][1], yerel)]


func _gemi_ciz(s: Dictionary, renk: int, oran: float) -> void:
	var o := _kare_ornek(s)
	var seviye := 0
	if oran < 0.3:
		seviye = 2
	elif oran < 0.65:
		seviye = 1
	var t: Texture2D = V.doku("gemiler/gemi_%02d.png" % (renk + 1 + seviye * 6))
	var sallanma := sin(_zaman * 2.2 + renk) * 0.05
	draw_set_transform(o[0] + Vector2(3, 4), o[1] + sallanma, Vector2(0.38, 0.38))
	draw_texture(t, -t.get_size() / 2.0, Color(0, 0, 0, 0.25))
	draw_set_transform(o[0], o[1] + sallanma, Vector2(0.38, 0.38))
	draw_texture(t, -t.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	if s.yanma > 0:
		var ates: Texture2D = V.doku("efekt/fire1.png")
		var oy := 0.9 + 0.2 * sin(_zaman * 14.0)
		draw_texture_rect(ates, Rect2(o[0] + Vector2(-6, -22) * oy, Vector2(12, 26) * oy), false)


func _buton(r: Rect2, yazi: String, ad: String, vurgulu := false, pasif := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.36, 0.18) if vurgulu else Color(0.32, 0.21, 0.12, 0.95)
	if pasif:
		sb.bg_color = Color(0.2, 0.17, 0.15, 0.8)
	sb.border_color = Color(1, 0.85, 0.45) if vurgulu else Color(0.85, 0.65, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, r)
	if yazi != "":
		_yazi_ortala(r, yazi, 18, Color(1, 0.95, 0.84) if not pasif else Color(0.6, 0.55, 0.5))
	_tuslar.append([r, ad])


func _yazi_ortala(r: Rect2, yazi: String, boy: int, renk: Color) -> void:
	var font := ThemeDB.fallback_font
	var s := font.get_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy)
	draw_string(font, r.position + Vector2((r.size.x - s.x) / 2.0, (r.size.y + boy * 0.75) / 2.0), yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy, renk)


func _yazi(p: Vector2, yazi: String, boy: int, renk := Color(1, 0.95, 0.84)) -> void:
	draw_string(ThemeDB.fallback_font, p, yazi, HORIZONTAL_ALIGNMENT_LEFT, -1, boy, renk)


func _ok_ciz(m: Vector2, h: String, renk: Color, boy := 14.0) -> void:
	var a := -PI / 2.0
	if h == "sol":
		a = -PI * 0.75
	elif h == "sag":
		a = -PI * 0.25
	var u := Vector2.from_angle(a) * boy
	var dik := u.orthogonal() * 0.6
	draw_line(m - u, m + u * 0.4, renk, 4.0)
	draw_colored_polygon(PackedVector2Array([m + u, m + u * 0.3 + dik, m + u * 0.3 - dik]), renk)


func _cubuk(r: Rect2, oran: float, renk: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(oran, 0.0, 1.0), r.size.y)), renk)
	draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)


func _draw() -> void:
	_tuslar.clear()
	var ekran := size
	var alan := Rect2(TAHTA, Vector2(N * C, N * C))
	draw_rect(alan.grow(3), Color(0.45, 0.3, 0.16), false, 6.0)
	# Su zemini shader'la (arka planda) çizilir; ızgara çizgileri
	for i in N + 1:
		draw_line(TAHTA + Vector2(i * C, 0), TAHTA + Vector2(i * C, N * C), Color(1, 1, 1, 0.08), 1.0)
		draw_line(TAHTA + Vector2(0, i * C), TAHTA + Vector2(N * C, i * C), Color(1, 1, 1, 0.08), 1.0)
	for y in N:
		for x in N:
			var t := harita[y * N + x]
			var m := TAHTA + (Vector2(x, y) + Vector2(0.5, 0.5)) * C
			match t:
				KAYA:
					var no := 49 + (x * 7 + y * 3) % 3
					draw_circle(m, C * 0.48, Color(1, 1, 1, 0.15))
					draw_texture_rect(V.karo(no), Rect2(m - Vector2(C, C) * 0.55, Vector2(C, C) * 1.1), false)
				RUZGAR:
					var d := Vector2(YON[ruzgar_yon[y * N + x]])
					draw_rect(Rect2(m - Vector2(C, C) / 2.0, Vector2(C, C)), Color(0.85, 0.95, 1.0, 0.13))
					var kay := fmod(_zaman * 0.8, 1.0) - 0.5
					var u := d * C * 0.22
					var dik := Vector2(-d.y, d.x) * C * 0.22
					var c0 := m + d * C * kay * 0.5
					draw_polyline(PackedVector2Array([c0 - u + dik, c0 + u, c0 - u - dik]), Color(1, 1, 1, 0.75), 3.0)
				GIRDAP:
					for k in 3:
						var r := C * (0.15 + k * 0.13)
						var bas := _zaman * (3.0 - k * 0.6) + k * 2.0
						draw_arc(m, r, bas, bas + PI * 1.3, 14, Color(0.85, 0.95, 1.0, 0.85 - k * 0.2), 2.5)
					draw_circle(m, C * 0.1, Color(0.05, 0.2, 0.35, 0.9))
	# Plan önizlemesi: oyuncunun gideceği yol (rakibin şimdiki yeri engel sayılır)
	if asama == "plan":
		var p: Vector2i = oyuncu.p
		var yon: int = oyuncu.yon
		var onceki := _merkez(p)
		for i in ADIM:
			var r := _benzet(p, yon, plan[i].h, rakip.p)
			p = r.p
			yon = r.yon
			var m := _merkez(p)
			if m != onceki:
				draw_line(onceki, m, Color(1, 1, 0.6, 0.5), 3.0)
			draw_circle(m, 5.0, Color(1, 1, 0.6, 0.8))
			for taraf in ["sol", "sag"]:
				if plan[i][taraf] != "":
					var iz := _atis_izi(p, yon, taraf, rakip.p)
					draw_line(m, _merkez(iz.son), Color(1, 0.35, 0.25, 0.55), 2.0)
			onceki = m
		var tt: Texture2D = V.doku("gemiler/gemi_05.png")
		draw_set_transform(_merkez(p), _aci(yon), Vector2(0.38, 0.38))
		draw_texture(tt, -tt.get_size() / 2.0, Color(1, 1, 1, 0.3))
		draw_set_transform(Vector2.ZERO)
	if canavar_mi:
		var co := _kare_ornek(rakip)
		CanavarBetik.canavar_ciz(self, str(korsan.get("tur", "yilan")), co[0], co[1] + PI / 2.0, 0.42, _zaman, rakip.can / rakip.can_max)
	else:
		_gemi_ciz(rakip, int(korsan.get("renk", 2)), rakip.can / rakip.can_max)
	_gemi_ciz(oyuncu, 4, gemi.govde / 100.0)
	# Uçan gülleler
	if asama == "cozum" and _faz == 2:
		var t := clampf(_faz_t * 1.15, 0.0, 1.0)
		var top_doku: Texture2D = V.doku("efekt/cannonBall.png")
		for tp in _toplar:
			var p: Vector2 = tp.bas.lerp(tp.son, t) + Vector2(0, -sin(t * PI) * 16.0)
			if t < 0.25:
				draw_circle(tp.bas, 10.0 * (1.0 - t * 4.0) + 4.0, Color(1, 0.9, 0.6, 0.8))
			draw_circle(p + Vector2(2, 2), 6, Color(0, 0, 0, 0.3))
			if tp.tur == "demir":
				draw_texture_rect(top_doku, Rect2(p - Vector2(6, 6), Vector2(12, 12)), false)
			elif tp.tur == "harpun":
				# Harpun: ipli mızrak
				var yonu: Vector2 = (tp.son - tp.bas).normalized()
				draw_line(tp.bas, p, Color(0.95, 0.9, 0.75, 0.6), 1.5)
				draw_line(p - yonu * 14.0, p + yonu * 6.0, Color(0.55, 0.38, 0.2), 3.0)
				draw_colored_polygon(PackedVector2Array([p + yonu * 13.0, p + yonu * 4.0 + yonu.orthogonal() * 4.0, p + yonu * 4.0 - yonu.orthogonal() * 4.0]), Color(0.8, 0.82, 0.88))
			else:
				if tp.tur == "ates":
					draw_circle(p, 10.0, Color(1, 0.6, 0.2, 0.35))
				draw_circle(p, 6.0, MERMI_RENK[tp.tur])
				draw_circle(p + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.6))
	for b in _patlamalar:
		var kare := mini(8, int(b.yas / 0.6 * 9.0))
		var tx: Texture2D = V.doku("duman/explosion%02d.png" % kare)
		var boy := (C * 1.6) if b.buyuk else (C * 0.8)
		if b.buyuk:
			draw_texture_rect(tx, Rect2(b.p - Vector2(boy, boy) / 2.0, Vector2(boy, boy)), false)
		else:
			draw_circle(b.p, 4.0 + b.yas * 30.0, Color(1, 1, 1, 0.7 * (1.0 - b.yas / 0.6)))
	var cf := V.font()
	for y in _yazilar:
		var a := clampf((0.9 - y.yas) / 0.3, 0.0, 1.0)
		var o := minf(1.0, y.yas / 0.1)
		var s := cf.get_string_size(y.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		var p: Vector2 = y.p + Vector2(-s.x / 2.0 * o, -y.yas * 30.0)
		draw_string_outline(cf, p, y.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * o) + 1, 6, Color(0.2, 0.05, 0.02, a))
		draw_string(cf, p, y.metin, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * o) + 1, Color(y.renk, a))
	_ust_cubuk()
	_sol_sutun()
	_alt_cubuk()
	_sag_bilgi(ekran)
	if asama == "son" or asama == "bitti":
		_ozet_ciz()
	elif _mesaj_sure > 0.0:
		var a := clampf(_mesaj_sure / 0.4, 0.0, 1.0)
		var r := Rect2(TAHTA.x, TAHTA.y + N * C * 0.42, N * C, 70)
		draw_rect(r, Color(0, 0, 0, 0.55 * a))
		var bf := ThemeDB.fallback_font
		var s := bf.get_string_size(_mesaj, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
		var p := r.position + Vector2((r.size.x - s.x) / 2.0, 48)
		draw_string_outline(bf, p, _mesaj, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0.1, 0.04, 0.02, a))
		draw_string(bf, p, _mesaj, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.85, 0.35, a))


func _ust_cubuk() -> void:
	_yazi(Vector2(TAHTA.x, 24), "Gemin", 17)
	_cubuk(Rect2(TAHTA.x, 32, 200, 14), gemi.govde / 100.0, Color(0.55, 0.85, 0.45))
	_cubuk(Rect2(TAHTA.x, 50, 200, 8), gemi.su / 100.0, Color(0.3, 0.6, 0.95))
	_yazi(Vector2(TAHTA.x + 150, 24), str(int(gemi.govde)), 16)
	var sag_x := TAHTA.x + N * C - 200
	var ad := ("" if canavar_mi else "Korsan ") + str(korsan.get("ad", ""))
	_yazi(Vector2(sag_x, 24), ad, 17, Color(1, 0.7, 0.6))
	_cubuk(Rect2(sag_x, 32, 200, 14), rakip.can / rakip.can_max, Color(0.9, 0.35, 0.3))
	# Süre halkası
	var m := Vector2(TAHTA.x + N * C / 2.0, 36)
	draw_circle(m, 27, Color(0.1, 0.07, 0.05, 0.9))
	var oran := clampf(sure / TUR_SURE, 0.0, 1.0) if asama == "plan" else 0.0
	draw_arc(m, 24, -PI / 2.0, -PI / 2.0 + TAU * oran, 32, Color(1, 0.85, 0.35) if sure > 5.0 else Color(1, 0.35, 0.25), 5.0)
	var yazi := str(ceili(sure)) if asama == "plan" else "!"
	_yazi_ortala(Rect2(m - Vector2(27, 27), Vector2(54, 54)), yazi, 22, Color(1, 0.95, 0.84))
	_yazi(Vector2(m.x - 80, 24), "Tur " + str(tur), 16, Color(0.85, 0.78, 0.65))


func _sol_sutun() -> void:
	for i in ISTASYONLAR.size():
		var r := Rect2(8, 72 + i * 56, 92, 48)
		_buton(r, ISTASYONLAR[i][1], "ist_" + ISTASYONLAR[i][0])
	_yazi(Vector2(10, 320), "Hareket", 16, Color(0.85, 0.78, 0.65))
	_yazi(Vector2(10, 342), "x" + str(gemi.hareket), 22, Color(0.95, 0.9, 0.6))
	_yazi(Vector2(10, 376), "Gülle", 16, Color(0.85, 0.78, 0.65))
	var i := 0
	for m in MERMILER:
		var r := Rect2(8, 384 + i * 52, 92, 47)
		_buton(r, "", "mermi_" + m, m == secili_mermi)
		draw_circle(r.position + Vector2(16, 24), 9, MERMI_RENK[m])
		_yazi(r.position + Vector2(30, 20), MERMI_ADI[m], 15)
		_yazi(r.position + Vector2(30, 39), "x" + str(gemi.mermi[m]), 16, Color(1, 0.88, 0.45))
		i += 1
	# Kanca: rakibe bitişikken rampa düellosu başlatır
	if not canavar_mi:
		var kr := Rect2(8, 596, 92, 46)
		var olur := kanca_mumkun()
		if olur:
			var parla := 0.5 + 0.5 * sin(_zaman * 6.0)
			draw_rect(kr.grow(4), Color(1, 0.85, 0.3, 0.35 * parla))
		_buton(kr, "Kanca", "kanca", olur, not olur)
	var y := 662.0
	if int(oyuncu.yirtik) > 0:
		_yazi(Vector2(10, y), "Yelken yırtık!", 14, Color(1, 0.6, 0.5))
		y += 20
	if int(oyuncu.yanma) > 0:
		_yazi(Vector2(10, y), "Yanıyorsun!", 14, Color(1, 0.6, 0.3))


func _alt_cubuk() -> void:
	var y := TAHTA.y + N * C + 10
	for i in ADIM:
		var r := Rect2(TAHTA.x + i * 70, y, 64, 86)
		var kilitli := i >= hamle_hakki() and asama == "plan"
		var aktif := asama == "cozum" and i == _adim
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.14, 0.09, 0.95) if not kilitli else Color(0.12, 0.1, 0.09, 0.9)
		sb.border_color = Color(1, 0.9, 0.4) if aktif else Color(0.6, 0.45, 0.25)
		sb.set_border_width_all(3 if aktif else 2)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, r)
		_yazi(r.position + Vector2(4, 14), str(i + 1), 12, Color(0.7, 0.62, 0.5))
		if kilitli:
			_yazi_ortala(r, "X", 26, Color(0.6, 0.3, 0.25))
			continue
		var h: String = plan[i].h
		if h != "":
			_ok_ciz(r.get_center() + Vector2(0, 4), h, Color(0.95, 0.9, 0.6))
		for taraf in ["sol", "sag"]:
			var m: String = plan[i][taraf]
			var k := r.position + Vector2(12 if taraf == "sol" else 52, 64)
			if m != "":
				draw_circle(k, 8, MERMI_RENK[m])
				draw_circle(k + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.5))
			else:
				draw_arc(k, 7, 0, TAU, 12, Color(1, 1, 1, 0.25), 1.5)
		_tuslar.append([Rect2(r.position, Vector2(22, r.size.y)), "slot_%d_sol" % i])
		_tuslar.append([Rect2(r.position + Vector2(42, 0), Vector2(22, r.size.y)), "slot_%d_sag" % i])
		_tuslar.append([Rect2(r.position + Vector2(22, 0), Vector2(20, r.size.y)), "slot_%d_orta" % i])
	var plan_mi := asama == "plan"
	var hx := TAHTA.x + 4 * 70 + 6
	for j in 3:
		var ad: String = ["sol", "ileri", "sag"][j]
		var r := Rect2(hx + j * 60, y, 54, 86)
		_buton(r, "", ad, false, not plan_mi or gemi.hareket <= 0)
		_ok_ciz(r.get_center() + Vector2(0, -6), ad, Color(1, 0.95, 0.84), 16.0)
		_yazi_ortala(Rect2(r.position + Vector2(0, 52), Vector2(54, 30)), ["Sol", "İleri", "Sağ"][j], 14, Color(0.85, 0.78, 0.65))
	var hr := Rect2(hx + 180, y, TAHTA.x + N * C - (hx + 180), 86)
	_buton(hr, "Hazır", "hazir", plan_mi, not plan_mi)


func _sag_bilgi(ekran: Vector2) -> void:
	# Puzzle paneli kapalıyken sağda kısa rehber görünür (panel açılınca üstünü örter)
	var x := TAHTA.x + N * C + 70
	if ekran.x - x < 300:
		return
	var r := Rect2(x, 72, ekran.x - x - 24, 500)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.11, 0.07, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.55, 0.36, 0.18)
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
	var satirlar := [
		"Her tur 20 saniye: 4 adımı planla.",
		"Sol / İleri / Sağ: hareket jetonu harcar.",
		"Adım kutusunun kenarına dokun: o yöne",
		"  bordadan ateş (seçili gülle, 3 kare).",
		"Ok kareleri iter, girdap döndürüp fırlatır,",
		"kayalar gövdeye zarar verir.",
		"",
		"Bitişikken Kanca: rampa düellosu başlar.",
		"Kenardan dışarı sür: savaştan kaç.",
		"Harpun canavarlara 4 kat işler.",
		"",
		"Jeton: Yelken  ·  Gülle: Top",
		"Gövdeyi Tamir, suyu Pompa ile koru!",
	]
	_yazi(r.position + Vector2(18, 36), "Canavar Avı" if canavar_mi else "Deniz Savaşı", 26, Color(1, 0.85, 0.4))
	for i in satirlar.size():
		_yazi(r.position + Vector2(18, 76 + i * 30), satirlar[i], 17, Color(0.92, 0.86, 0.74))


## Savaş sonu özet kartı: sonuç, ganimet, atış/isabet ve kalan gövde.
func _ozet_ciz() -> void:
	var r := Rect2(TAHTA.x + 62, TAHTA.y + 120, N * C - 124, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.11, 0.07, 0.95)
	sb.border_color = Color(1, 0.85, 0.4)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.5)
	draw_style_box(sb, r)
	var baslik: String = {"zafer": "ZAFER!", "yenilgi": "YENİLGİ", "kacis": "KAÇTIN"}.get(sonuc, "")
	if sonuc == "zafer" and canavar_mi:
		baslik = "AV TAMAM!"
	elif sonuc == "zafer" and _teslim:
		baslik = "TESLİM OLDULAR!"
	var renk := Color(1, 0.85, 0.35) if sonuc == "zafer" else (Color(0.95, 0.45, 0.4) if sonuc == "yenilgi" else Color(0.6, 0.85, 1.0))
	var bf := ThemeDB.fallback_font
	var s := bf.get_string_size(baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	var bp := r.position + Vector2((r.size.x - s.x) / 2.0, 56)
	draw_string_outline(bf, bp, baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.1, 0.04, 0.02))
	draw_string(bf, bp, baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, renk)
	var oa: int = istatistik.oyuncu_atis
	var oi: int = istatistik.oyuncu_isabet
	var satirlar := [
		["Rakip", str(korsan.get("ad", ""))],
		["Tur", str(tur)],
		["Atış / isabet", "%d / %d  (%%%d)" % [oa, oi, int(100.0 * oi / maxf(1.0, oa))]],
		["Aldığın isabet", str(istatistik.rakip_isabet)],
		["Kalan gövde", str(int(gemi.govde))],
		["Ganimet", str(ganimet) + " altın"],
	]
	for i in satirlar.size():
		var y := r.position.y + 100 + i * 31
		_yazi(Vector2(r.position.x + 30, y), satirlar[i][0], 19, Color(0.85, 0.78, 0.65))
		_yazi(Vector2(r.position.x + 210, y), satirlar[i][1], 19, Color(1, 0.88, 0.45) if i == 5 else Color(1, 0.95, 0.84))
