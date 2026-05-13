extends Control

signal buy_option_requested(item_id: String, max_amount: int)
signal ui_clicked

const SHOP_ITEMS: Array[String] = ["wheat_seed", "potato_seed", "carrot_seed"]
const SLOT_SCRIPT := preload("res://scripts/ui/ItemSlotUI.gd")

var _background: Panel
var _title_label: Label
var _rows: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	CurrencyManager.gold_changed.connect(_refresh_rows)
	_refresh_rows()


func set_open(value: bool) -> void:
	visible = value
	if visible:
		_refresh_rows()
		_update_layout()


func is_open() -> bool:
	return visible


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
	background_style.bg_color = Color(0.95, 0.89, 0.78, 0.96)
	background_style.border_color = Color(0.58, 0.41, 0.21, 0.95)
	background_style.set_border_width_all(3)
	background_style.set_corner_radius_all(12)
	_background.add_theme_stylebox_override("panel", background_style)
	add_child(_background)

	_title_label = Label.new()
	_title_label.text = "商店"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	_background.add_child(_title_label)

	for item_id in SHOP_ITEMS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_background.add_child(row)

		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(68, 68)
		slot.set_script(SLOT_SCRIPT)
		row.add_child(slot)
		slot.setup("shop", _rows.size(), false)
		slot.set_slot_data({"item_id": item_id, "amount": 1})

		var info_box: VBoxContainer = VBoxContainer.new()
		info_box.add_theme_constant_override("separation", 4)
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_box)

		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		info_box.add_child(name_label)

		var price_label: Label = Label.new()
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(0.45, 0.31, 0.14))
		info_box.add_child(price_label)

		var buy_button: Button = Button.new()
		buy_button.text = "购买"
		buy_button.custom_minimum_size = Vector2(72, 36)
		buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_button.pressed.connect(_on_buy_button_pressed.bind(_rows.size()))
		row.add_child(buy_button)

		_rows.append({
			"item_id": item_id,
			"row": row,
			"slot": slot,
			"name_label": name_label,
			"price_label": price_label,
			"buy_button": buy_button
		})


func _update_layout() -> void:
	if _background == null:
		return
	var panel_size := Vector2(420, 320)
	var viewport_size: Vector2 = get_viewport_rect().size
	_background.size = panel_size
	_background.position = Vector2(viewport_size.x - panel_size.x - 24.0, (viewport_size.y - panel_size.y) * 0.5)

	_title_label.position = Vector2(24, 18)
	var row_y := 64.0
	for row_data in _rows:
		var row: HBoxContainer = row_data["row"]
		row.position = Vector2(24, row_y)
		row.size = Vector2(panel_size.x - 48, 72)
		row_y += 82.0


func _refresh_rows(_value: int = 0) -> void:
	for row_data in _rows:
		var item_id: String = row_data["item_id"]
		var name_label: Label = row_data["name_label"]
		var price_label: Label = row_data["price_label"]
		var buy_button: Button = row_data["buy_button"]
		var unit_price: int = _get_buy_price(item_id)
		var max_amount: int = _get_max_buy_amount(item_id)
		name_label.text = ItemDatabase.get_display_name(item_id)
		if max_amount > 0:
			price_label.text = "单价：%d 金币 | 最多可买 %d" % [unit_price, max_amount]
		else:
			price_label.text = "单价：%d 金币 | 金币不足" % unit_price
		buy_button.disabled = max_amount <= 0


func _on_buy_button_pressed(row_index: int) -> void:
	ui_clicked.emit()
	if row_index < 0 or row_index >= _rows.size():
		return
	var item_id: String = _rows[row_index]["item_id"]
	var max_amount: int = _get_max_buy_amount(item_id)
	if max_amount <= 0:
		return
	buy_option_requested.emit(item_id, max_amount)


func _get_buy_price(item_id: String) -> int:
	var crop_id: String = ItemDatabase.get_crop_id_from_seed(item_id)
	if crop_id.is_empty():
		return 0
	return int(CropData.get_crop(crop_id).get("seed_price", 0))


func _get_max_buy_amount(item_id: String) -> int:
	var unit_price: int = _get_buy_price(item_id)
	if unit_price <= 0:
		return 0
	return int(floor(float(CurrencyManager.gold) / float(unit_price)))
