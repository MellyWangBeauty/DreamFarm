extends Node2D


var display_text: String = ""
var display_color: Color = Color.WHITE
var velocity: Vector2 = Vector2(0, -24)
var lifetime: float = 0.85
var elapsed: float = 0.0
var font_size: int = 18


func setup(text: String, color: Color, world_position: Vector2) -> void:
	display_text = text
	display_color = color
	top_level = true
	z_as_relative = false
	z_index = 1000
	global_position = world_position
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	position += velocity * delta
	if elapsed >= lifetime:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	if display_text.is_empty():
		return
	var alpha := clampf(1.0 - (elapsed / lifetime), 0.0, 1.0)
	var shadow_color := Color(0, 0, 0, alpha * 0.7)
	var text_color := Color(display_color.r, display_color.g, display_color.b, alpha)
	var font := ThemeDB.fallback_font
	var baseline := Vector2(-48, 0)
	draw_string(font, baseline + Vector2(2, 2), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string(font, baseline, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
