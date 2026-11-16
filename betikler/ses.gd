extends Node
## Basit ses yöneticisi: "ses" grubundaki bu düğüme cal("ad") ile ulaşılır.

const SESLER := ["tik", "eslesme", "kombo", "hata", "dus", "ac", "cekic", "tahta", "tas", "carpma", "altin", "yelken", "gicirti", "basari"]
var _akislar := {}
var _calarlar: Array = []
var _sira := 0
var acik := true


func _ready() -> void:
	add_to_group("ses")
	for ad in SESLER:
		var yol := "res://varliklar/ses/%s.ogg" % ad
		if ResourceLoader.exists(yol):
			_akislar[ad] = load(yol)
	for i in 8:
		var c := AudioStreamPlayer.new()
		add_child(c)
		_calarlar.append(c)


func cal(ad: String, ses_db := 0.0, perde_oynama := 0.08) -> void:
	if not acik or not _akislar.has(ad):
		return
	var c: AudioStreamPlayer = _calarlar[_sira]
	_sira = (_sira + 1) % _calarlar.size()
	c.stream = _akislar[ad]
	c.volume_db = ses_db
	c.pitch_scale = 1.0 + randf_range(-perde_oynama, perde_oynama)
	c.play()
