extends Node2D


const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const TILE_SIZE := 48.0
const HUD_SCRIPT := preload("res://scripts/ui/FarmHud.gd")
const FLOATING_TEXT_SCRIPT := preload("res://scripts/effects/FloatingText.gd")
const BURST_EFFECT_SCRIPT := preload("res://scripts/effects/BurstEffect.gd")
const INTERACT_SFX := preload("res://assets/placeholder/audio/interact.wav")
const WATER_SFX := preload("res://assets/placeholder/audio/water.wav")
const HARVEST_SFX := preload("res://assets/placeholder/audio/harvest.wav")
const COIN_SFX := preload("res://assets/placeholder/audio/coin.wav")

@onready var player: CharacterBody2D = $Player
@onready var tiles_root: Node2D = $Tiles
@onready var assistants_root: Node = $Assistants

var _tiles: Dictionary = {}
var _feedback_root: Node2D
var _hud: CanvasLayer
var _sfx_players: Dictionary = {}


func _ready() -> void:
	GameManager.register_farm_scene(self)
	_ensure_feedback_root()
	_ensure_hud()
	_ensure_audio_players()
	_create_tiles()
	_spawn_existing_assistants()
	queue_redraw()
	print("FarmScene ready. H till, P plant wheat, W water, R harvest, B sell, N next day, K hire aria, F5 save, F9 load.")


func _exit_tree() -> void:
	GameManager.unregister_farm_scene(self)


func _unhandled_input(event: InputEvent) -> void:
	if _is_key_pressed(event, KEY_H):
		_use_tile_action("till")
	elif _is_key_pressed(event, KEY_P):
		_use_tile_action("plant")
	elif _is_key_pressed(event, KEY_R):
		_use_tile_action("harvest")
	elif _is_key_pressed(event, KEY_B):
		_sell_all_crops()
	elif _is_key_pressed(event, KEY_N):
		TimeManager.next_day()
	elif _is_key_pressed(event, KEY_K):
		var hired := RecruitmentManager.hire_character("aria")
		if hired:
			_spawn_world_text("+Aria", Color(0.51, 0.92, 1.0), Vector2(350, 10))
			_play_sfx("interact")
		print("Hire aria result: %s" % hired)
	elif _is_key_pressed(event, KEY_F5):
		SaveManager.save_game()
	elif _is_key_pressed(event, KEY_F9):
		SaveManager.load_game()
	elif _is_water_key(event):
		_use_tile_action("water")


func _draw() -> void:
	draw_rect(Rect2(-256, -180, 1600, 1100), Color(0.63, 0.83, 0.44))
	draw_rect(Rect2(-20, -20, GRID_WIDTH * TILE_SIZE + 40, GRID_HEIGHT * TILE_SIZE + 40), Color(0.76, 0.67, 0.45, 0.85))
	for x in range(GRID_WIDTH + 1):
		var x_pos := x * TILE_SIZE
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, GRID_HEIGHT * TILE_SIZE), Color(0.45, 0.38, 0.20, 0.15), 1.0)
	for y in range(GRID_HEIGHT + 1):
		var y_pos := y * TILE_SIZE
		draw_line(Vector2(0, y_pos), Vector2(GRID_WIDTH * TILE_SIZE, y_pos), Color(0.45, 0.38, 0.20, 0.15), 1.0)


func get_farm_tiles() -> Array:
	var tiles: Array = []
	for tile in _tiles.values():
		tiles.append(tile)
	return tiles


func get_farm_tile_save_data() -> Array:
	var data: Array = []
	for tile in get_farm_tiles():
		data.append(tile.get_save_data())
	return data


func load_farm_tile_save_data(save_data: Array) -> void:
	for tile_data_variant in save_data:
		var tile_data: Dictionary = tile_data_variant
		var position_key: Vector2i = Vector2i(int(tile_data.get("grid_x", 0)), int(tile_data.get("grid_y", 0)))
		if _tiles.has(position_key):
			_tiles[position_key].load_save_data(tile_data)
	_spawn_existing_assistants()


func ensure_assistant_node(character_id: String) -> void:
	for child in assistants_root.get_children():
		if child.character_id == character_id:
			child.hired = true
			child.assign_to_farm(self)
			return
	var assistant_script := load("res://scripts/characters/Assistant.gd")
	var assistant := Node2D.new()
	assistant.set_script(assistant_script)
	assistant.character_id = character_id
	assistant.hired = RecruitmentManager.is_hired(character_id)
	assistants_root.add_child(assistant)
	assistant.assign_to_farm(self)


func _create_tiles() -> void:
	if not _tiles.is_empty():
		return
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var tile_script := load("res://scripts/farming/FarmingTile.gd")
			var tile := Node2D.new()
			tile.set_script(tile_script)
			tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			tile.grid_position = Vector2i(x, y)
			tile.name = "Tile_%d_%d" % [x, y]
			tiles_root.add_child(tile)
			_tiles[Vector2i(x, y)] = tile


func _use_tile_action(action_name: String) -> void:
	var tile: Node = _get_facing_tile()
	if tile == null:
		return
	match action_name:
		"till":
			if tile.till():
				_play_sfx("interact")
		"plant":
			if tile.plant("wheat"):
				_play_sfx("interact")
		"water":
			if tile.water():
				_play_sfx("water")
		"harvest":
			var harvest_result: Dictionary = tile.harvest()
			if not harvest_result.is_empty():
				InventoryManager.add_item(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 0)))
				_spawn_world_text("+%s" % String(harvest_result.get("item_id", "")), Color(1.0, 0.95, 0.72), tile.get_feedback_position() + Vector2(0, -20))
				_play_sfx("harvest")
				print("Harvested %s x%d" % [harvest_result.get("item_id", ""), harvest_result.get("amount", 0)])


func _get_facing_tile() -> Node:
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	return _tiles.get(tile_position, null)


func _sell_all_crops() -> void:
	var inventory := InventoryManager.get_all_items()
	var total_gold := 0
	var sold_lines: Array[String] = []
	for item_id in inventory.keys():
		if not CropData.crop_exists(String(item_id)):
			continue
		var amount := InventoryManager.get_item_count(String(item_id))
		if amount <= 0:
			continue
		var crop_data := CropData.get_crop(String(item_id))
		var sell_price := int(crop_data.get("sell_price", 0))
		var earned := sell_price * amount
		if InventoryManager.remove_item(String(item_id), amount):
			total_gold += earned
			sold_lines.append("%s x%d => %d gold" % [item_id, amount, earned])
	if total_gold > 0:
		CurrencyManager.add_gold(total_gold)
		_spawn_world_text("+%d Gold" % total_gold, Color(1.0, 0.88, 0.35), player.global_position + Vector2(0, -48))
		_play_sfx("coin")
		print("Sold crops:")
		for line in sold_lines:
			print(" - %s" % line)
		print("Total gold earned: %d | Current gold: %d" % [total_gold, CurrencyManager.gold])
	else:
		print("No crops available to sell.")


func _spawn_existing_assistants() -> void:
	for character_id_variant in RecruitmentManager.get_hired_character_ids():
		ensure_assistant_node(String(character_id_variant))


func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


func _is_water_key(event: InputEvent) -> bool:
	return _is_key_pressed(event, KEY_W) and player.velocity == Vector2.ZERO


func spawn_water_feedback(world_position: Vector2) -> void:
	_spawn_burst(world_position, Color(0.49, 0.82, 1.0), 9, 34.0)


func spawn_harvest_feedback(world_position: Vector2) -> void:
	_spawn_burst(world_position, Color(1.0, 0.84, 0.35), 12, 46.0)


func _ensure_feedback_root() -> void:
	_feedback_root = Node2D.new()
	_feedback_root.name = "Feedback"
	add_child(_feedback_root)


func _ensure_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "FarmHud"
	_hud.set_script(HUD_SCRIPT)
	add_child(_hud)


func _ensure_audio_players() -> void:
	_sfx_players["interact"] = _make_sfx_player("InteractSfx", INTERACT_SFX)
	_sfx_players["water"] = _make_sfx_player("WaterSfx", WATER_SFX)
	_sfx_players["harvest"] = _make_sfx_player("HarvestSfx", HARVEST_SFX)
	_sfx_players["coin"] = _make_sfx_player("CoinSfx", COIN_SFX)


func _make_sfx_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.name = player_name
	player_node.stream = stream
	add_child(player_node)
	return player_node


func _play_sfx(sound_name: String) -> void:
	var player_node = _sfx_players.get(sound_name, null)
	if player_node != null:
		player_node.play()


func _spawn_world_text(text: String, color: Color, world_position: Vector2) -> void:
	var text_node := Node2D.new()
	text_node.set_script(FLOATING_TEXT_SCRIPT)
	_feedback_root.add_child(text_node)
	text_node.setup(text, color, world_position)


func _spawn_burst(world_position: Vector2, color: Color, amount: int, speed: float) -> void:
	var burst_node := Node2D.new()
	burst_node.set_script(BURST_EFFECT_SCRIPT)
	_feedback_root.add_child(burst_node)
	burst_node.setup(color, world_position, amount, speed)
