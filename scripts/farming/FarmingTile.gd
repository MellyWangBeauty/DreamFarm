extends Node2D

const TILE_TEXTURES := {
	"empty": preload("res://assets/placeholder/tiles/tile_empty.png"),
	"tilled": preload("res://assets/placeholder/tiles/tile_tilled.png"),
	"planted": preload("res://assets/placeholder/tiles/tile_tilled.png"),
	"grown": preload("res://assets/placeholder/tiles/tile_ready.png")
}
const WATERED_TILE_TEXTURE := preload("res://assets/placeholder/tiles/tile_watered.png")
const CROP_STAGE_TEXTURES := {
	"wheat": [
		preload("res://assets/placeholder/crops/wheat_stage_0.png"),
		preload("res://assets/placeholder/crops/wheat_stage_1.png"),
		preload("res://assets/placeholder/crops/wheat_stage_2.png"),
		preload("res://assets/placeholder/crops/wheat_stage_3.png")
	],
	"potato": [
		preload("res://assets/placeholder/crops/potato_stage_0.png"),
		preload("res://assets/placeholder/crops/potato_stage_1.png"),
		preload("res://assets/placeholder/crops/potato_stage_2.png"),
		preload("res://assets/placeholder/crops/potato_stage_3.png")
	],
	"carrot": [
		preload("res://assets/placeholder/crops/carrot_stage_0.png"),
		preload("res://assets/placeholder/crops/carrot_stage_1.png"),
		preload("res://assets/placeholder/crops/carrot_stage_2.png"),
		preload("res://assets/placeholder/crops/carrot_stage_3.png")
	]
}

enum TileState {
	EMPTY,
	TILLED,
	PLANTED,
	GROWN
}


const TILE_SIZE := 48.0
const PRE_GROWN_STAGE_COUNT: int = 3

var state: String = "empty"
var crop_id: String = ""
var growth_day: int = 0
var growth_minutes: int = 0
var watered_today: bool = false
var grid_position: Vector2i = Vector2i.ZERO
var _ground_sprite: Sprite2D
var _crop_sprite: Sprite2D


func _ready() -> void:
	TimeManager.register_tile(self)
	_setup_visuals()
	_update_visuals()
	z_index = 5


func _exit_tree() -> void:
	TimeManager.unregister_tile(self)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(TILE_SIZE, TILE_SIZE)), Color(0, 0, 0, 0), false)


func till() -> bool:
	if state != "empty":
		return false
	state = "tilled"
	_update_visuals()
	return true


func plant(new_crop_id: String) -> bool:
	if state != "tilled":
		return false
	if not CropData.crop_exists(new_crop_id):
		push_warning("FarmingTile.plant: crop '%s' does not exist." % new_crop_id)
		return false
	state = "planted"
	crop_id = new_crop_id
	growth_day = 0
	growth_minutes = 0
	watered_today = false
	_update_visuals()
	return true


func water() -> bool:
	if state != "planted" and state != "grown":
		return false
	if watered_today:
		return false
	watered_today = true
	_update_visuals()
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("spawn_water_feedback"):
		GameManager.farm_scene.spawn_water_feedback(get_feedback_position())
	return true


func reset_daily_state() -> void:
	watered_today = false
	_update_visuals()


func advance_day() -> void:
	# Kept for compatibility with older callers.
	_update_visuals()


func advance_time(minutes_passed: int) -> void:
	if state != "planted":
		return
	if not watered_today:
		return
	var stage_minutes: int = _get_stage_minutes()
	if stage_minutes <= 0:
		return
	growth_minutes += max(minutes_passed, 0)
	growth_day = int(growth_minutes / stage_minutes)
	if growth_minutes >= stage_minutes * PRE_GROWN_STAGE_COUNT:
		state = "grown"
	_update_visuals()


func harvest() -> Dictionary:
	if state != "grown":
		return {}
	var result: Dictionary = {
		"item_id": crop_id,
		"amount": 1
	}
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("spawn_harvest_feedback"):
		GameManager.farm_scene.spawn_harvest_feedback(get_feedback_position())
	clear_tile()
	return result


func can_harvest() -> bool:
	return state == "grown"


func clear_tile() -> void:
	state = "empty"
	crop_id = ""
	growth_day = 0
	growth_minutes = 0
	watered_today = false
	_update_visuals()


func get_save_data() -> Dictionary:
	return {
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"state": state,
		"crop_id": crop_id,
		"growth_day": growth_day,
		"growth_minutes": growth_minutes,
		"watered_today": watered_today
	}


func load_save_data(data: Dictionary) -> void:
	state = String(data.get("state", "empty"))
	crop_id = String(data.get("crop_id", ""))
	growth_day = int(data.get("growth_day", 0))
	growth_minutes = int(data.get("growth_minutes", 0))
	if growth_minutes <= 0 and not crop_id.is_empty() and growth_day > 0:
		growth_minutes = growth_day * _get_stage_minutes()
	watered_today = bool(data.get("watered_today", false))
	if state == "planted" and growth_minutes >= _get_stage_minutes() * PRE_GROWN_STAGE_COUNT:
		state = "grown"
	_update_visuals()


func get_feedback_position() -> Vector2:
	return global_position + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.35)


func _setup_visuals() -> void:
	_ground_sprite = Sprite2D.new()
	_ground_sprite.centered = true
	_ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_sprite.position = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	add_child(_ground_sprite)

	_crop_sprite = Sprite2D.new()
	_crop_sprite.centered = true
	_crop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crop_sprite.position = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.45)
	add_child(_crop_sprite)


func _update_visuals() -> void:
	var tile_texture: Texture2D = TILE_TEXTURES.get(state, TILE_TEXTURES["empty"])
	if watered_today and state in ["planted", "grown"]:
		tile_texture = WATERED_TILE_TEXTURE if state != "grown" else TILE_TEXTURES["grown"]
	_apply_sprite_texture(_ground_sprite, tile_texture, TILE_SIZE)
	var crop_texture: Texture2D = _get_crop_texture()
	_crop_sprite.visible = crop_texture != null
	if crop_texture != null:
		_apply_sprite_texture(_crop_sprite, crop_texture, 34.0)


func _get_crop_texture() -> Texture2D:
	if crop_id.is_empty():
		return null
	var textures: Array = CROP_STAGE_TEXTURES.get(crop_id, [])
	if textures.is_empty():
		return null
	if state == "grown":
		return textures[3]
	var stage_minutes: int = _get_stage_minutes()
	var stage_index: int = mini(int(floor(float(growth_minutes) / float(maxi(stage_minutes, 1)))), 2)
	return textures[stage_index]


func _apply_sprite_texture(sprite: Sprite2D, texture: Texture2D, target_size: float) -> void:
	sprite.texture = texture
	var texture_size: Vector2i = texture.get_size()
	var max_dimension: float = maxf(texture_size.x, texture_size.y)
	var scale_factor: float = target_size / max_dimension
	sprite.scale = Vector2.ONE * scale_factor


func _get_stage_minutes() -> int:
	var crop_data: Dictionary = CropData.get_crop(crop_id)
	return maxi(int(crop_data.get("stage_minutes", 10)), 1)
