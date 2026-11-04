extends Control

## A single card face rendered into a clipping parent. Used by the X2 shelf so
## the deck shows only its top 30% while keeping the true 5:7 card geometry.

var def: CardDef
var token: String = "A"
var face_down: bool = true
var display_scale: float = 1.0

func _draw() -> void:
	if def == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(display_scale, display_scale))
	CardComposer.draw(self, def, null, token, {"face_down": face_down})
