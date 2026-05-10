extends Control


var _icon: TextureRect
var _count_label: Label
var _active: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_ui()
	hide_drag()


func show_drag(slot_data: Dictionary) -> void:
	_build_ui()
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	_icon.texture = ItemDatabase.get_icon(item_id)
	_icon.visible = not item_id.is_empty()
	_count_label.text = str(amount) if amount > 1 else ""
	modulate = Color(1, 1, 1, 0.82)
	visible = true
	_active = true
	_update_position()


func hide_drag() -> void:
	visible = false
	_active = false


func set_drop_state(valid: bool) -> void:
	modulate = Color(1, 1, 1, 0.82) if valid else Color(1.0, 0.65, 0.65, 0.82)


func _process(_delta: float) -> void:
	if _active:
		_update_position()


func _update_position() -> void:
	position = get_viewport().get_mouse_position() + Vector2(12, 12)


func _build_ui() -> void:
	if _icon != null:
		return
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(42, 42)
	add_child(_icon)

	_count_label = Label.new()
	_count_label.offset_left = 14.0
	_count_label.offset_top = 24.0
	_count_label.offset_right = 54.0
	_count_label.offset_bottom = 44.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(0.20, 0.14, 0.08))
	_count_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.3))
	_count_label.add_theme_constant_override("shadow_offset_x", 1)
	_count_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_count_label)
