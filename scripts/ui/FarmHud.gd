extends CanvasLayer


const PANEL_TEXTURE := preload("res://assets/placeholder/ui/hud_panel.png")
const GOLD_TEXTURE := preload("res://assets/placeholder/ui/icon_gold.png")
const WISH_STONE_TEXTURE := preload("res://assets/placeholder/ui/icon_wish_stone.png")

var panel_rect: TextureRect
var day_label: Label
var gold_label: Label
var wish_stone_label: Label
var wheat_label: Label


func _ready() -> void:
	_build_ui()
	_connect_signals()
	_refresh_all()


func _build_ui() -> void:
	panel_rect = TextureRect.new()
	panel_rect.texture = PANEL_TEXTURE
	panel_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_rect.position = Vector2(16, 16)
	panel_rect.size = Vector2(430, 140)
	panel_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(panel_rect)

	day_label = _make_label(Vector2(28, 20), 18)
	gold_label = _make_label(Vector2(88, 62), 18)
	wish_stone_label = _make_label(Vector2(88, 98), 18)
	wheat_label = _make_label(Vector2(250, 62), 16)
	panel_rect.add_child(day_label)
	panel_rect.add_child(gold_label)
	panel_rect.add_child(wish_stone_label)
	panel_rect.add_child(wheat_label)

	var gold_icon := _make_icon(GOLD_TEXTURE, Vector2(28, 58), Vector2(40, 40))
	var wish_icon := _make_icon(WISH_STONE_TEXTURE, Vector2(28, 92), Vector2(40, 40))
	panel_rect.add_child(gold_icon)
	panel_rect.add_child(wish_icon)

	var hint_label := _make_label(Vector2(248, 92), 13)
	hint_label.text = "H/P/W/R  B  N  K  F5/F9"
	panel_rect.add_child(hint_label)


func _connect_signals() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	CurrencyManager.wish_stone_changed.connect(_on_wish_stone_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	TimeManager.day_advanced.connect(_on_day_changed)


func _refresh_all() -> void:
	_on_day_changed(TimeManager.day)
	_on_gold_changed(CurrencyManager.gold)
	_on_wish_stone_changed(CurrencyManager.wish_stone)
	_on_inventory_changed(InventoryManager.get_all_items())


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.86, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_icon(texture: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = pos
	icon.size = size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day


func _on_gold_changed(value: int) -> void:
	gold_label.text = "%d" % value


func _on_wish_stone_changed(value: int) -> void:
	wish_stone_label.text = "%d" % value


func _on_inventory_changed(_items: Dictionary) -> void:
	wheat_label.text = "Wheat %d" % InventoryManager.get_item_count("wheat")
