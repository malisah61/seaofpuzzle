extends Node2D
## Denizde parlayan hazine sandıkları (Seafight'taki parıltılar gibi).

var deniz: Node2D
var _zaman := 0.0


func _process(delta: float) -> void:
	_zaman += delta
	queue_redraw()


func _draw() -> void:
	if deniz == null:
		return
	for i in deniz.hazineler.size():
		var p: Vector2 = deniz.hazineler[i]
		var parilti := 0.5 + 0.5 * sin(_zaman * 4.0 + i * 1.7)
		var salinim := Vector2(0, sin(_zaman * 2.0 + i) * 3.0)
		draw_circle(p, 26.0 + parilti * 8.0, Color(1.0, 0.85, 0.3, 0.12 + parilti * 0.12))
		draw_rect(Rect2(p + salinim + Vector2(-14, -9), Vector2(28, 18)), Color(0.55, 0.33, 0.14))
		draw_rect(Rect2(p + salinim + Vector2(-14, -12), Vector2(28, 7)), Color(0.66, 0.42, 0.18))
		draw_rect(Rect2(p + salinim + Vector2(-3, -6), Vector2(6, 6)), Color(1.0, 0.82, 0.25))
		var y := p + Vector2(10, -18) + salinim
		draw_line(y + Vector2(-5 * parilti, 0), y + Vector2(5 * parilti, 0), Color(1, 1, 0.8), 2.0)
		draw_line(y + Vector2(0, -5 * parilti), y + Vector2(0, 5 * parilti), Color(1, 1, 0.8), 2.0)
