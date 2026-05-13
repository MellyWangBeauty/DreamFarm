extends Control

signal slot_left_pressed(slot_type: String, slot_index: int)
signal slot_left_released(slot_type: String, slot_index: int)
signal slot_hovered(slot_type: String, slot_index: int)
signal slot_unhovered(slot_type: String, slot_index: int)

const SLOT_SCRIPT := preload("res://scripts/ui/ItemSlotUI.gd")
const MAX_SLOT_COUNT := 36
const SLOT_SIZE := Vector2(44, 44)
const SLOT_STEP := Vector2(48, 48)

var _background: Panel
var _title_label: Label
var _slots: Array = []
var _slot_style: StyleBoxFlat
var _slot_data: Array = []
var _columns: int = 4
var _rows: int = 4


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_chest(chest_name: String, columns: int, rows: int, slots: Array) -> void:
	_columns = clampi(columns, 1, 6)
	_rows = clampi(rows, 1, 6)
	_slot_data = _normalize_slots(slots, _columns * _rows)
	_title_label.text = chest_name
	visible = true
	_update_layout()
	_refresh_slots()


func close_chest() -> void:
	visible = false


func is_open() -> bool:
	return visible


func get_slots() -> Array:
	var result: Array = []
	for slot_data in _slot_data:
		result.append(slot_data.duplicate(true))
	return result


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= _slot_data.size():
		return _make_empty_slot()
	return _slot_data[index].duplicate(true)


func set_slot(index: int, slot_data: Dictionary) -> void:
	if index < 0 or index >= _slot_data.size():
		return
	_slot_data[index] = _normalize_slot(slot_data)
	_refresh_slots()


func clear_all_hover() -> void:
	for slot in _slots:
		slot.clear_hover_style()


func set_hover_state(slot_index: int, valid: bool) -> void:
	if slot_index >= 0 and slot_index < _slots.size() and _slots[slot_index].visible:
		_slots[slot_index].set_hover_style(valid)


func pulse_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size() and _slots[slot_index].visible:
		_slots[slot_index].pulse()


func get_slot_global_rect(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= _slots.size() or not _slots[slot_index].visible:
		return Rect2()
	return Rect2(_slots[slot_index].global_position, _slots[slot_index].size)


func get_slot_index_at_global_position(screen_position: Vector2) -> int:
	for index in range(_slot_data.size()):
		if get_slot_global_rect(index).has_point(screen_position):
			return index
	return -1


func get_panel_global_rect() -> Rect2:
	if _background == null:
		return Rect2()
	return Rect2(_background.global_position, _background.size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()


func _build_ui() -> void:
	_background = Panel.new()
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.95, 0.89, 0.78, 0.97)
	background_style.border_color = Color(0.58, 0.41, 0.21, 0.96)
	background_style.set_border_width_all(3)
	background_style.set_corner_radius_all(12)
	_background.add_theme_stylebox_override("panel", background_style)
	add_child(_background)

	_title_label = Label.new()
	_title_label.position = Vector2(24, 18)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	_background.add_child(_title_label)

	_slot_style = _make_slot_style()
	for index in range(MAX_SLOT_COUNT):
		var slot: Panel = Panel.new()
		slot.set_script(SLOT_SCRIPT)
		_background.add_child(slot)
		slot.setup("chest", index, false)
		slot.add_theme_stylebox_override("panel", _slot_style)
		slot.left_pressed.connect(_on_slot_left_pressed)
		slot.left_released.connect(_on_slot_left_released)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		_slots.append(slot)


func _update_layout() -> void:
	if _background == null:
		return
	var panel_size := Vector2(56 + _columns * SLOT_STEP.x, 86 + _rows * SLOT_STEP.y)
	var viewport_size: Vector2 = get_viewport_rect().size
	_background.size = panel_size
	_background.position = Vector2(viewport_size.x - panel_size.x - 24.0, (viewport_size.y - panel_size.y) * 0.5)
	for index in range(_slots.size()):
		var slot: Panel = _slots[index]
		slot.visible = index < _slot_data.size()
		if not slot.visible:
			continue
		var row: int = floori(float(index) / float(_columns))
		var column: int = index % _columns
		slot.position = Vector2(28, 64) + Vector2(column * SLOT_STEP.x, row * SLOT_STEP.y)
		slot.size = SLOT_SIZE
		slot.add_theme_stylebox_override("panel", _slot_style)


func _refresh_slots() -> void:
	for index in range(_slots.size()):
		if index < _slot_data.size():
			_slots[index].set_slot_data(_slot_data[index])
		else:
			_slots[index].set_slot_data(_make_empty_slot())


func _on_slot_left_pressed(slot_type: String, slot_index: int) -> void:
	slot_left_pressed.emit(slot_type, slot_index)


func _on_slot_left_released(slot_type: String, slot_index: int) -> void:
	slot_left_released.emit(slot_type, slot_index)


func _on_slot_hovered(slot_type: String, slot_index: int) -> void:
	slot_hovered.emit(slot_type, slot_index)


func _on_slot_unhovered(slot_type: String, slot_index: int) -> void:
	slot_unhovered.emit(slot_type, slot_index)


func _normalize_slots(slots: Array, slot_count: int) -> Array:
	var result: Array = []
	for index in range(slot_count):
		if index < slots.size():
			result.append(_normalize_slot(slots[index]))
		else:
			result.append(_make_empty_slot())
	return result


func _normalize_slot(slot_data: Dictionary) -> Dictionary:
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return _make_empty_slot()
	return {
		"item_id": item_id,
		"amount": amount
	}


func _make_empty_slot() -> Dictionary:
	return {
		"item_id": "",
		"amount": 0
	}


func _make_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.72, 0.46, 0.55)
	style.border_color = Color(0.58, 0.38, 0.17, 0.52)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(1.0, 0.96, 0.82, 0.28)
	style.shadow_size = 2
	style.shadow_offset = Vector2(1, 1)
	return style
