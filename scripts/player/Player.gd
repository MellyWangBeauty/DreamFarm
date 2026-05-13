extends CharacterBody2D

const WALK_TEXTURE := preload("res://assets/placeholder/player/player_walksheet.png")
const INTERACTION_BODY_RADIUS := 12.0


@export var move_speed: float = 180.0

var facing_direction: Vector2 = Vector2.DOWN
var _sprite: AnimatedSprite2D
var _last_animation: String = "walk_down"
var _swing_time: float = 0.0
var _swing_duration: float = 0.12
var _swing_strength: float = 0.0


func _ready() -> void:
	_setup_sprite()
	z_index = 20


func _physics_process(delta: float) -> void:
	var input_vector := _get_input_vector()
	if input_vector != Vector2.ZERO:
		facing_direction = input_vector.normalized()
	velocity = input_vector * move_speed
	move_and_slide()
	_update_swing(delta)
	_update_animation()


func is_interact_action_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("interact_action") or _is_key_pressed(event, KEY_E)


func is_tool_action_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("tool_action") or _is_key_pressed(event, KEY_SPACE)


func get_facing_tile_position(tile_size: float) -> Vector2i:
	var facing_step := Vector2.ZERO
	if absf(facing_direction.x) > absf(facing_direction.y):
		facing_step = Vector2(signf(facing_direction.x), 0.0)
	else:
		facing_step = Vector2(0.0, signf(facing_direction.y))
	var base_tile_position := _get_body_stable_tile_position(tile_size, facing_step)
	return base_tile_position + Vector2i(int(facing_step.x), int(facing_step.y))


func _get_body_stable_tile_position(tile_size: float, facing_step: Vector2) -> Vector2i:
	var sample_position := global_position
	if facing_step.x > 0.0:
		sample_position.x -= INTERACTION_BODY_RADIUS
	elif facing_step.x < 0.0:
		sample_position.x += INTERACTION_BODY_RADIUS
	if facing_step.y > 0.0:
		sample_position.y -= INTERACTION_BODY_RADIUS
	elif facing_step.y < 0.0:
		sample_position.y += INTERACTION_BODY_RADIUS
	return Vector2i(floori(sample_position.x / tile_size), floori(sample_position.y / tile_size))


func _get_input_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y).normalized()


func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


func _setup_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0, -14)
	_sprite.sprite_frames = _build_frames()
	var texture_size: Vector2i = WALK_TEXTURE.get_size()
	var frame_size := Vector2i(texture_size.x / 3, texture_size.y / 4)
	var target_height := 54.0
	var scale_factor := target_height / float(frame_size.y)
	_sprite.scale = Vector2.ONE * scale_factor
	add_child(_sprite)
	_update_animation()


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


func _update_animation() -> void:
	var animation_name := "walk_down"
	if absf(facing_direction.x) > absf(facing_direction.y):
		animation_name = "walk_right" if facing_direction.x > 0.0 else "walk_left"
	else:
		animation_name = "walk_down" if facing_direction.y > 0.0 else "walk_up"
	_last_animation = animation_name
	if velocity.length() > 0.01:
		_sprite.play(animation_name)
	else:
		_sprite.play(animation_name)
		_sprite.frame = 1
		_sprite.stop()


func play_tool_swing(tool_id: String) -> void:
	_swing_duration = 0.14
	_swing_strength = 0.20 if tool_id == "scythe" else 0.14
	if tool_id == "watering_can":
		_swing_strength = 0.10
	_swing_time = _swing_duration


func _update_swing(delta: float) -> void:
	if _swing_time <= 0.0:
		_sprite.rotation = 0.0
		_sprite.position = Vector2(0, -14)
		return
	_swing_time = maxf(_swing_time - delta, 0.0)
	var progress := 1.0 - (_swing_time / _swing_duration)
	var wave := sin(progress * PI)
	var horizontal := signf(facing_direction.x)
	if horizontal == 0.0:
		horizontal = 1.0 if facing_direction.y >= 0.0 else -1.0
	_sprite.rotation = wave * _swing_strength * horizontal
	_sprite.position = Vector2(horizontal * wave * 4.0, -14 + wave * 2.0)
