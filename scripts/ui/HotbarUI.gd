extends Control

signal selected_item_changed(item_id: String, slot_index: int)
signal ui_clicked
signal slot_left_pressed(slot_type: String, slot_index: int)
signal slot_left_released(slot_type: String, slot_index: int)
signal slot_hovered(slot_type: String, slot_index: int)
signal slot_unhovered(slot_type: String, slot_index: int)

const HOTBAR_TEXTURE := preload("res://assets/placeholder/hotbar/hotbar_background.png")
const HIGHLIGHT_TEXTURE := preload("res://assets/placeholder/hotbar/hotbar_highlight.png")
const SLOT_SCRIPT := preload("res://scripts/ui/ItemSlotUI.gd")

const SLOT_COUNT := 10
const UI_SCALE := 0.38
const ORIGINAL_SLOT_SIZE := Vector2(100, 100)
const ORIGINAL_SLOT_STEP := 114.0
const ORIGINAL_BACKGROUND_OFFSET := Vector2(160, 84)

var selected_index: int = 0
var _background: TextureRect
var _highlight: TextureRect
var _slots: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_hotbar_manager().hotbar_changed.connect(_refresh_slots)
	_hotbar_manager().selected_slot_changed.connect(_on_selected_slot_changed)
	_refresh_slots()
	_on_selected_slot_changed(_hotbar_manager().selected_index, _hotbar_manager().get_selected_item_id())


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var next_index: int = _keycode_to_hotbar_index(event.keycode)
		if next_index >= 0:
			_hotbar_manager().set_selected_index(next_index)
			ui_clicked.emit()
			return true
	elif event is InputEventMouseButton and event.pressed:
		var wheel_direction: int = _mouse_wheel_direction(event.button_index)
		if wheel_direction != 0:
			_select_relative_slot(wheel_direction)
			ui_clicked.emit()
			return true
	return false


func get_selected_item_id() -> String:
	return _hotbar_manager().get_selected_item_id()


func pulse_selected() -> void:
	if selected_index >= 0 and selected_index < _slots.size():
		_slots[selected_index].pulse()
	_highlight.scale = Vector2.ONE * 1.06


func pulse_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].pulse()


func clear_all_hover() -> void:
	for slot in _slots:
		slot.clear_hover_style()


func set_hover_state(slot_index: int, valid: bool) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].set_hover_style(valid)


func get_slot_global_rect(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= _slots.size():
		return Rect2()
	return Rect2(_slots[slot_index].global_position, _slots[slot_index].size)


func get_slot_index_at_global_position(global_position: Vector2) -> int:
	for index in range(_slots.size()):
		if get_slot_global_rect(index).has_point(global_position):
			return index
	return -1


func _process(delta: float) -> void:
	if _highlight.scale.x > 1.0:
		_highlight.scale = _highlight.scale.lerp(Vector2.ONE, minf(delta * 12.0, 1.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_ui()


func _build_ui() -> void:
	if _background != null:
		return
	_background = TextureRect.new()
	_background.texture = HOTBAR_TEXTURE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_background)

	_highlight = TextureRect.new()
	_highlight.texture = HIGHLIGHT_TEXTURE
	_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_highlight)

	for index in range(SLOT_COUNT):
		var slot: Panel = Panel.new()
		slot.set_script(SLOT_SCRIPT)
		add_child(slot)
		slot.setup("hotbar", index, true)
		slot.left_pressed.connect(_on_slot_left_pressed)
		slot.left_released.connect(_on_slot_left_released)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		_slots.append(slot)

	_position_ui()


func _position_ui() -> void:
	if _background == null:
		return
	var texture_size: Vector2i = HOTBAR_TEXTURE.get_size()
	var background_size: Vector2 = Vector2(texture_size.x, texture_size.y) * UI_SCALE
	var viewport_size: Vector2 = get_viewport_rect().size
	_background.size = background_size
	_background.position = Vector2((viewport_size.x - background_size.x) * 0.5, viewport_size.y - background_size.y - 10.0)
	var slot_size: Vector2 = ORIGINAL_SLOT_SIZE * UI_SCALE
	var slot_step: float = ORIGINAL_SLOT_STEP * UI_SCALE
	var slot_origin: Vector2 = _background.position + ORIGINAL_BACKGROUND_OFFSET * UI_SCALE
	for index in range(_slots.size()):
		var slot_position: Vector2 = slot_origin + Vector2(index * slot_step, 0)
		_slots[index].position = slot_position
		_slots[index].size = slot_size
	_position_highlight()


func _position_highlight() -> void:
	if _highlight == null:
		return
	var slot_step: float = ORIGINAL_SLOT_STEP * UI_SCALE
	var slot_origin: Vector2 = _background.position + ORIGINAL_BACKGROUND_OFFSET * UI_SCALE
	var highlight_size: Vector2 = Vector2(120, 120) * UI_SCALE
	_highlight.size = highlight_size
	_highlight.position = slot_origin + Vector2(selected_index * slot_step, 0) - Vector2(12, 10) * UI_SCALE


func _refresh_slots() -> void:
	for index in range(_slots.size()):
		_slots[index].set_slot_data(_hotbar_manager().get_slot(index))


func _on_selected_slot_changed(index: int, item_id: String) -> void:
	selected_index = index
	_position_highlight()
	selected_item_changed.emit(item_id, index)


func _keycode_to_hotbar_index(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		KEY_0:
			return 9
	return -1


func _mouse_wheel_direction(button_index: MouseButton) -> int:
	match button_index:
		MOUSE_BUTTON_WHEEL_UP:
			return -1
		MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0


func _select_relative_slot(direction: int) -> void:
	var slot_count: int = max(_slots.size(), 1)
	var next_index: int = posmod(_hotbar_manager().selected_index + direction, slot_count)
	_hotbar_manager().set_selected_index(next_index)


func _on_slot_left_pressed(slot_type: String, slot_index: int) -> void:
	ui_clicked.emit()
	_hotbar_manager().set_selected_index(slot_index)
	slot_left_pressed.emit(slot_type, slot_index)


func _on_slot_left_released(slot_type: String, slot_index: int) -> void:
	slot_left_released.emit(slot_type, slot_index)


func _on_slot_hovered(slot_type: String, slot_index: int) -> void:
	slot_hovered.emit(slot_type, slot_index)


func _on_slot_unhovered(slot_type: String, slot_index: int) -> void:
	slot_unhovered.emit(slot_type, slot_index)


func _hotbar_manager() -> Node:
	return get_node("/root/HotbarManager")
