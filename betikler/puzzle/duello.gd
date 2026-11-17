extends "res://betikler/puzzle/puzzle_taban.gd"
## RAMPA DÜELLOSU — kanca tutunca başlayan blok düellosu (2. aşama).
## İkişer taştan oluşan parçalar düşer. YILDIZ taş (kırıcı), değdiği aynı renkteki bütün bitişik taşları kırar.
## Kırılan taşlar ve zincirleme kırılmalar rakibe ENGEL taşı gönderir; engeller, yanında bir grup kırılınca dağılır.
## Kimin yığını tepeye ulaşırsa düelloyu kaybeder; süre biterse tahtası daha boş olan kazanır.
## Sonuç katki("duello", 1) (zafer) ya da katki("duello", -1) (yenilgi) ile bildirilir.

const SUT := 6
const SAT := 12
const H := 38.0
const TAHTA := Vector2(24, 76)
const RH := 22.0
const RTAHTA := Vector2(300, 122)
const SURE := 75.0
const RENK := ["", "Red", "Blue", "Green", "Yellow"]
const ENGEL := 5
const DONUS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const KOMBO_SOZU := ["", "ÇAT!", "BAM!", "BUUM!", "VUŞŞ!"]


## Bir oyuncunun tahtası (oyuncu ve rakip aynı kuralları kullanır; yapay zekâ kopyası üzerinde dener).
class Tahta:
	var h := PackedInt32Array()      # 0 boş, 1-4 renk, 5 engel
	var k := PackedByteArray()       # 1 = yıldız (kırıcı) taş
	var ofs := PackedFloat32Array()  # düşüş animasyonu (satır cinsinden kalan yol)

	func _init() -> void:
		h.resize(SUT * SAT)
		h.fill(0)
		k.resize(SUT * SAT)
		k.fill(0)
		ofs.resize(SUT * SAT)
		ofs.fill(0.0)

	func kopya() -> Tahta:
		var t := Tahta.new()
		t.h = h.duplicate()
		t.k = k.duplicate()
		return t

	func bos_mu(p: Vector2i) -> bool:
		if p.x < 0 or p.x >= SUT or p.y >= SAT:
			return false
		return p.y < 0 or h[p.y * SUT + p.x] == 0

	## Parça hücrelerini koyar; tepenin üstünde kalan olursa false (yığın taştı).
	func yerlestir(hucreler: Array) -> bool:
		var tamam := true
		for c in hucreler:
			var p: Vector2i = c[0]
			if p.y < 0:
				tamam = false
				continue
			h[p.y * SUT + p.x] = c[1]
			k[p.y * SUT + p.x] = c[2]
		return tamam

	func yercekimi() -> void:
		for x in SUT:
			var yaz := SAT - 1
			for y in range(SAT - 1, -1, -1):
				var i := y * SUT + x
				if h[i] == 0:
					continue
				if yaz != y:
					var j := yaz * SUT + x
					h[j] = h[i]
					k[j] = k[i]
					ofs[j] = float(yaz - y) + ofs[i]
					h[i] = 0
					k[i] = 0
					ofs[i] = 0.0
				yaz -= 1

	## Kırıcıları çözer; her zincir adımı için {"sayi", "merkez", "zincir"} döner.
	func coz() -> Array:
		var adimlar: Array = []
		var zincir := 0
		while zincir < 10:
			var sil := {}
			for i in SUT * SAT:
				if k[i] != 1 or h[i] < 1 or h[i] > 4 or sil.has(i):
					continue
				var komsu_var := false
				for d in DONUS:
					var q: Vector2i = Vector2i(i % SUT, i / SUT) + d
					if q.x >= 0 and q.x < SUT and q.y >= 0 and q.y < SAT and h[q.y * SUT + q.x] == h[i]:
						komsu_var = true
						break
				if komsu_var:
					_doldur(i, h[i], sil)
			if sil.is_empty():
				break
			zincir += 1
			# Kırılan grubun yanındaki engeller de dağılır
			var engeller := {}
			for i in sil:
				for d in DONUS:
					var q: Vector2i = Vector2i(i % SUT, i / SUT) + d
					if q.x >= 0 and q.x < SUT and q.y >= 0 and q.y < SAT and h[q.y * SUT + q.x] == ENGEL:
						engeller[q.y * SUT + q.x] = true
			var merkez := Vector2.ZERO
			for i in sil:
				merkez += Vector2(i % SUT, i / SUT)
			merkez /= float(sil.size())
			var sayi := sil.size()
			sil.merge(engeller)
			for i in sil:
				h[i] = 0
				k[i] = 0
			adimlar.append({"sayi": sayi, "engel": engeller.size(), "merkez": merkez, "zincir": zincir})
			yercekimi()
		return adimlar

	func _doldur(bas: int, renk: int, sil: Dictionary) -> void:
		var yigin := [bas]
		while not yigin.is_empty():
			var i: int = yigin.pop_back()
			if sil.has(i) or h[i] != renk:
				continue
			sil[i] = true
			for d in DONUS:
				var q: Vector2i = Vector2i(i % SUT, i / SUT) + d
				if q.x >= 0 and q.x < SUT and q.y >= 0 and q.y < SAT:
					yigin.append(q.y * SUT + q.x)

	## Engel taşlarını en boş sütunlardan başlayarak üstten düşürür.
	func engel_dusur(n: int, rng: RandomNumberGenerator) -> int:
		var dusen := 0
		for i in n:
			var x := rng.randi() % SUT
			var y := _ust_bos(x)
			if y < 0:
				for xx in SUT:
					if _ust_bos(xx) >= 0:
						x = xx
						y = _ust_bos(xx)
						break
			if y < 0:
				break
			h[y * SUT + x] = ENGEL
			k[y * SUT + x] = 0
			ofs[y * SUT + x] = float(y + 2)
			dusen += 1
		return dusen

	func _ust_bos(x: int) -> int:
		for y in range(SAT - 1, -1, -1):
			if h[y * SUT + x] == 0:
				return y
		return -1

	func dolu_sayi() -> int:
		var n := 0
		for v in h:
			if v != 0:
				n += 1
		return n

	func yukseklik() -> int:
		for y in SAT:
			for x in SUT:
				if h[y * SUT + x] != 0:
					return SAT - y
		return 0


var oyuncu_t := Tahta.new()
var rakip_t := Tahta.new()
var parca := {}                 # {"p": Vector2i, "rot": int, "a": [renk, kirici], "b": [renk, kirici]}
var sonraki := {}
var rakip_parca := {}
var rakip_ad := "Korsan"
var guc := 1
var sure := SURE
var bitti := false
var gelen := 0                  # oyuncuya gelecek engel
var giden := 0                  # rakibe gidecek engel
var toplam_gonderilen := 0
var toplam_alinan := 0
var _dus_t := 0.0
var _rakip_t := 0.0
var _zaman := 0.0
var _rng := RandomNumberGenerator.new()
var _bitis_bekle := -1.0


func baslat() -> void:
	baslik = "Rampa Düellosu"
	aciklama = "YILDIZ taş, değdiği aynı renk taşları kırar"
	_rng.randomize()
	sonraki = _yeni_parca()
	rakip_parca = _yeni_parca()
	_sonraki_parca()


## Düelloyu rakibe göre ayarlar (güç = hız).
func kur(ad: String, rakip_guc: int, tohum := -1) -> void:
	rakip_ad = ad
	guc = rakip_guc
	ses_cal("kilic", -2.0)
	if tohum >= 0:
		_rng.seed = tohum


func _yeni_parca() -> Dictionary:
	# Her parçada en çok bir yıldız: kırıcı şansı %30
	var a := [1 + _rng.randi() % 4, 0]
	var b := [1 + _rng.randi() % 4, 0]
	if _rng.randf() < 0.3:
		(a if _rng.randf() < 0.5 else b)[1] = 1
	return {"p": Vector2i(2, 1), "rot": 0, "a": a, "b": b}


func _sonraki_parca() -> void:
	parca = sonraki
	sonraki = _yeni_parca()
	_dus_t = 0.0
	if not oyuncu_t.bos_mu(parca.p) or not oyuncu_t.bos_mu(parca.p + DONUS[0]):
		_bitir(false, "Yığının tepeye ulaştı!")


func _hucreler(pc: Dictionary) -> Array:
	return [[pc.p, pc.a[0], pc.a[1]], [pc.p + DONUS[pc.rot], pc.b[0], pc.b[1]]]


func _gecerli(t: Tahta, pc: Dictionary) -> bool:
	for c in _hucreler(pc):
		if not t.bos_mu(c[0]):
			return false
	return true


func _dene(degisim: Vector2i, donus := 0) -> bool:
	if bitti or parca.is_empty():
		return false
	var yeni := parca.duplicate()
	yeni.p = parca.p + degisim
	yeni.rot = (parca.rot + donus) % 4
	if _gecerli(oyuncu_t, yeni):
		parca = yeni
		return true
	if donus != 0:
		# Duvara dayalıyken döndürme: bir kare it
		for itme in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			yeni.p = parca.p + itme
			if _gecerli(oyuncu_t, yeni):
				parca = yeni
				return true
	return false


func sola() -> void:
	if _dene(Vector2i(-1, 0)):
		ses_cal("tik", -12.0)


func saga() -> void:
	if _dene(Vector2i(1, 0)):
		ses_cal("tik", -12.0)


func dondur() -> void:
	if _dene(Vector2i.ZERO, 1):
		ses_cal("tik", -8.0)


func dusur() -> void:
	if bitti or parca.is_empty():
		return
	while _dene(Vector2i(0, 1)):
		pass
	_kilitle()


func _kilitle() -> void:
	ses_cal("tas", -6.0)
	if not oyuncu_t.yerlestir(_hucreler(parca)):
		_bitir(false, "Yığının tepeye ulaştı!")
		return
	parca = {}
	oyuncu_t.yercekimi()
	var gonder := _coz_ve_goster(oyuncu_t, TAHTA, H, true)
	# Gelen engelle karşılıklı iptal, kalanı rakibe
	var iptal := mini(gonder, gelen)
	gelen -= iptal
	gonder -= iptal
	giden += gonder
	toplam_gonderilen += gonder
	if gonder > 0:
		bildir("Rakibe " + str(gonder) + " engel!")
	elif gelen > 0 and iptal == 0:
		var n := oyuncu_t.engel_dusur(mini(gelen, 6), _rng)
		gelen -= n
		toplam_alinan += n
		if n > 0:
			patlama_yazisi(TAHTA + Vector2(SUT * H / 2.0, 60), "ENGEL!", Color(0.85, 0.3, 0.25))
			ses_cal("carpma", -6.0)
	_sonraki_parca()


## Tahtayı çözer, efektleri gösterir ve gönderilecek engel sayısını döner.
func _coz_ve_goster(t: Tahta, koken: Vector2, boy: float, efekt: bool) -> int:
	var adimlar := t.coz()
	var gonder := 0
	for a in adimlar:
		gonder += int((a.sayi - 1) * a.zincir * 0.75 + a.engel * 0.25)
		var m: Vector2 = koken + (a.merkez + Vector2(0.5, 0.5)) * boy
		parcacik_patlat(m, "sari" if a.zincir == 1 else "beyaz", 6 if efekt else 3, 260.0 if efekt else 150.0)
		if efekt:
			patlama_yazisi(m, KOMBO_SOZU[mini(a.zincir, 4)], Color(1, 0.75, 0.2) if a.zincir == 1 else Color(0.95, 0.35, 0.3))
			ses_cal("kombo" if a.zincir >= 2 else "kesik", -4.0)
	return gonder


# --- Rakip yapay zekâsı ------------------------------------------------------

## Tüm sütun/yön seçeneklerini dener: kırılan taş, renk komşuluğu ve düşük yığın ödüllenir.
func en_iyi_yer(t: Tahta, pc: Dictionary, hata := 0.0) -> Dictionary:
	var en_iyi := {}
	var en_iyi_puan := -INF
	for rot in 4:
		for x in SUT:
			var d := pc.duplicate()
			d.rot = rot
			d.p = Vector2i(x, 1)
			if not _gecerli(t, d):
				continue
			while true:
				var alt := d.duplicate()
				alt.p = d.p + Vector2i(0, 1)
				if not _gecerli(t, alt):
					break
				d = alt
			var k := t.kopya()
			k.yerlestir(_hucreler(d))
			k.yercekimi()
			var puan := 0.0
			for a in k.coz():
				puan += a.sayi * 10.0 * a.zincir
			for c in _hucreler(d):
				for yon in DONUS:
					var q: Vector2i = c[0] + yon
					if q.x >= 0 and q.x < SUT and q.y >= 0 and q.y < SAT and k.h[q.y * SUT + q.x] == c[1]:
						puan += 1.5
			puan -= k.yukseklik() * 1.2 + _rng.randf() * hata
			if puan > en_iyi_puan:
				en_iyi_puan = puan
				en_iyi = d
	return en_iyi


func _rakip_hamle() -> void:
	var yer := en_iyi_yer(rakip_t, rakip_parca, 14.0 - guc * 3.0)
	rakip_parca = _yeni_parca()
	if yer.is_empty() or not rakip_t.yerlestir(_hucreler(yer)):
		_bitir(true, "Rakibin yığını taştı!")
		return
	rakip_t.yercekimi()
	var gonder := _coz_ve_goster(rakip_t, RTAHTA, RH, false)
	var iptal := mini(gonder, giden)
	giden -= iptal
	gonder -= iptal
	gelen += gonder
	if gonder == 0 and giden > 0:
		giden -= rakip_t.engel_dusur(mini(giden, 6), _rng)
	if not rakip_t.bos_mu(Vector2i(2, 1)) or not rakip_t.bos_mu(Vector2i(2, 0)):
		_bitir(true, "Rakibin yığını taştı!")


func _bitir(kazandi: bool, neden: String) -> void:
	if bitti:
		return
	bitti = true
	parca = {}
	bildir(("ZAFER! " if kazandi else "YENİLGİ! ") + neden)
	_bildirim_sure = 2.0
	patlama_yazisi(Vector2(GENISLIK / 2.0, 300), "BUUM!" if kazandi else "VUŞŞ!", Color(1, 0.8, 0.2) if kazandi else Color(0.6, 0.6, 0.7))
	ses_cal("basari" if kazandi else "hata")
	_bitis_bekle = 1.6
	set_meta("sonuc", 1.0 if kazandi else -1.0)


## Kapat düğmesi: geri çekilmek düelloyu kaybetmektir.
func teslim() -> void:
	_bitir(false, "Geri çekildin")


# --- Akış ---------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_zaman += delta
	for t in [oyuncu_t, rakip_t]:
		for i in t.ofs.size():
			if t.ofs[i] > 0.0:
				t.ofs[i] = maxf(0.0, t.ofs[i] - delta * 14.0)
	if _bitis_bekle >= 0.0:
		_bitis_bekle -= delta
		if _bitis_bekle < 0.0:
			katki.emit("duello", get_meta("sonuc", -1.0))
		return
	if bitti:
		return
	sure -= delta
	if sure <= 0.0:
		var o := oyuncu_t.dolu_sayi()
		var r := rakip_t.dolu_sayi()
		_bitir(o < r, "Süre bitti: tahtan daha boş" if o < r else "Süre bitti: rakibin tahtası daha boş")
		return
	var aralik := maxf(0.28, 0.75 - (SURE - sure) * 0.006)
	_dus_t += delta
	if _dus_t >= aralik and not parca.is_empty():
		_dus_t = 0.0
		if not _dene(Vector2i(0, 1)):
			_kilitle()
	_rakip_t += delta
	if _rakip_t >= 2.4 - 0.4 * guc:
		_rakip_t = 0.0
		_rakip_hamle()


func dokun(p: Vector2) -> void:
	var t := tus_bul(p)
	match t:
		"sol":
			sola()
		"sag":
			saga()
		"don":
			dondur()
		"dus":
			dusur()
		_:
			# Tahtaya dokunuş: sol üçte bir sola, sağ üçte bir sağa, orta döndürür
			var alan := Rect2(TAHTA, Vector2(SUT * H, SAT * H))
			if alan.has_point(p):
				var o := (p.x - TAHTA.x) / (SUT * H)
				if o < 0.33:
					sola()
				elif o > 0.67:
					saga()
				else:
					dondur()


## Test/önizleme botu: yapay zekâyla en iyi yeri bulup parçayı oraya bırakır.
func bot_hamle() -> void:
	if bitti or parca.is_empty():
		return
	var yer := en_iyi_yer(oyuncu_t, parca)
	if yer.is_empty():
		dusur()
		return
	yer.p.y = parca.p.y
	if _gecerli(oyuncu_t, yer):
		parca = yer
	dusur()


# --- Çizim ----------------------------------------------------------------

func _tas(t: Tahta, i: int, koken: Vector2, boy: float) -> void:
	var v := t.h[i]
	var x := i % SUT
	var y := float(i / SUT) - t.ofs[i]
	if y < -0.2:
		return   # tahtanın üstünden düşen engel henüz görünmez
	var r := Rect2(koken + Vector2(x, y) * boy, Vector2(boy, boy))
	if v == ENGEL:
		tas_ciz(r.grow(-1), "Grey", "01", 0.95)
		draw_line(r.position + Vector2(boy * 0.3, boy * 0.3), r.end - Vector2(boy * 0.3, boy * 0.3), Color(0.25, 0.25, 0.3), 2.0)
		draw_line(r.position + Vector2(boy * 0.7, boy * 0.3), r.position + Vector2(boy * 0.3, boy * 0.7), Color(0.25, 0.25, 0.3), 2.0)
	elif t.k[i] == 1:
		_yildiz_ciz(r, v)
	else:
		tas_ciz(r.grow(-1), RENK[v], "01")


func _yildiz_ciz(r: Rect2, v: int, alfa := 1.0) -> void:
	var parilti := 0.5 + 0.5 * sin(_zaman * 7.0 + r.position.x * 0.05)
	draw_circle(r.get_center(), r.size.x * (0.5 + parilti * 0.1), Color(1, 1, 0.8, 0.3 * alfa))
	tas_ciz(r.grow(-1), RENK[v], "09", alfa)


func _parca_ciz(pc: Dictionary, koken: Vector2, boy: float, alfa := 1.0, kayma := 0.0) -> void:
	for c in _hucreler(pc):
		var p: Vector2i = c[0]
		if p.y < 0:
			continue
		var r := Rect2(koken + (Vector2(p) + Vector2(0, kayma)) * boy, Vector2(boy, boy))
		if c[2] == 1:
			_yildiz_ciz(r, c[1], alfa)
		else:
			tas_ciz(r.grow(-1), RENK[c[1]], "01", alfa)


func _tahta_ciz(t: Tahta, koken: Vector2, boy: float) -> void:
	var alan := Rect2(koken, Vector2(SUT * boy, SAT * boy))
	draw_rect(alan.grow(5), Color(0.45, 0.3, 0.16))
	draw_rect(alan, Color(0.12, 0.09, 0.07))
	for x in range(1, SUT):
		draw_line(koken + Vector2(x * boy, 0), koken + Vector2(x * boy, SAT * boy), Color(1, 1, 1, 0.04), 1.0)
	# Tehlike çizgisi (çıkış satırı)
	draw_rect(Rect2(koken, Vector2(SUT * boy, boy)), Color(0.8, 0.2, 0.15, 0.12))
	for i in t.h.size():
		if t.h[i] != 0:
			_tas(t, i, koken, boy)


func ciz() -> void:
	# Arkadaki savaş rehberi görünmesin: gövde alanı tam opak
	draw_rect(Rect2(6, 62, size.x - 6, size.y - 100), Color(AHSAP, 1.0))
	_tahta_ciz(oyuncu_t, TAHTA, H)
	if not parca.is_empty():
		# Hayalet: düşeceği yer
		var hayalet := parca.duplicate()
		while true:
			var alt := hayalet.duplicate()
			alt.p = hayalet.p + Vector2i(0, 1)
			if not _gecerli(oyuncu_t, alt):
				break
			hayalet = alt
		_parca_ciz(hayalet, TAHTA, H, 0.28)
		var kayma := 0.0
		var alt2 := parca.duplicate()
		alt2.p = parca.p + Vector2i(0, 1)
		if _gecerli(oyuncu_t, alt2):
			kayma = clampf(_dus_t / maxf(0.28, 0.75 - (SURE - sure) * 0.006), 0.0, 1.0) * 0.5
		_parca_ciz(parca, TAHTA, H, 1.0, kayma)
	# Rakip tahtası
	metin(Vector2(RTAHTA.x, RTAHTA.y - 12), rakip_ad, 17, Color(1, 0.7, 0.6))
	_tahta_ciz(rakip_t, RTAHTA, RH)
	# Sıradaki parça
	var sx := 452.0
	metin(Vector2(sx, 110), "Sıradaki", 16, SOLUK)
	var on := {"p": Vector2i(0, 1), "rot": 0, "a": sonraki.a, "b": sonraki.b}
	_parca_ciz(on, Vector2(sx + 22, 120), 30.0)
	# Süre ve engeller
	var y := RTAHTA.y + SAT * RH + 34
	metin(Vector2(RTAHTA.x, y), "Süre", 17, SOLUK)
	metin(Vector2(RTAHTA.x + 64, y), str(ceili(maxf(sure, 0.0))), 24, Color(1, 0.85, 0.35) if sure > 10.0 else Color(1, 0.4, 0.3))
	metin(Vector2(RTAHTA.x, y + 32), "Gönderilen engel: " + str(toplam_gonderilen), 17)
	metin(Vector2(RTAHTA.x, y + 58), "Gelen engel: " + str(gelen), 17, Color(1, 0.6, 0.5) if gelen > 0 else YAZI)
	# Gelen engel uyarısı: tahtanın üstünde gri noktalar
	for i in mini(gelen, 12):
		draw_circle(TAHTA + Vector2(10 + i * 18, -10), 6, Color(0.7, 0.7, 0.75))
	# Kontrol tuşları
	var by := TAHTA.y + SAT * H + 14
	var adlar := [["sol", "Sol"], ["don", "Döndür"], ["sag", "Sağ"], ["dus", "Düşür"]]
	for i in adlar.size():
		var r := Rect2(24 + i * 130, by, 120, 72)
		tus_ciz(r, "", i == 3)
		tus_ekle(r, adlar[i][0])
		metin_ortala(Rect2(r.position + Vector2(0, 30), Vector2(r.size.x, 40)), adlar[i][1], 18, YAZI)
		_ikon(r.get_center() + Vector2(0, -12), adlar[i][0])
	metin(Vector2(24, by + 98), "Kırdığın taşlar ve kombolar rakibe engel taşı yollar.", 16, SOLUK)
	metin(Vector2(24, by + 120), "Tahtaya dokun: kenarlar kaydırır, orta döndürür.", 16, SOLUK)


func _ikon(m: Vector2, ad: String) -> void:
	var c := Color(1, 0.95, 0.84)
	match ad:
		"sol", "sag":
			var d := -1.0 if ad == "sol" else 1.0
			draw_colored_polygon(PackedVector2Array([m + Vector2(12 * d, 0), m + Vector2(-6 * d, -10), m + Vector2(-6 * d, 10)]), c)
		"don":
			draw_arc(m, 10, -PI * 0.2, PI * 1.3, 16, c, 3.0)
			var u := m + Vector2.from_angle(-PI * 0.2) * 10
			draw_colored_polygon(PackedVector2Array([u + Vector2(-6, -4), u + Vector2(5, -6), u + Vector2(2, 5)]), c)
		"dus":
			draw_line(m + Vector2(0, -12), m + Vector2(0, 4), c, 4.0)
			draw_colored_polygon(PackedVector2Array([m + Vector2(-9, 2), m + Vector2(9, 2), m + Vector2(0, 13)]), c)
