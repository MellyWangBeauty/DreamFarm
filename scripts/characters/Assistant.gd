extends Node2D

const WALK_TEXTURE := preload("res://assets/placeholder/characters/aria_walksheet.png")


var character_id: String = ""
var affection: int = 0
var hired: bool = false
var farm_scene: Node = null
var _sprite: AnimatedSprite2D
var _base_position: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0


func _ready() -> void:
	GameManager.register_assistant(self)
	TimeManager.day_started.connect(_on_day_started)
	_setup_sprite()
	z_index = 18


func _process(delta: float) -> void:
	_bob_time += delta
	position = _base_position + Vector2(0, sin(_bob_time * 2.0) * 2.0)


func assign_to_farm(target_farm_scene: Node) -> void:
	farm_scene = target_farm_scene
	_base_position = Vector2(350, 42)
	position = _base_position


func do_daily_work() -> void:
	if not hired or farm_scene == null:
		return
	if character_id == "aria":
		var watered_count := 0
		for tile in farm_scene.get_farm_tiles():
			if watered_count >= 6:
				break
			if tile.state == "planted" and not tile.watered_today:
				tile.water()
				watered_count += 1
		if watered_count > 0:
			_sprite.play("walk_left")
			print("Assistant %s watered %d tile(s)." % [character_id, watered_count])


func _on_day_started(_day: int) -> void:
	do_daily_work()


func _setup_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -10)
	_sprite.sprite_frames = _build_frames()
	var texture_size: Vector2i = WALK_TEXTURE.get_size()
	var frame_size := Vector2i(texture_size.x / 3, texture_size.y / 4)
	var target_height := 50.0
	var scale_factor := target_height / float(frame_size.y)
	_sprite.scale = Vector2.ONE * scale_factor
	add_child(_sprite)
	_sprite.play("walk_down")
	_sprite.frame = 1
	_sprite.stop()


func _build_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var animations: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]
	var texture_size: Vector2i = WALK_TEXTURE.get_size()
	var frame_size := Vector2i(texture_size.x / 3, texture_size.y / 4)
	for row in range(animations.size()):
		var animation_name: String = animations[row]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, 6.0)
		for col in range(3):
			var atlas := AtlasTexture.new()
			atlas.atlas = WALK_TEXTURE
			atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
			sprite_frames.add_frame(animation_name, atlas)
	return sprite_frames
