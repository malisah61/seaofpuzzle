extends RefCounted
## Görsel/ses varlıklarının tek yerden yüklenmesi (önbellekli).
## Tüm varlıklar Kenney CC0 paketlerinden: bkz. varliklar/LISANS.md

const KOK := "res://varliklar/"
static var _dokular := {}
static var _font: Font


static func doku(yol: String) -> Texture2D:
	if not _dokular.has(yol):
		_dokular[yol] = load(KOK + yol)
	return _dokular[yol]


static func karo(no: int) -> Texture2D:
	return doku("karo/tile_%02d.png" % no)


## Başlık ve patlama yazıları için çizgi roman fontu. Türkçe harfler sistem fontuna düşer.
static func font() -> Font:
	if _font == null:
		var f: FontFile = load(KOK + "font/kenney_future.ttf")
		f.fallbacks = [ThemeDB.fallback_font]
		_font = f
	return _font
