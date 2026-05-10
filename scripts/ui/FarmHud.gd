extends CanvasLayer

signal tool_selected(item_id: String)
signal inventory_toggled(opened: bool)
signal sell_requested(item_id: String, amount: int)
signal ui_clicked

const TOP_PANEL_TEXTURE := preload("res://assets/placeholder/ui/hud_panel.png")
const GOLD_TEXTURE := preload("res://assets/placeholder/tools/gold_coin.png")
const WISH_STONE_TEXTURE := preload("res://assets/placeholder/tools/wish_stone.png")
const HOTBAR_SCRIPT := preload("res://scripts/ui/HotbarUI.gd")
const INVENTORY_PANEL_SCRIPT := preload("res://scripts/ui/InventoryPanel.gd")
const DRAG_ITEM_SCRIPT := preload("res://scripts/ui/DragItemUI.gd")
const HUD_SCALE := 0.38
const DAY_LABEL_POS := Vector2(108, 38)
const GOLD_ICON_POS := Vector2(40, 122)
const GOLD_LABEL_POS := Vector2(190, 126)
const WISH_ICON_POS := Vector2(40, 248)
const WISH_LABEL_POS := Vector2(190, 252)
const CROP_LABEL_POS := Vector2(505, 118)
const DAY_PROGRESS_LABEL_POS := Vector2(505, 252)
const ICON_SIZE := Vector2(92, 92)

var panel_rect: TextureRect
var day_label: Label
var gold_label: Label
var wish_stone_label: Label
var crop_label: Label
var day_progress_label: Label
var hotbar_ui
var inventory_panel
var drag_item_ui

var _pressed_slot_type: String = ""
var _pressed_slot_index: int = -1
var _pressed_mouse_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_source_type: String = ""
var _drag_source_index: int = -1


func _ready() -> void:
	_build_top_hud()
	_build_hotbar()
	_build_inventory_panel()
	_build_drag_ui()
	_connect_signals()
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not _dragging and _can_start_drag():
			if event.position.distance_to(_pressed_mouse_position) > 6.0:
				_begin_drag()
		elif _dragging:
			_update_drag_target_visual()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _dragging:
			_finish_drag()
		_clear_press_state()


func handle_global_input(event: InputEvent) -> bool:
	if _dragging:
		return true
	if hotbar_ui.handle_input(event):
		ui_clicked.emit()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			if event.keycode == KEY_ESCAPE and not inventory_panel.is_open():
				return false
			toggle_inventory()
			ui_clicked.emit()
			return true
	return false


func get_selected_item_id() -> String:
	return hotbar_ui.get_selected_item_id()


func is_inventory_open() -> bool:
	return inventory_panel.is_open()


func is_dragging() -> bool:
	return _dragging


func toggle_inventory() -> void:
	var next_state: bool = not inventory_panel.is_open()
	inventory_panel.set_open(next_state)
	if not next_state and _dragging:
		_cancel_drag()
	inventory_toggled.emit(next_state)


func pulse_selected_slot() -> void:
	hotbar_ui.pulse_selected()


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_target_visual()


func _build_top_hud() -> void:
	panel_rect = TextureRect.new()
	panel_rect.texture = TOP_PANEL_TEXTURE
	panel_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_rect.position = Vector2(16, 16)
	var texture_size: Vector2i = TOP_PANEL_TEXTURE.get_size()
	panel_rect.size = Vector2(texture_size.x, texture_size.y) * HUD_SCALE
	panel_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(panel_rect)

	day_label = _make_label(DAY_LABEL_POS * HUD_SCALE, 18)
	gold_label = _make_label(GOLD_LABEL_POS * HUD_SCALE, 18)
	wish_stone_label = _make_label(WISH_LABEL_POS * HUD_SCALE, 18)
	crop_label = _make_label(CROP_LABEL_POS * HUD_SCALE, 15)
	day_progress_label = _make_label(DAY_PROGRESS_LABEL_POS * HUD_SCALE, 13)
	panel_rect.add_child(day_label)
	panel_rect.add_child(gold_label)
	panel_rect.add_child(wish_stone_label)
	panel_rect.add_child(crop_label)
	panel_rect.add_child(day_progress_label)

	var gold_icon: TextureRect = _make_icon(GOLD_TEXTURE, GOLD_ICON_POS * HUD_SCALE, ICON_SIZE * HUD_SCALE)
	var wish_icon: TextureRect = _make_icon(WISH_STONE_TEXTURE, WISH_ICON_POS * HUD_SCALE, ICON_SIZE * HUD_SCALE)
	panel_rect.add_child(gold_icon)
	panel_rect.add_child(wish_icon)


func _build_hotbar() -> void:
	hotbar_ui = Control.new()
	hotbar_ui.name = "HotbarUI"
	hotbar_ui.set_script(HOTBAR_SCRIPT)
	add_child(hotbar_ui)


func _build_inventory_panel() -> void:
	inventory_panel = Control.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.set_script(INVENTORY_PANEL_SCRIPT)
	add_child(inventory_panel)


func _build_drag_ui() -> void:
	drag_item_ui = Control.new()
	drag_item_ui.name = "DragItemUI"
	drag_item_ui.set_script(DRAG_ITEM_SCRIPT)
	add_child(drag_item_ui)


func _connect_signals() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	CurrencyManager.wish_stone_changed.connect(_on_wish_stone_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	TimeManager.day_advanced.connect(_on_day_changed)
	TimeManager.day_progress_changed.connect(_on_day_progress_changed)
	_hotbar_manager().selected_slot_changed.connect(_on_hotbar_manager_selected)
	hotbar_ui.selected_item_changed.connect(_on_hotbar_selected)
	hotbar_ui.ui_clicked.connect(_relay_ui_click)
	hotbar_ui.slot_left_pressed.connect(_on_slot_left_pressed)
	hotbar_ui.slot_left_released.connect(_on_slot_left_released)
	hotbar_ui.slot_hovered.connect(_on_slot_hovered)
	hotbar_ui.slot_unhovered.connect(_on_slot_unhovered)
	inventory_panel.sell_requested.connect(_on_sell_requested)
	inventory_panel.ui_clicked.connect(_relay_ui_click)
	inventory_panel.slot_left_pressed.connect(_on_slot_left_pressed)
	inventory_panel.slot_left_released.connect(_on_slot_left_released)
	inventory_panel.slot_hovered.connect(_on_slot_hovered)
	inventory_panel.slot_unhovered.connect(_on_slot_unhovered)


func _refresh_all() -> void:
	_on_day_changed(TimeManager.day)
	_on_day_progress_changed(0.0)
	_on_gold_changed(CurrencyManager.gold)
	_on_wish_stone_changed(CurrencyManager.wish_stone)
	_on_inventory_changed(InventoryManager.get_all_items())
	tool_selected.emit(get_selected_item_id())


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.86, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_icon(texture: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = pos
	icon.size = size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day


func _on_day_progress_changed(progress: float) -> void:
	day_progress_label.text = "Next growth tick %d%%" % int(progress * 100.0)


func _on_gold_changed(value: int) -> void:
	gold_label.text = "%d" % value


func _on_wish_stone_changed(value: int) -> void:
	wish_stone_label.text = "%d" % value


func _on_inventory_changed(_items: Dictionary) -> void:
	crop_label.text = "Wheat %d  Potato %d  Carrot %d" % [
		InventoryManager.get_item_count("wheat"),
		InventoryManager.get_item_count("potato"),
		InventoryManager.get_item_count("carrot")
	]


func _on_hotbar_manager_selected(index: int, item_id: String) -> void:
	_on_hotbar_selected(item_id, index)


func _on_hotbar_selected(item_id: String, _slot_index: int) -> void:
	tool_selected.emit(item_id)


func _on_sell_requested(item_id: String, amount: int) -> void:
	sell_requested.emit(item_id, amount)


func _relay_ui_click() -> void:
	ui_clicked.emit()


func _on_slot_left_pressed(slot_type: String, slot_index: int) -> void:
	if not inventory_panel.is_open():
		return
	_pressed_slot_type = slot_type
	_pressed_slot_index = slot_index
	_pressed_mouse_position = get_viewport().get_mouse_position()


func _on_slot_left_released(_slot_type: String, _slot_index: int) -> void:
	if not _dragging:
		_clear_press_state()


func _on_slot_hovered(_slot_type: String, _slot_index: int) -> void:
	if _dragging:
		_update_drag_target_visual()


func _on_slot_unhovered(_slot_type: String, _slot_index: int) -> void:
	if _dragging:
		_update_drag_target_visual()


func _can_start_drag() -> bool:
	if _pressed_slot_type.is_empty() or _pressed_slot_index < 0:
		return false
	var slot_data: Dictionary = _get_slot_data(_pressed_slot_type, _pressed_slot_index)
	return not String(slot_data.get("item_id", "")).is_empty()


func _begin_drag() -> void:
	var slot_data: Dictionary = _get_slot_data(_pressed_slot_type, _pressed_slot_index)
	if String(slot_data.get("item_id", "")).is_empty():
		return
	_dragging = true
	_drag_source_type = _pressed_slot_type
	_drag_source_index = _pressed_slot_index
	drag_item_ui.show_drag(slot_data)
	_update_drag_target_visual()


func _finish_drag() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var target_type: String = ""
	var target_index: int = -1
	var hotbar_index: int = int(hotbar_ui.get_slot_index_at_global_position(mouse_position))
	if hotbar_index != -1:
		target_type = "hotbar"
		target_index = hotbar_index
	else:
		var inventory_index: int = int(inventory_panel.get_slot_index_at_global_position(mouse_position))
		if inventory_index != -1:
			target_type = "inventory"
			target_index = inventory_index
	if not target_type.is_empty():
		_swap_slots(_drag_source_type, _drag_source_index, target_type, target_index)
		ui_clicked.emit()
	hotbar_ui.clear_all_hover()
	inventory_panel.clear_all_hover()
	drag_item_ui.hide_drag()
	_dragging = false
	_drag_source_type = ""
	_drag_source_index = -1


func _cancel_drag() -> void:
	hotbar_ui.clear_all_hover()
	inventory_panel.clear_all_hover()
	drag_item_ui.hide_drag()
	_dragging = false
	_drag_source_type = ""
	_drag_source_index = -1
	_clear_press_state()


func _clear_press_state() -> void:
	_pressed_slot_type = ""
	_pressed_slot_index = -1
	_pressed_mouse_position = Vector2.ZERO


func _update_drag_target_visual() -> void:
	hotbar_ui.clear_all_hover()
	inventory_panel.clear_all_hover()
	if not _dragging:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var hotbar_index: int = int(hotbar_ui.get_slot_index_at_global_position(mouse_position))
	if hotbar_index != -1:
		hotbar_ui.set_hover_state(hotbar_index, true)
		drag_item_ui.set_drop_state(true)
		return
	var inventory_index: int = int(inventory_panel.get_slot_index_at_global_position(mouse_position))
	if inventory_index != -1:
		inventory_panel.set_hover_state(inventory_index, true)
		drag_item_ui.set_drop_state(true)
		return
	drag_item_ui.set_drop_state(false)


func _swap_slots(source_type: String, source_index: int, target_type: String, target_index: int) -> void:
	if source_type == target_type and source_index == target_index:
		return
	var source_data: Dictionary = _get_slot_data(source_type, source_index)
	var target_data: Dictionary = _get_slot_data(target_type, target_index)
	_set_slot_data(source_type, source_index, target_data)
	_set_slot_data(target_type, target_index, source_data)
	_pulse_slot(target_type, target_index)
	_pulse_slot(source_type, source_index)


func _get_slot_data(slot_type: String, slot_index: int) -> Dictionary:
	match slot_type:
		"hotbar":
			return _hotbar_manager().get_slot(slot_index)
		"inventory":
			return InventoryManager.get_slot(slot_index)
	return {
		"item_id": "",
		"amount": 0
	}


func _set_slot_data(slot_type: String, slot_index: int, slot_data: Dictionary) -> void:
	match slot_type:
		"hotbar":
			_hotbar_manager().set_slot(slot_index, slot_data)
		"inventory":
			InventoryManager.set_slot(slot_index, slot_data)


func _pulse_slot(slot_type: String, slot_index: int) -> void:
	match slot_type:
		"hotbar":
			hotbar_ui.set_hover_state(slot_index, true)
			if slot_index == int(_hotbar_manager().selected_index):
				hotbar_ui.pulse_selected()
			else:
				hotbar_ui.pulse_slot(slot_index)
		"inventory":
			inventory_panel.pulse_slot(slot_index)


func _hotbar_manager() -> Node:
	return get_node("/root/HotbarManager")
