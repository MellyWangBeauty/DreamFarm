extends Panel

signal left_pressed(slot_type: String, slot_index: int)
signal left_released(slot_type: String, slot_index: int)
signal right_clicked(slot_type: String, slot_index: int)
signal hovered(slot_type: String, slot_index: int)
signal unhovered(slot_type: String, slot_index: int)

var slot_type: String = ""
var slot_index: int = -1
var item_id: String = ""
var amount: int = 0

var _icon: TextureRect
var _count_label: Label
var _number_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(40, 40)
	_build_ui()


func setup(new_slot_type: String, new_slot_index: int, show_number: bool) -> void:
	_build_ui()
	slot_type = new_slot_type
	slot_index = new_slot_index
	_number_label.visible = show_number
	_number_label.text = str(new_slot_index + 1) if new_slot_index < 9 else "0"


func set_slot_data(slot_data: Dictionary) -> void:
	_build_ui()
	item_id = String(slot_data.get("item_id", ""))
	amount = int(slot_data.get("amount", 0))
	_icon.texture = ItemDatabase.get_icon(item_id)
	_icon.visible = not item_id.is_empty()
	_count_label.text = str(amount) if amount > 1 else ""


func set_hover_style(valid: bool) -> void:
	modulate = Color(0.82, 1.0, 0.82) if valid else Color(1.0, 0.75, 0.75)


func clear_hover_style() -> void:
	modulate = Color.WHITE


func pulse() -> void:
	scale = Vector2.ONE * 1.05


func _process(delta: float) -> void:
	if scale.x > 1.0:
		scale = scale.lerp(Vector2.ONE, minf(delta * 12.0, 1.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_pressed.emit(slot_type, slot_index)
			else:
				left_released.emit(slot_type, slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(slot_type, slot_index)


func _on_mouse_entered() -> void:
	hovered.emit(slot_type, slot_index)


func _on_mouse_exited() -> void:
	unhovered.emit(slot_type, slot_index)


func _build_ui() -> void:
	if _icon != null:
		return
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.anchor_right = 1.0
	_icon.anchor_bottom = 1.0
	_icon.offset_left = 4.0
	_icon.offset_top = 4.0
	_icon.offset_right = -4.0
	_icon.offset_bottom = -6.0
	add_child(_icon)

	_count_label = Label.new()
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.offset_left = 2.0
	_count_label.offset_top = 18.0
	_count_label.offset_right = -2.0
	_count_label.offset_bottom = -2.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(0.25, 0.16, 0.08))
	_count_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	_count_label.add_theme_constant_override("shadow_offset_x", 1)
	_count_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_count_label)

	_number_label = Label.new()
	_number_label.offset_left = 2.0
	_number_label.offset_top = -2.0
	_number_label.offset_right = 14.0
	_number_label.offset_bottom = 12.0
	_number_label.add_theme_font_size_override("font_size", 9)
	_number_label.add_theme_color_override("font_color", Color(0.45, 0.27, 0.10))
	add_child(_number_label)
