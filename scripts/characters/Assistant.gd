extends Node2D

const WALK_TEXTURE := preload("res://assets/placeholder/characters/aria_walksheet.png")


var character_id: String = ""
var affection: int = 0
var hired: bool = false
var farm_scene: Node = null
var _sprite: AnimatedSprite2D
var _bob_time: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO
var _wander_time: float = 0.0
var _pause_time: float = 0.0


func _ready() -> void:
	GameManager.register_assistant(self)
	TimeManager.day_started.connect(_on_day_started)
	_setup_sprite()
	z_index = 18


func _process(delta: float) -> void:
	_bob_time += delta
	_update_wander(delta)


func assign_to_farm(target_farm_scene: Node, spawn_position: Vector2 = Vector2.INF) -> void:
	farm_scene = target_farm_scene
	if spawn_position != Vector2.INF:
		global_position = spawn_position
	elif global_position == Vector2.ZERO:
		global_position = Vector2(350, 42)


func set_world_position(world_position: Vector2) -> void:
	global_position = world_position


func get_save_data() -> Dictionary:
	return {
		"character_id": character_id,
		"grid_x": 0,
		"grid_y": 0,
		"x": global_position.x,
		"y": global_position.y
	}


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


func _update_wander(delta: float) -> void:
	if not hired:
		return
	if _pause_time > 0.0:
		_pause_time = maxf(_pause_time - delta, 0.0)
		_set_idle_frame()
		return
	_wander_time -= delta
	if _wander_time <= 0.0:
		if randf() < 0.35:
			_wander_direction = Vector2.ZERO
			_pause_time = randf_range(0.8, 1.6)
		else:
			_wander_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU)).normalized()
			_wander_time = randf_range(0.7, 1.5)
	if _wander_direction == Vector2.ZERO:
		_set_idle_frame()
		return
	global_position += _wander_direction * 28.0 * delta
	_play_walk_animation(_wander_direction)


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


func _play_walk_animation(direction: Vector2) -> void:
	var animation_name := "walk_down"
	if absf(direction.x) > absf(direction.y):
		animation_name = "walk_right" if direction.x > 0.0 else "walk_left"
	else:
		animation_name = "walk_down" if direction.y > 0.0 else "walk_up"
	_sprite.play(animation_name)


func _set_idle_frame() -> void:
	if _sprite == null:
		return
	if not _sprite.is_playing():
		return
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
