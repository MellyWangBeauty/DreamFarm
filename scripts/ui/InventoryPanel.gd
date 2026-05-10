extends Control

signal sell_requested(item_id: String, amount: int)
signal ui_clicked
signal slot_left_pressed(slot_type: String, slot_index: int)
signal slot_left_released(slot_type: String, slot_index: int)
signal slot_hovered(slot_type: String, slot_index: int)
signal slot_unhovered(slot_type: String, slot_index: int)

const PANEL_TEXTURE := preload("res://assets/placeholder/hotbar/inventory_panel.png")
const SLOT_SCRIPT := preload("res://scripts/ui/ItemSlotUI.gd")

const GRID_COLUMNS := 8
const GRID_ROWS := 5
const SLOT_COUNT := GRID_COLUMNS * GRID_ROWS
const UI_SCALE := 0.70
const ORIGINAL_SLOT_SIZE := Vector2(68, 68)
const ORIGINAL_SLOT_STEP := Vector2(88, 84)
const ORIGINAL_GRID_OFFSET := Vector2(171, 133)

var _panel: TextureRect
var _slots: Array = []
var _tooltip: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	InventoryManager.inventory_slots_changed.connect(_refresh_slots)
	_refresh_slots()


func set_open(value: bool) -> void:
	visible = value
	if visible:
		_refresh_slots()
		_update_layout()
		_tooltip.visible = false


func is_open() -> bool:
	return visible


func clear_all_hover() -> void:
	for slot in _slots:
		slot.clear_hover_style()


func set_hover_state(slot_index: int, valid: bool) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].set_hover_style(valid)


func pulse_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].pulse()


func get_slot_global_rect(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= _slots.size():
		return Rect2()
	return Rect2(_slots[slot_index].global_position, _slots[slot_index].size)


func get_slot_index_at_global_position(global_position: Vector2) -> int:
	for index in range(_slots.size()):
		if get_slot_global_rect(index).has_point(global_position):
			return index
	return -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()


func _process(_delta: float) -> void:
	if _tooltip.visible:
		_tooltip.position = get_local_mouse_position() + Vector2(18, 18)


func _build_ui() -> void:
	_panel = TextureRect.new()
	_panel.texture = PANEL_TEXTURE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_panel)

	_tooltip = Label.new()
	_tooltip.visible = false
	_tooltip.z_index = 20
	_tooltip.add_theme_font_size_override("font_size", 16)
	_tooltip.add_theme_color_override("font_color", Color(0.20, 0.15, 0.09))
	_tooltip.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tooltip)

	for index in range(SLOT_COUNT):
		var slot: Panel = Panel.new()
		slot.set_script(SLOT_SCRIPT)
		add_child(slot)
		slot.setup("inventory", index, false)
		slot.left_pressed.connect(_on_slot_left_pressed)
		slot.left_released.connect(_on_slot_left_released)
		slot.right_clicked.connect(_on_slot_right_clicked)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(_on_slot_unhovered)
		_slots.append(slot)

	_update_layout()


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var texture_size: Vector2i = PANEL_TEXTURE.get_size()
	var panel_size: Vector2 = Vector2(texture_size.x, texture_size.y) * UI_SCALE
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) * 0.5
	var slot_size: Vector2 = ORIGINAL_SLOT_SIZE * UI_SCALE
	var slot_step: Vector2 = ORIGINAL_SLOT_STEP * UI_SCALE
	var grid_offset: Vector2 = ORIGINAL_GRID_OFFSET * UI_SCALE
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var index: int = row * GRID_COLUMNS + col
			_slots[index].position = _panel.position + grid_offset + Vector2(col * slot_step.x, row * slot_step.y)
			_slots[index].size = slot_size


func _refresh_slots() -> void:
	for index in range(_slots.size()):
		_slots[index].set_slot_data(InventoryManager.get_slot(index))


func _on_slot_left_pressed(slot_type: String, slot_index: int) -> void:
	ui_clicked.emit()
	slot_left_pressed.emit(slot_type, slot_index)


func _on_slot_left_released(slot_type: String, slot_index: int) -> void:
	slot_left_released.emit(slot_type, slot_index)


func _on_slot_right_clicked(_slot_type: String, slot_index: int) -> void:
	ui_clicked.emit()
	var slot_data: Dictionary = InventoryManager.get_slot(slot_index)
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return
	if ItemDatabase.is_sellable(item_id):
		sell_requested.emit(item_id, amount)


func _on_slot_hovered(slot_type: String, slot_index: int) -> void:
	var slot_data: Dictionary = InventoryManager.get_slot(slot_index)
	var item_id: String = String(slot_data.get("item_id", ""))
	if item_id.is_empty():
		_tooltip.visible = false
		return
	var amount: int = int(slot_data.get("amount", 0))
	_tooltip.text = "%s x%d" % [ItemDatabase.get_display_name(item_id), amount]
	_tooltip.position = get_local_mouse_position() + Vector2(18, 18)
	_tooltip.visible = true
	slot_hovered.emit(slot_type, slot_index)


func _on_slot_unhovered(slot_type: String, slot_index: int) -> void:
	_tooltip.visible = false
	slot_unhovered.emit(slot_type, slot_index)
