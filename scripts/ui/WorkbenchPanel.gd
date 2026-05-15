extends Control

signal craft_option_requested(recipe_id: String, max_amount: int)
signal ui_clicked

const RECIPE_IDS: Array[String] = ["wood_chest"]
const SLOT_SCRIPT := preload("res://scripts/ui/ItemSlotUI.gd")

var _background: Panel
var _title_label: Label
var _message_label: Label
var _rows: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	InventoryManager.inventory_slots_changed.connect(_refresh_rows)
	get_node("/root/HotbarManager").hotbar_changed.connect(_refresh_rows)
	_refresh_rows()


func set_open(value: bool) -> void:
	visible = value
	if visible:
		_refresh_rows()
		_update_layout()


func is_open() -> bool:
	return visible


func show_message(message: String) -> void:
	_message_label.text = message


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
	_title_label.text = "制造"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.29, 0.18, 0.09))
	_background.add_child(_title_label)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(0.50, 0.25, 0.12))
	_background.add_child(_message_label)

	for recipe_id in RECIPE_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_background.add_child(row)

		var recipe: Dictionary = CraftingData.get_recipe(recipe_id)
		var output_item_id: String = String(recipe.get("output_item_id", recipe_id))

		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(68, 68)
		slot.set_script(SLOT_SCRIPT)
		row.add_child(slot)
		slot.setup("craft", _rows.size(), false)
		slot.set_slot_data({"item_id": output_item_id, "amount": int(recipe.get("output_amount", 1))})

		var info_box := VBoxContainer.new()
		info_box.add_theme_constant_override("separation", 4)
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_box)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		info_box.add_child(name_label)

		var recipe_label := Label.new()
		recipe_label.add_theme_font_size_override("font_size", 15)
		recipe_label.add_theme_color_override("font_color", Color(0.45, 0.31, 0.14))
		info_box.add_child(recipe_label)

		var craft_button := Button.new()
		craft_button.text = "制造"
		craft_button.custom_minimum_size = Vector2(72, 36)
		craft_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft_button.pressed.connect(_on_craft_button_pressed.bind(_rows.size()))
		row.add_child(craft_button)

		_rows.append({
			"recipe_id": recipe_id,
			"row": row,
			"name_label": name_label,
			"recipe_label": recipe_label,
			"craft_button": craft_button
		})


func _update_layout() -> void:
	if _background == null:
		return
	var panel_size := Vector2(420, 320)
	var viewport_size: Vector2 = get_viewport_rect().size
	_background.size = panel_size
	_background.position = Vector2(viewport_size.x - panel_size.x - 24.0, (viewport_size.y - panel_size.y) * 0.5)

	_title_label.position = Vector2(24, 18)
	_message_label.position = Vector2(24, panel_size.y - 42.0)
	_message_label.size = Vector2(panel_size.x - 48.0, 24.0)
	var row_y := 64.0
	for row_data in _rows:
		var row: HBoxContainer = row_data["row"]
		row.position = Vector2(24, row_y)
		row.size = Vector2(panel_size.x - 48, 72)
		row_y += 82.0


func _refresh_rows() -> void:
	for row_data in _rows:
		var recipe_id: String = row_data["recipe_id"]
		var recipe: Dictionary = CraftingData.get_recipe(recipe_id)
		var output_item_id: String = String(recipe.get("output_item_id", recipe_id))
		var name_label: Label = row_data["name_label"]
		var recipe_label: Label = row_data["recipe_label"]
		var craft_button: Button = row_data["craft_button"]
		var max_amount: int = CraftingData.get_max_craft_amount(recipe_id)
		name_label.text = ItemDatabase.get_display_name(output_item_id)
		recipe_label.text = _format_recipe(recipe, max_amount)
		craft_button.disabled = max_amount <= 0


func _format_recipe(recipe: Dictionary, max_amount: int) -> String:
	var ingredient_lines: Array[String] = []
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id_variant in ingredients.keys():
		var item_id: String = String(item_id_variant)
		ingredient_lines.append("%s x%d" % [ItemDatabase.get_display_name(item_id), int(ingredients[item_id_variant])])
	var status_text: String = "最多可造 %d" % max_amount if max_amount > 0 else "材料不足"
	return "%s | %s" % [", ".join(ingredient_lines), status_text]


func _on_craft_button_pressed(row_index: int) -> void:
	ui_clicked.emit()
	if row_index < 0 or row_index >= _rows.size():
		return
	var recipe_id: String = _rows[row_index]["recipe_id"]
	var max_amount: int = CraftingData.get_max_craft_amount(recipe_id)
	if max_amount <= 0:
		show_message("材料不足")
		return
	craft_option_requested.emit(recipe_id, max_amount)
