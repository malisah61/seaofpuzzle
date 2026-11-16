extends Node2D
## Keşfedilmemiş denizi örten sis. Sadece yeni hücre açılınca yeniden çizilir.

var deniz: Node2D


func _draw() -> void:
	if deniz == null:
		return
	var h := 200.0  # deniz.gd HUCRE ile aynı
	var renk := Color(0.03, 0.07, 0.12, 0.92)
	var kenar := Color(0.03, 0.07, 0.12, 0.45)
	for y in deniz.sis_h:
		for x in deniz.sis_w:
			if deniz.acik[y * deniz.sis_w + x] == 0:
				var r := Rect2(x * h, y * h, h, h)
				var komsu_acik := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < deniz.sis_w and ny < deniz.sis_h and deniz.acik[ny * deniz.sis_w + nx] == 1:
						komsu_acik = true
				draw_rect(r, kenar if komsu_acik else renk)
