extends Node

const ITEMS_DATA_PATH := "res://data/items.json"
const DEFAULT_HOTBAR: Array[String] = [
	"hoe",
	"watering_can",
	"axe",
	"pickaxe",
	"workbench",
	"tree_sapling",
	"wheat_seed",
	"potato_seed",
	"carrot_seed",
	"scythe",
]
const NON_STACKABLE_HANDHELD_TOOLS: Array[String] = [
	"axe",
	"hoe",
	"pickaxe",
	"scythe",
	"watering_can",
]

var _items: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	if not FileAccess.file_exists(ITEMS_DATA_PATH):
		push_error("物品数据库：未找到 items.json。")
		return
	var file: FileAccess = FileAccess.open(ITEMS_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("物品数据库：打开 items.json 失败。")
		return
	var parser: JSON = JSON.new()
	var result: int = parser.parse(file.get_as_text())
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("物品数据库：解析 items.json 失败。")
		return
	_items = parser.data


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate(true)


func item_exists(item_id: String) -> bool:
	return _items.has(item_id)


func get_display_name(item_id: String) -> String:
	return String(get_item(item_id).get("name", item_id))


func get_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]
	var item_data: Dictionary = get_item(item_id)
	var icon_path: String = String(item_data.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var texture: Texture2D = _load_texture(icon_path)
	if texture != null:
		_icon_cache[item_id] = texture
	return texture


func get_ui_scale(item_id: String) -> float:
	if item_id.is_empty():
		return 1.0
	return float(get_item(item_id).get("ui_scale", 1.0))


func get_ui_offset(item_id: String) -> Vector2:
	if item_id.is_empty():
		return Vector2.ZERO
	var item_data: Dictionary = get_item(item_id)
	return Vector2(
		float(item_data.get("ui_offset_x", 0.0)),
		float(item_data.get("ui_offset_y", 0.0))
	)


func get_default_hotbar() -> Array[String]:
	return DEFAULT_HOTBAR.duplicate()


func is_seed(item_id: String) -> bool:
	return String(get_item(item_id).get("category", "")) == "seed"


func is_tool(item_id: String) -> bool:
	return String(get_item(item_id).get("category", "")) == "tool"


func is_stackable(item_id: String) -> bool:
	if not item_exists(item_id):
		return false
	var item_data: Dictionary = get_item(item_id)
	if item_data.has("stackable"):
		return bool(item_data.get("stackable", true))
	return not NON_STACKABLE_HANDHELD_TOOLS.has(item_id)


func is_crop(item_id: String) -> bool:
	return String(get_item(item_id).get("category", "")) == "crop"


func is_container(item_id: String) -> bool:
	return String(get_item(item_id).get("category", "")) == "container"


func is_placeable(item_id: String) -> bool:
	return String(get_item(item_id).get("category", "")) == "placeable"


func get_placeable_type(item_id: String) -> String:
	return String(get_item(item_id).get("placeable_type", ""))


func is_sellable(item_id: String) -> bool:
	return is_crop(item_id)


func get_crop_id_from_seed(item_id: String) -> String:
	return String(get_item(item_id).get("crop_id", ""))


func get_sell_price(item_id: String) -> int:
	if CropData.crop_exists(item_id):
		return int(CropData.get_crop(item_id).get("sell_price", 0))
	var crop_id: String = String(get_item(item_id).get("crop_id", ""))
	if CropData.crop_exists(crop_id):
		return int(CropData.get_crop(crop_id).get("sell_price", 0))
	return 0


func get_container_columns(item_id: String) -> int:
	return maxi(int(get_item(item_id).get("storage_columns", 0)), 1)


func get_container_rows(item_id: String) -> int:
	return maxi(int(get_item(item_id).get("storage_rows", 0)), 1)


func get_container_capacity(item_id: String) -> int:
	if not is_container(item_id):
		return 0
	return get_container_columns(item_id) * get_container_rows(item_id)


func _load_texture(resource_path: String) -> Texture2D:
	if FileAccess.file_exists("%s.import" % resource_path):
		var texture: Texture2D = load(resource_path)
		if texture != null:
			return texture
	if not resource_path.begins_with("res://"):
		return null
	var file_path: String = ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(file_path):
		return null
	var image := Image.new()
	if image.load(file_path) != OK:
		return null
	return ImageTexture.create_from_image(image)
