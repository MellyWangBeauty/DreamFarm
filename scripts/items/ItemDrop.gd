extends Node2D


var item_id: String = ""
var amount: int = 1
var display_name: String = ""
var _bob_time: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var quantity_label: Label = $QuantityLabel


func _ready() -> void:
	z_index = 15


func setup(new_item_id: String, new_amount: int) -> void:
	item_id = new_item_id
	amount = max(new_amount, 1)
	display_name = ItemDatabase.get_display_name(item_id)
	if sprite != null:
		sprite.texture = ItemDatabase.get_icon(item_id)
		_apply_icon_scale()
	if quantity_label != null:
		quantity_label.text = "x%d" % amount if amount > 1 else ""


func launch(initial_velocity: Vector2) -> void:
	_velocity = initial_velocity


func set_spawn_world_position(world_position: Vector2) -> void:
	global_position = world_position
	_spawn_position = global_position


func _process(delta: float) -> void:
	_bob_time += delta
	_velocity = _velocity.lerp(Vector2.ZERO, minf(delta * 3.0, 1.0))
	_spawn_position += _velocity * delta
	position = _spawn_position + Vector2(0, sin(_bob_time * 3.5) * 4.0)
	var farm_scene = GameManager.farm_scene
	if farm_scene == null:
		return
	var player = farm_scene.player
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance < 56.0 and distance > 1.0:
		_spawn_position += to_player.normalized() * 140.0 * delta
	if distance < 20.0:
		_collect()


func _collect() -> void:
	InventoryManager.add_item(item_id, amount)
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("on_item_drop_collected"):
		GameManager.farm_scene.on_item_drop_collected(item_id, amount, global_position)
	queue_free()


func _apply_icon_scale() -> void:
	if sprite.texture == null:
		return
	var texture_size: Vector2i = sprite.texture.get_size()
	var max_dimension: float = maxf(texture_size.x, texture_size.y)
	var scale_factor: float = 34.0 / max_dimension
	sprite.scale = Vector2.ONE * scale_factor
