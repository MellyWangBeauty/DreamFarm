extends CanvasLayer

signal tool_selected(item_id: String)
signal inventory_toggled(opened: bool)
signal buy_requested(item_id: String, amount: int)
signal sell_requested(item_id: String, amount: int)
signal ui_clicked

const TOP_PANEL_TEXTURE := preload("res://assets/placeholder/ui/hud_panel.png")
const GOLD_TEXTURE := preload("res://assets/placeholder/tools/gold_coin.png")
const HOTBAR_SCRIPT := preload("res://scripts/ui/HotbarUI.gd")
const INVENTORY_PANEL_SCRIPT := preload("res://scripts/ui/InventoryPanel.gd")
const SHOP_PANEL_SCRIPT := preload("res://scripts/ui/ShopPanel.gd")
const CHEST_PANEL_SCRIPT := preload("res://scripts/ui/ChestPanel.gd")
const WORKBENCH_PANEL_SCRIPT := preload("res://scripts/ui/WorkbenchPanel.gd")
const DRAG_ITEM_SCRIPT := preload("res://scripts/ui/DragItemUI.gd")
const TRADE_DIALOG_SCRIPT := preload("res://scripts/ui/TradeQuantityDialog.gd")
const HUD_SCALE := 0.15
const DAY_LABEL_POS := Vector2(300, 120)
const GOLD_ICON_POS := Vector2(350, 250)
const GOLD_LABEL_POS := Vector2(610, 240)
const GOLD_LABEL_SIZE := Vector2(120, 28)
const ICON_SIZE := Vector2(140, 140)

var panel_rect: TextureRect
var day_label: Label
var gold_label: Label
var wish_stone_label: Label
var crop_label: Label
var day_progress_label: Label
var hotbar_ui
var inventory_panel
var shop_panel
var chest_panel
var workbench_panel
var drag_item_ui
var trade_dialog
var quick_buttons_bar: HBoxContainer
var settings_panel: Panel
var settings_controls_label: Label
var item_tooltip: Label

var _pressed_slot_type: String = ""
var _pressed_slot_index: int = -1
var _pressed_mouse_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_source_type: String = ""
var _drag_source_index: int = -1
var _last_day_progress: float = 0.0
var _shop_open: bool = false
var _settings_open: bool = false
var _chest_open: bool = false
var _workbench_open: bool = false
var _active_chest_data: Dictionary = {}
var _pending_craft_recipe_id: String = ""


func _ready() -> void:
	_build_top_hud()
	_build_hotbar()
	_build_inventory_panel()
	_build_shop_panel()
	_build_chest_panel()
	_build_workbench_panel()
	_build_drag_ui()
	_build_trade_dialog()
	_build_item_tooltip()
	_build_quick_buttons()
	_build_settings_panel()
	_connect_signals()
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _close_open_panel_from_blank_click(event.position):
			get_viewport().set_input_as_handled()
			return
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
	if trade_dialog.is_open():
		return true
	if _settings_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_settings()
			ui_clicked.emit()
		return true
	if _workbench_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_workbench()
		ui_clicked.emit()
		return true
	if _chest_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_chest()
		ui_clicked.emit()
		return true
	if hotbar_ui.handle_input(event):
		ui_clicked.emit()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			toggle_shop()
			ui_clicked.emit()
			return true
		if event.keycode == KEY_ESCAPE:
			if _shop_open:
				close_shop()
				ui_clicked.emit()
				return true
			if inventory_panel.is_open():
				toggle_inventory()
				ui_clicked.emit()
				return true
			open_settings()
			ui_clicked.emit()
			return true
		if event.keycode == KEY_B:
			if _shop_open:
				return true
			toggle_inventory()
			ui_clicked.emit()
			return true
	return false


func get_selected_item_id() -> String:
	return hotbar_ui.get_selected_item_id()


func is_inventory_open() -> bool:
	return inventory_panel.is_open() or _chest_open or _workbench_open


func is_dragging() -> bool:
	return _dragging


func toggle_inventory() -> void:
	if _chest_open:
		close_chest()
		return
	if _shop_open or _settings_open:
		return
	var next_state: bool = not inventory_panel.is_open()
	inventory_panel.set_open(next_state, "center")
	if not next_state and _dragging:
		_cancel_drag()
	inventory_toggled.emit(next_state)


func toggle_shop() -> void:
	if _shop_open:
		close_shop()
	else:
		open_shop()


func open_shop() -> void:
	if _chest_open:
		close_chest()
	if _workbench_open:
		close_workbench()
	if _settings_open:
		close_settings()
	_shop_open = true
	inventory_panel.set_open(true, "left")
	shop_panel.set_open(true)
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(true)


func close_shop() -> void:
	_shop_open = false
	shop_panel.set_open(false)
	inventory_panel.set_open(false, "center")
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(false)


func toggle_settings() -> void:
	if _settings_open:
		close_settings()
	else:
		open_settings()


func open_settings() -> void:
	if _chest_open:
		close_chest()
	if _workbench_open:
		close_workbench()
	if _shop_open:
		close_shop()
	if inventory_panel.is_open():
		inventory_panel.set_open(false, "center")
		inventory_toggled.emit(false)
	_settings_open = true
	settings_panel.visible = true
	if _dragging:
		_cancel_drag()


func close_settings() -> void:
	_settings_open = false
	settings_panel.visible = false
	settings_controls_label.visible = false
	if _dragging:
		_cancel_drag()


func open_chest(chest_data: Dictionary) -> void:
	if _shop_open:
		close_shop()
	if _settings_open:
		close_settings()
	if _workbench_open:
		close_workbench()
	_active_chest_data = chest_data
	var item_id: String = String(chest_data.get("item_id", ""))
	var columns: int = ItemDatabase.get_container_columns(item_id)
	var rows: int = ItemDatabase.get_container_rows(item_id)
	_chest_open = true
	inventory_panel.set_open(true, "left")
	chest_panel.open_chest(ItemDatabase.get_display_name(item_id), columns, rows, chest_data.get("slots", []))
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(true)


func close_chest() -> void:
	if not _chest_open:
		return
	_active_chest_data["slots"] = chest_panel.get_slots()
	_chest_open = false
	chest_panel.close_chest()
	inventory_panel.set_open(false, "center")
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(false)


func flush_open_chest() -> void:
	if _chest_open:
		_active_chest_data["slots"] = chest_panel.get_slots()


func open_workbench() -> void:
	if _shop_open:
		close_shop()
	if _settings_open:
		close_settings()
	if _chest_open:
		close_chest()
	_workbench_open = true
	inventory_panel.set_open(true, "left")
	workbench_panel.set_open(true)
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(true)


func close_workbench() -> void:
	if not _workbench_open:
		return
	_workbench_open = false
	workbench_panel.set_open(false)
	inventory_panel.set_open(false, "center")
	if _dragging:
		_cancel_drag()
	inventory_toggled.emit(false)


func _close_open_panel_from_blank_click(mouse_position: Vector2) -> bool:
	if trade_dialog.is_open() or _dragging:
		return false
	if not inventory_panel.is_open() and not _shop_open and not _settings_open and not _chest_open:
		return false
	if _is_point_inside_open_ui(mouse_position):
		return false
	if _shop_open:
		close_shop()
	elif _settings_open:
		close_settings()
	elif _chest_open:
		close_chest()
	elif _workbench_open:
		close_workbench()
	else:
		toggle_inventory()
	ui_clicked.emit()
	return true


func _is_point_inside_open_ui(mouse_position: Vector2) -> bool:
	if quick_buttons_bar != null and quick_buttons_bar.get_global_rect().has_point(mouse_position):
		return true
	if hotbar_ui != null and int(hotbar_ui.get_slot_index_at_global_position(mouse_position)) != -1:
		return true
	if inventory_panel.is_open() and inventory_panel.get_panel_global_rect().has_point(mouse_position):
		return true
	if _shop_open and shop_panel.get_panel_global_rect().has_point(mouse_position):
		return true
	if _chest_open and chest_panel.get_panel_global_rect().has_point(mouse_position):
		return true
	if _workbench_open and workbench_panel.get_panel_global_rect().has_point(mouse_position):
		return true
	if _settings_open and settings_panel.get_global_rect().has_point(mouse_position):
		return true
	return false


func pulse_selected_slot() -> void:
	hotbar_ui.pulse_selected()


func consume_selected_item(amount: int) -> bool:
	return _hotbar_manager().remove_from_slot(_hotbar_manager().selected_index, amount)


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_target_visual()
	if item_tooltip != null and item_tooltip.visible:
		item_tooltip.position = get_viewport().get_mouse_position() + Vector2(18, 18)


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

	day_label = _make_label(DAY_LABEL_POS * HUD_SCALE, 14)
	gold_label = _make_label(GOLD_LABEL_POS * HUD_SCALE, 16)
	gold_label.size = GOLD_LABEL_SIZE * HUD_SCALE
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wish_stone_label = _make_label(Vector2.ZERO, 1)
	crop_label = _make_label(Vector2.ZERO, 1)
	day_progress_label = _make_label(Vector2.ZERO, 1)
	panel_rect.add_child(day_label)
	panel_rect.add_child(gold_label)
	wish_stone_label.visible = false
	crop_label.visible = false
	day_progress_label.visible = false

	var gold_icon: TextureRect = _make_icon(GOLD_TEXTURE, GOLD_ICON_POS * HUD_SCALE, ICON_SIZE * HUD_SCALE)
	panel_rect.add_child(gold_icon)


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


func _build_shop_panel() -> void:
	shop_panel = Control.new()
	shop_panel.name = "ShopPanel"
	shop_panel.set_script(SHOP_PANEL_SCRIPT)
	add_child(shop_panel)


func _build_chest_panel() -> void:
	chest_panel = Control.new()
	chest_panel.name = "ChestPanel"
	chest_panel.set_script(CHEST_PANEL_SCRIPT)
	add_child(chest_panel)


func _build_workbench_panel() -> void:
	workbench_panel = Control.new()
	workbench_panel.name = "WorkbenchPanel"
	workbench_panel.set_script(WORKBENCH_PANEL_SCRIPT)
	add_child(workbench_panel)


func _build_drag_ui() -> void:
	drag_item_ui = Control.new()
	drag_item_ui.name = "DragItemUI"
	drag_item_ui.set_script(DRAG_ITEM_SCRIPT)
	add_child(drag_item_ui)


func _build_trade_dialog() -> void:
	trade_dialog = Control.new()
	trade_dialog.name = "TradeQuantityDialog"
	trade_dialog.set_script(TRADE_DIALOG_SCRIPT)
	add_child(trade_dialog)


func _build_item_tooltip() -> void:
	item_tooltip = Label.new()
	item_tooltip.name = "ItemTooltip"
	item_tooltip.visible = false
	item_tooltip.z_index = 200
	item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_tooltip.add_theme_font_size_override("font_size", 16)
	item_tooltip.add_theme_color_override("font_color", Color(0.20, 0.15, 0.09))
	item_tooltip.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	item_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	item_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	add_child(item_tooltip)


func _build_quick_buttons() -> void:
	quick_buttons_bar = HBoxContainer.new()
	quick_buttons_bar.name = "QuickButtons"
	quick_buttons_bar.anchor_left = 1.0
	quick_buttons_bar.anchor_right = 1.0
	quick_buttons_bar.offset_left = -204.0
	quick_buttons_bar.offset_top = 16.0
	quick_buttons_bar.offset_right = -16.0
	quick_buttons_bar.offset_bottom = 76.0
	quick_buttons_bar.add_theme_constant_override("separation", 8)
	add_child(quick_buttons_bar)

	quick_buttons_bar.add_child(_make_quick_button("背包", "B", Callable(self, "_on_inventory_button_pressed")))
	quick_buttons_bar.add_child(_make_quick_button("商店", "P", Callable(self, "_on_shop_button_pressed")))
	quick_buttons_bar.add_child(_make_quick_button("设置", "ESC", Callable(self, "_on_settings_button_pressed")))


func _build_settings_panel() -> void:
	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -120.0
	settings_panel.offset_top = -180.0
	settings_panel.offset_right = 120.0
	settings_panel.offset_bottom = 180.0
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.95, 0.89, 0.78, 0.97)
	panel_style.border_color = Color(0.58, 0.41, 0.21, 0.96)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(settings_panel)

	var title_label: Label = Label.new()
	title_label.text = "设置"
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	settings_panel.add_child(title_label)

	var button_box: VBoxContainer = VBoxContainer.new()
	button_box.position = Vector2(28, 62)
	button_box.size = Vector2(184, 204)
	button_box.add_theme_constant_override("separation", 12)
	settings_panel.add_child(button_box)

	button_box.add_child(_make_settings_button("存档", Callable(self, "_on_save_button_pressed")))
	button_box.add_child(_make_settings_button("读档", Callable(self, "_on_load_button_pressed")))
	button_box.add_child(_make_settings_button("操作", Callable(self, "_on_controls_button_pressed")))
	button_box.add_child(_make_settings_button("退出", Callable(self, "_on_quit_button_pressed")))

	settings_controls_label = Label.new()
	settings_controls_label.visible = false
	settings_controls_label.position = Vector2(28, 276)
	settings_controls_label.size = Vector2(184, 70)
	settings_controls_label.text = "移动：WASD / 方向键\n使用工具：鼠标左键 / 空格\n丢弃：G  背包：B  商店：P\n设置：ESC  下一天：N  招募：K"
	settings_controls_label.add_theme_font_size_override("font_size", 11)
	settings_controls_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	settings_panel.add_child(settings_controls_label)


func _make_quick_button(title_text: String, key_text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(58, 60)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.95, 0.89, 0.78, 0.92)
	button_style.border_color = Color(0.58, 0.41, 0.21, 0.95)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_style)
	button.add_theme_stylebox_override("pressed", button_style)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.position = Vector2(0, 10)
	title_label.size = Vector2(58, 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	button.add_child(title_label)

	var key_label: Label = Label.new()
	key_label.text = key_text
	key_label.position = Vector2(0, 38)
	key_label.size = Vector2(58, 18)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	button.add_child(key_label)
	return button


func _make_settings_button(button_text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(184, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	button.add_theme_font_size_override("font_size", 18)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.86, 0.70, 0.42, 0.95)
	button_style.border_color = Color(0.47, 0.29, 0.12, 0.96)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_style)
	button.add_theme_stylebox_override("pressed", button_style)
	return button


func _connect_signals() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	CurrencyManager.wish_stone_changed.connect(_on_wish_stone_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	TimeManager.day_advanced.connect(_on_day_changed)
	TimeManager.day_progress_changed.connect(_on_day_progress_changed)
	TimeManager.time_changed.connect(_on_time_changed)
	_hotbar_manager().selected_slot_changed.connect(_on_hotbar_manager_selected)
	hotbar_ui.selected_item_changed.connect(_on_hotbar_selected)
	hotbar_ui.ui_clicked.connect(_relay_ui_click)
	hotbar_ui.slot_left_pressed.connect(_on_slot_left_pressed)
	hotbar_ui.slot_left_released.connect(_on_slot_left_released)
	hotbar_ui.slot_hovered.connect(_on_slot_hovered)
	hotbar_ui.slot_unhovered.connect(_on_slot_unhovered)
	inventory_panel.sell_requested.connect(_on_sell_requested)
	inventory_panel.sell_option_requested.connect(_on_sell_option_requested)
	inventory_panel.ui_clicked.connect(_relay_ui_click)
	inventory_panel.slot_left_pressed.connect(_on_slot_left_pressed)
	inventory_panel.slot_left_released.connect(_on_slot_left_released)
	inventory_panel.slot_hovered.connect(_on_slot_hovered)
	inventory_panel.slot_unhovered.connect(_on_slot_unhovered)
	chest_panel.slot_left_pressed.connect(_on_slot_left_pressed)
	chest_panel.slot_left_released.connect(_on_slot_left_released)
	chest_panel.slot_hovered.connect(_on_slot_hovered)
	chest_panel.slot_unhovered.connect(_on_slot_unhovered)
	workbench_panel.craft_option_requested.connect(_on_craft_option_requested)
	workbench_panel.ui_clicked.connect(_relay_ui_click)
	shop_panel.buy_option_requested.connect(_on_buy_option_requested)
	shop_panel.ui_clicked.connect(_relay_ui_click)
	trade_dialog.trade_confirmed.connect(_on_trade_confirmed)


func _refresh_all() -> void:
	_on_time_changed(TimeManager.day, TimeManager.get_display_hour(), TimeManager.get_display_minute())
	_on_day_progress_changed(TimeManager.get_day_progress())
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
	_update_day_time_text(day, _last_day_progress)


func _on_day_progress_changed(progress: float) -> void:
	_last_day_progress = progress
	_update_day_time_text(TimeManager.day, progress)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	day_label.text = "第%d日 %02d:%02d" % [day, hour, minute]


func _on_gold_changed(value: int) -> void:
	gold_label.text = "%d" % value


func _on_wish_stone_changed(value: int) -> void:
	wish_stone_label.text = "%d" % value


func _on_inventory_changed(_items: Dictionary) -> void:
	crop_label.text = "小麦 %d  土豆 %d  胡萝卜 %d" % [
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


func _on_sell_option_requested(item_id: String, max_amount: int) -> void:
	var unit_price: int = ItemDatabase.get_sell_price(item_id)
	if unit_price <= 0:
		return
	trade_dialog.open_dialog("sell", item_id, max_amount, unit_price)


func _on_buy_option_requested(item_id: String, max_amount: int) -> void:
	var crop_id: String = ItemDatabase.get_crop_id_from_seed(item_id)
	var unit_price: int = int(CropData.get_crop(crop_id).get("seed_price", 0))
	if unit_price <= 0:
		return
	trade_dialog.open_dialog("buy", item_id, max_amount, unit_price)


func _on_craft_option_requested(recipe_id: String, max_amount: int) -> void:
	var recipe: Dictionary = CraftingData.get_recipe(recipe_id)
	var output_item_id: String = String(recipe.get("output_item_id", recipe_id))
	_pending_craft_recipe_id = recipe_id
	trade_dialog.open_dialog("craft", output_item_id, max_amount, 0)


func _on_trade_confirmed(action_type: String, item_id: String, amount: int) -> void:
	if action_type == "sell":
		sell_requested.emit(item_id, amount)
	elif action_type == "buy":
		buy_requested.emit(item_id, amount)
	elif action_type == "craft":
		var farm_scene = GameManager.farm_scene
		if farm_scene != null and farm_scene.has_method("craft_item_from_workbench"):
			farm_scene.craft_item_from_workbench(_pending_craft_recipe_id, amount)
		_pending_craft_recipe_id = ""


func _relay_ui_click() -> void:
	ui_clicked.emit()


func _on_inventory_button_pressed() -> void:
	if _settings_open:
		close_settings()
	toggle_inventory()
	ui_clicked.emit()


func _on_shop_button_pressed() -> void:
	if _settings_open:
		close_settings()
	toggle_shop()
	ui_clicked.emit()


func _on_settings_button_pressed() -> void:
	toggle_settings()
	ui_clicked.emit()


func _on_save_button_pressed() -> void:
	SaveManager.save_game()
	settings_controls_label.visible = false
	ui_clicked.emit()


func _on_load_button_pressed() -> void:
	SaveManager.load_game()
	settings_controls_label.visible = false
	ui_clicked.emit()


func _on_controls_button_pressed() -> void:
	settings_controls_label.visible = not settings_controls_label.visible
	ui_clicked.emit()


func _on_quit_button_pressed() -> void:
	ui_clicked.emit()
	get_tree().quit()


func _on_slot_left_pressed(slot_type: String, slot_index: int) -> void:
	if not inventory_panel.is_open():
		return
	if _is_shift_pressed():
		if _quick_move_slot(slot_type, slot_index):
			_clear_all_slot_hover()
			ui_clicked.emit()
		_clear_press_state()
		return
	_pressed_slot_type = slot_type
	_pressed_slot_index = slot_index
	_pressed_mouse_position = get_viewport().get_mouse_position()


func _on_slot_left_released(_slot_type: String, _slot_index: int) -> void:
	if not _dragging:
		_clear_press_state()


func _on_slot_hovered(_slot_type: String, _slot_index: int) -> void:
	_show_slot_tooltip(_slot_type, _slot_index)
	if _dragging:
		_update_drag_target_visual()


func _on_slot_unhovered(_slot_type: String, _slot_index: int) -> void:
	_hide_slot_tooltip(_slot_type, _slot_index)
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
		elif _chest_open:
			var chest_index: int = int(chest_panel.get_slot_index_at_global_position(mouse_position))
			if chest_index != -1:
				target_type = "chest"
				target_index = chest_index
	if not target_type.is_empty():
		_swap_slots(_drag_source_type, _drag_source_index, target_type, target_index)
		ui_clicked.emit()
	elif _drop_dragged_slot_to_world():
		ui_clicked.emit()
	_clear_all_slot_hover()
	drag_item_ui.hide_drag()
	_dragging = false
	_drag_source_type = ""
	_drag_source_index = -1


func _cancel_drag() -> void:
	_clear_all_slot_hover()
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
	_clear_all_slot_hover()
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
	if _chest_open:
		var chest_index: int = int(chest_panel.get_slot_index_at_global_position(mouse_position))
		if chest_index != -1:
			chest_panel.set_hover_state(chest_index, true)
			drag_item_ui.set_drop_state(true)
			return
	drag_item_ui.set_drop_state(false)


func _swap_slots(source_type: String, source_index: int, target_type: String, target_index: int) -> void:
	if source_type == target_type and source_index == target_index:
		return
	var source_data: Dictionary = _get_slot_data(source_type, source_index)
	var target_data: Dictionary = _get_slot_data(target_type, target_index)
	if _can_merge_slots(source_data, target_data):
		source_data["amount"] = int(source_data.get("amount", 0)) + int(target_data.get("amount", 0))
		_set_slot_data(source_type, source_index, {"item_id": "", "amount": 0})
		_set_slot_data(target_type, target_index, source_data)
		_pulse_slot(target_type, target_index)
		return
	_set_slot_data(source_type, source_index, target_data)
	_set_slot_data(target_type, target_index, source_data)
	_pulse_slot(target_type, target_index)
	_pulse_slot(source_type, source_index)


func _drop_dragged_slot_to_world() -> bool:
	if _drag_source_type.is_empty() or _drag_source_index < 0:
		return false
	var source_data: Dictionary = _get_slot_data(_drag_source_type, _drag_source_index)
	var item_id: String = String(source_data.get("item_id", ""))
	var amount: int = int(source_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return false
	var farm_scene = GameManager.farm_scene
	if farm_scene == null or not farm_scene.has_method("drop_item_at_player"):
		return false
	_set_slot_data(_drag_source_type, _drag_source_index, {"item_id": "", "amount": 0})
	farm_scene.drop_item_at_player(item_id, amount)
	if item_tooltip != null:
		item_tooltip.visible = false
	return true


func _quick_move_slot(source_type: String, source_index: int) -> bool:
	var source_data: Dictionary = _get_slot_data(source_type, source_index)
	if String(source_data.get("item_id", "")).is_empty() or int(source_data.get("amount", 0)) <= 0:
		return false
	var target_types: Array[String] = _get_quick_move_targets(source_type)
	for target_type in target_types:
		if _move_slot_data_to_target_type(source_type, source_index, source_data, target_type):
			return true
	return false


func _get_quick_move_targets(source_type: String) -> Array[String]:
	if _chest_open:
		match source_type:
			"hotbar", "inventory":
				return ["chest"]
			"chest":
				return ["inventory", "hotbar"]
	elif inventory_panel.is_open():
		match source_type:
			"hotbar":
				return ["inventory"]
			"inventory":
				return ["hotbar"]
	return []


func _move_slot_data_to_target_type(source_type: String, source_index: int, source_data: Dictionary, target_type: String) -> bool:
	var merge_index: int = _find_merge_target_index(target_type, source_data)
	if merge_index != -1:
		var target_data: Dictionary = _get_slot_data(target_type, merge_index)
		target_data["amount"] = int(target_data.get("amount", 0)) + int(source_data.get("amount", 0))
		_set_slot_data(source_type, source_index, {"item_id": "", "amount": 0})
		_set_slot_data(target_type, merge_index, target_data)
		_pulse_slot(target_type, merge_index)
		return true
	var empty_index: int = _find_empty_target_index(target_type)
	if empty_index != -1:
		_set_slot_data(source_type, source_index, {"item_id": "", "amount": 0})
		_set_slot_data(target_type, empty_index, source_data)
		_pulse_slot(target_type, empty_index)
		return true
	return false


func _find_merge_target_index(target_type: String, source_data: Dictionary) -> int:
	var source_item_id: String = String(source_data.get("item_id", ""))
	if source_item_id.is_empty() or not ItemDatabase.is_stackable(source_item_id):
		return -1
	for index in range(_get_slot_count(target_type)):
		var target_data: Dictionary = _get_slot_data(target_type, index)
		if String(target_data.get("item_id", "")) == source_item_id:
			return index
	return -1


func _find_empty_target_index(target_type: String) -> int:
	for index in range(_get_slot_count(target_type)):
		var target_data: Dictionary = _get_slot_data(target_type, index)
		if String(target_data.get("item_id", "")).is_empty() or int(target_data.get("amount", 0)) <= 0:
			return index
	return -1


func _get_slot_count(slot_type: String) -> int:
	match slot_type:
		"hotbar":
			return int(_hotbar_manager().get_slot_count())
		"inventory":
			return int(InventoryManager.get_slot_count())
		"chest":
			if _chest_open:
				return chest_panel.get_slots().size()
	return 0


func _can_merge_slots(source_data: Dictionary, target_data: Dictionary) -> bool:
	var source_item_id: String = String(source_data.get("item_id", ""))
	var target_item_id: String = String(target_data.get("item_id", ""))
	return not source_item_id.is_empty() and source_item_id == target_item_id and ItemDatabase.is_stackable(source_item_id)


func _get_slot_data(slot_type: String, slot_index: int) -> Dictionary:
	match slot_type:
		"hotbar":
			return _hotbar_manager().get_slot(slot_index)
		"inventory":
			return InventoryManager.get_slot(slot_index)
		"chest":
			return chest_panel.get_slot(slot_index)
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
		"chest":
			chest_panel.set_slot(slot_index, slot_data)
			_active_chest_data["slots"] = chest_panel.get_slots()


func _pulse_slot(slot_type: String, slot_index: int) -> void:
	match slot_type:
		"hotbar":
			if slot_index == int(_hotbar_manager().selected_index):
				hotbar_ui.pulse_selected()
			else:
				hotbar_ui.pulse_slot(slot_index)
		"inventory":
			inventory_panel.pulse_slot(slot_index)
		"chest":
			chest_panel.pulse_slot(slot_index)


func _clear_all_slot_hover() -> void:
	hotbar_ui.clear_all_hover()
	inventory_panel.clear_all_hover()
	chest_panel.clear_all_hover()


func _hotbar_manager() -> Node:
	return get_node("/root/HotbarManager")


func _is_shift_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _show_slot_tooltip(slot_type: String, slot_index: int) -> void:
	if slot_type == "inventory":
		return
	var slot_data: Dictionary = _get_slot_data(slot_type, slot_index)
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		item_tooltip.visible = false
		return
	item_tooltip.text = "%s x%d" % [ItemDatabase.get_display_name(item_id), amount]
	item_tooltip.position = get_viewport().get_mouse_position() + Vector2(18, 18)
	item_tooltip.visible = true


func _hide_slot_tooltip(slot_type: String, _slot_index: int) -> void:
	if slot_type != "inventory" and item_tooltip != null:
		item_tooltip.visible = false


func _update_day_time_text(day: int, progress: float) -> void:
	var _unused_progress: float = progress
	day_label.text = "第%d日 %02d:%02d" % [day, TimeManager.get_display_hour(), TimeManager.get_display_minute()]
