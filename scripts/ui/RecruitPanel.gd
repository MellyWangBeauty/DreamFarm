extends Control

signal recruit_requested(character_id: String)
signal ui_clicked

const WISH_STONE_TEXTURE := preload("res://assets/placeholder/ui/icon_wish_stone.png")
const PANEL_SIZE := Vector2(560, 380)
const CARD_SIZE := Vector2(260, 230)

var _background: Panel
var _wish_count_label: Label
var _card_root: Control
var _message_label: Label
var _confirm_panel: Panel
var _confirm_label: Label
var _pending_character_id: String = ""


func _ready() -> void:
	_build_panel()
	set_open(false)


func set_open(opened: bool) -> void:
	visible = opened
	if opened:
		refresh()


func is_open() -> bool:
	return visible


func refresh() -> void:
	if _wish_count_label != null:
		_wish_count_label.text = "%d" % CurrencyManager.wish_stone
	_message_label.text = ""
	_clear_cards()
	var available := RecruitmentManager.list_available_characters()
	if available.is_empty():
		_message_label.text = "暂无可招募角色"
		return
	var index := 0
	for character_variant in available:
		var character_data: Dictionary = character_variant
		_add_character_card(character_data, index)
		index += 1


func get_panel_global_rect() -> Rect2:
	return Rect2(_background.global_position, _background.size)


func _build_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = Panel.new()
	_background.name = "Background"
	_background.size = PANEL_SIZE
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.89, 0.77, 0.97)
	style.border_color = Color(0.58, 0.41, 0.21, 0.96)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	_background.add_theme_stylebox_override("panel", style)
	add_child(_background)

	var title_label := _make_label("招募", Vector2(28, 22), 28)
	_background.add_child(title_label)

	var wish_icon := TextureRect.new()
	wish_icon.texture = WISH_STONE_TEXTURE
	wish_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wish_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wish_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wish_icon.position = Vector2(PANEL_SIZE.x - 128.0, 22.0)
	wish_icon.size = Vector2(32.0, 32.0)
	_background.add_child(wish_icon)

	_wish_count_label = _make_label("0", Vector2(PANEL_SIZE.x - 90.0, 24.0), 22)
	_wish_count_label.size = Vector2(64.0, 28.0)
	_wish_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_background.add_child(_wish_count_label)

	_card_root = Control.new()
	_card_root.position = Vector2(0, 76)
	_card_root.size = Vector2(PANEL_SIZE.x, CARD_SIZE.y)
	_background.add_child(_card_root)

	_message_label = _make_label("", Vector2(28, PANEL_SIZE.y - 44.0), 17)
	_message_label.size = Vector2(PANEL_SIZE.x - 56.0, 28.0)
	_background.add_child(_message_label)

	_build_confirm_panel()


func _build_confirm_panel() -> void:
	_confirm_panel = Panel.new()
	_confirm_panel.visible = false
	_confirm_panel.position = Vector2((PANEL_SIZE.x - 340.0) * 0.5, 104.0)
	_confirm_panel.size = Vector2(340.0, 160.0)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.84, 0.68, 0.98)
	style.border_color = Color(0.47, 0.29, 0.12, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	_confirm_panel.add_theme_stylebox_override("panel", style)
	_background.add_child(_confirm_panel)

	_confirm_label = _make_label("", Vector2(20, 24), 18)
	_confirm_label.size = Vector2(300, 48)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_panel.add_child(_confirm_label)

	var confirm_button := _make_button("确认", Vector2(36, 98), Vector2(116, 42))
	confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_panel.add_child(confirm_button)

	var cancel_button := _make_button("取消", Vector2(188, 98), Vector2(116, 42))
	cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_panel.add_child(cancel_button)


func _add_character_card(character_data: Dictionary, index: int) -> void:
	var card := Panel.new()
	card.name = "RecruitCard_%s" % String(character_data.get("id", ""))
	card.size = CARD_SIZE
	card.position = Vector2((PANEL_SIZE.x - CARD_SIZE.x) * 0.5 + index * (CARD_SIZE.x + 18.0), 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.93, 0.80, 0.96)
	style.border_color = Color(0.61, 0.43, 0.22, 0.94)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)
	_card_root.add_child(card)

	var portrait := TextureRect.new()
	portrait.texture = _load_texture(String(character_data.get("portrait_path", "")))
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(76, 20)
	portrait.size = Vector2(108, 108)
	card.add_child(portrait)

	var name_label := _make_label(String(character_data.get("name", character_data.get("id", ""))), Vector2(0, 134), 22)
	name_label.size = Vector2(CARD_SIZE.x, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var cost := int(character_data.get("hire_cost_wish_stone", 100))
	var recruit_button := _make_button("花费 %d 许愿石招募" % cost, Vector2(28, 174), Vector2(204, 42))
	recruit_button.pressed.connect(_on_recruit_pressed.bind(String(character_data.get("id", "")), cost))
	card.add_child(recruit_button)


func _clear_cards() -> void:
	for child in _card_root.get_children():
		child.queue_free()


func _on_recruit_pressed(character_id: String, cost: int) -> void:
	ui_clicked.emit()
	if CurrencyManager.wish_stone < cost:
		_message_label.text = "许愿石不足"
		return
	_pending_character_id = character_id
	_confirm_label.text = "是否花费 %d 许愿石招募该角色？" % cost
	_confirm_panel.visible = true


func _on_confirm_pressed() -> void:
	ui_clicked.emit()
	if _pending_character_id.is_empty():
		return
	recruit_requested.emit(_pending_character_id)
	_pending_character_id = ""
	_confirm_panel.visible = false


func _on_cancel_pressed() -> void:
	ui_clicked.emit()
	_pending_character_id = ""
	_confirm_panel.visible = false


func _make_label(text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.84, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = size
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.70, 0.42, 0.95)
	style.border_color = Color(0.47, 0.29, 0.12, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	return button


func _load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	if FileAccess.file_exists("%s.import" % resource_path):
		var texture: Texture2D = load(resource_path)
		if texture != null:
			return texture
	if not resource_path.begins_with("res://"):
		return null
	var file_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(file_path):
		return null
	var image := Image.new()
	if image.load(file_path) != OK:
		return null
	return ImageTexture.create_from_image(image)
