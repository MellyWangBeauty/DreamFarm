extends Node2D

const GRID_WIDTH := 24
const GRID_HEIGHT := 18
const TILE_SIZE := 48.0
const MAP_LAYOUT_PATH := "res://data/map_layout.json"
const WATER_AUTOTILE_TEXTURE_PATH := "res://assets/placeholder/tiles/water_autotile.png"
const HUD_SCRIPT := preload("res://scripts/ui/FarmHud.gd")
const FEEDBACK_SCRIPT := preload("res://scripts/effects/FarmFeedback.gd")
const ITEM_DROP_SCENE := preload("res://scenes/items/ItemDrop.tscn")
const MAP_OBJECT_COLLISION_LAYER := 1
const MAP_OBJECT_COLLISION_MASK := 1
const WATER_TILE_SOURCE_COLUMNS := 4
const WATER_TILE_SOURCE_ROWS := 4

@onready var player = $Player
@onready var tiles_root: Node2D = $Tiles
@onready var assistants_root: Node = $Assistants

var _tiles: Dictionary = {}
var _placed_chests: Dictionary = {}
var _placed_workbenches: Dictionary = {}
var _placed_furnaces: Dictionary = {}
var _placed_ores: Dictionary = {}
var _water_tiles: Dictionary = {}
var _farmable_tiles: Dictionary = {}
var _map_layout: Dictionary = {}
var _water_texture: Texture2D
var _water_root: Node2D
var _chests_root: Node2D
var _workbenches_root: Node2D
var _furnaces_root: Node2D
var _ores_root: Node2D
var _feedback_controller: Node2D
var _interaction_hint_label: Label
var _hud
var _shop_sell_items: Array[String] = ["wheat", "potato", "carrot"]
var _shop_buy_items: Array[String] = ["wheat_seed", "potato_seed", "carrot_seed", "tree_sapling"]


func _ready() -> void:
	GameManager.register_farm_scene(self)
	_load_map_layout()
	_ensure_water_root()
	_ensure_feedback_controller()
	_ensure_chests_root()
	_ensure_workbenches_root()
	_ensure_furnaces_root()
	_ensure_ores_root()
	_ensure_interaction_hint()
	_ensure_hud()
	_create_water_tiles()
	_create_tiles()
	_spawn_default_trees()
	_spawn_default_ores()
	_spawn_existing_assistants()
	queue_redraw()
	print("农场场景已就绪。1-0 切换快捷栏，鼠标左键/空格使用工具，G 丢弃当前热栏物品，E 打开箱子，B 打开背包，P 打开商店，ESC 设置，N 下一天，K 招募 Aria。")


func _exit_tree() -> void:
	GameManager.unregister_farm_scene(self)


func _unhandled_input(event: InputEvent) -> void:
	if _hud != null and _hud.has_method("handle_global_input") and _hud.handle_global_input(event):
		return
	if _is_key_pressed(event, KEY_E):
		if not _hud.is_inventory_open():
			if not _open_facing_workbench() and not _open_facing_furnace():
				_open_facing_chest()
	elif _is_key_pressed(event, KEY_G):
		if not _hud.is_inventory_open():
			_drop_selected_hotbar_item()
	elif _is_left_click(event) or _is_key_pressed(event, KEY_SPACE):
		if not _hud.is_inventory_open():
			_use_selected_tool()
	elif _is_key_pressed(event, KEY_N):
		TimeManager.next_day()


func _draw() -> void:
	var map_width := GRID_WIDTH * TILE_SIZE
	var map_height := GRID_HEIGHT * TILE_SIZE
	draw_rect(Rect2(-TILE_SIZE, -TILE_SIZE, map_width + TILE_SIZE * 2.0, map_height + TILE_SIZE * 2.0), Color(0.50, 0.72, 0.32))
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_width, map_height)), Color(0.63, 0.83, 0.44))
	draw_rect(Rect2(Vector2(TILE_SIZE * 1.4, TILE_SIZE * 1.25), Vector2(TILE_SIZE * 8.4, TILE_SIZE * 8.2)), Color(0.70, 0.78, 0.38, 0.70))
	draw_rect(Rect2(Vector2(TILE_SIZE * 16.0, TILE_SIZE * 1.1), Vector2(TILE_SIZE * 7.0, TILE_SIZE * 8.2)), Color(0.55, 0.57, 0.38, 0.55))
	draw_rect(Rect2(Vector2(TILE_SIZE * 0.4, TILE_SIZE * 9.0), Vector2(TILE_SIZE * 8.8, TILE_SIZE * 8.4)), Color(0.39, 0.66, 0.31, 0.45))
	draw_rect(Rect2(Vector2(TILE_SIZE * 9.5, TILE_SIZE * 11.5), Vector2(TILE_SIZE * 5.8, TILE_SIZE * 5.6)), Color(0.72, 0.82, 0.44, 0.40))
	_draw_water_tiles()


func _process(_delta: float) -> void:
	_update_interaction_hint()


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


func get_chest_save_data() -> Array:
	if _hud != null and _hud.has_method("flush_open_chest"):
		_hud.flush_open_chest()
	var data: Array = []
	for grid_position in _placed_chests.keys():
		var chest_data: Dictionary = _placed_chests[grid_position]
		data.append({
			"grid_x": grid_position.x,
			"grid_y": grid_position.y,
			"item_id": String(chest_data.get("item_id", "")),
			"slots": chest_data.get("slots", [])
		})
	return data


func get_workbench_save_data() -> Array:
	var data: Array = []
	for grid_position in _placed_workbenches.keys():
		data.append({
			"grid_x": grid_position.x,
			"grid_y": grid_position.y,
			"item_id": String(_placed_workbenches[grid_position].get("item_id", "workbench"))
		})
	return data


func get_furnace_save_data() -> Array:
	var data: Array = []
	for grid_position in _placed_furnaces.keys():
		data.append({
			"grid_x": grid_position.x,
			"grid_y": grid_position.y,
			"item_id": String(_placed_furnaces[grid_position].get("item_id", "furnace"))
		})
	return data


func get_ore_save_data() -> Array:
	var data: Array = []
	for grid_position in _placed_ores.keys():
		data.append({
			"grid_x": grid_position.x,
			"grid_y": grid_position.y,
			"node_id": String(_placed_ores[grid_position].get("node_id", ""))
		})
	return data


func get_assistant_save_data() -> Array:
	var data: Array = []
	for child in assistants_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not bool(child.get("hired")):
			continue
		if child.has_method("get_save_data"):
			data.append(child.get_save_data())
	return data


func has_placed_workbench() -> bool:
	return not _placed_workbenches.is_empty()


func load_farm_tile_save_data(save_data: Array) -> void:
	for tile_data_variant in save_data:
		var tile_data: Dictionary = tile_data_variant
		var position_key: Vector2i = Vector2i(int(tile_data.get("grid_x", 0)), int(tile_data.get("grid_y", 0)))
		if not _tiles.has(position_key) and _is_within_map(position_key) and not _is_water_tile(position_key):
			_create_farming_tile(position_key, true, true)
		if _tiles.has(position_key):
			_tiles[position_key].load_save_data(tile_data)
	_clear_ores_on_occupied_tiles()
	_spawn_existing_assistants()


func load_chest_save_data(save_data: Array) -> void:
	_clear_placed_chests()
	for chest_data_variant in save_data:
		var chest_data: Dictionary = chest_data_variant
		var grid_position := Vector2i(int(chest_data.get("grid_x", 0)), int(chest_data.get("grid_y", 0)))
		var item_id := String(chest_data.get("item_id", ""))
		if not ItemDatabase.is_container(item_id):
			continue
		_clear_ore_at(grid_position)
		_place_chest_at(grid_position, item_id, chest_data.get("slots", []), false)


func load_workbench_save_data(save_data: Array) -> void:
	_clear_placed_workbenches()
	for workbench_data_variant in save_data:
		var workbench_data: Dictionary = workbench_data_variant
		var grid_position := Vector2i(int(workbench_data.get("grid_x", 0)), int(workbench_data.get("grid_y", 0)))
		_clear_ore_at(grid_position)
		_place_workbench_at(grid_position, String(workbench_data.get("item_id", "workbench")), false)


func load_furnace_save_data(save_data: Array) -> void:
	_clear_placed_furnaces()
	for furnace_data_variant in save_data:
		var furnace_data: Dictionary = furnace_data_variant
		var grid_position := Vector2i(int(furnace_data.get("grid_x", 0)), int(furnace_data.get("grid_y", 0)))
		_clear_ore_at(grid_position)
		_place_furnace_at(grid_position, String(furnace_data.get("item_id", "furnace")), false)


func load_ore_save_data(save_data: Array) -> void:
	_clear_placed_ores()
	for ore_data_variant in save_data:
		var ore_data: Dictionary = ore_data_variant
		var grid_position := Vector2i(int(ore_data.get("grid_x", 0)), int(ore_data.get("grid_y", 0)))
		_place_ore_at(grid_position, String(ore_data.get("node_id", "")), false)


func load_assistant_save_data(save_data: Array) -> void:
	for assistant_data_variant in save_data:
		var assistant_data: Dictionary = assistant_data_variant
		var character_id := String(assistant_data.get("character_id", ""))
		if character_id.is_empty():
			continue
		var spawn_position := Vector2(float(assistant_data.get("x", 350.0)), float(assistant_data.get("y", 42.0)))
		ensure_assistant_node(character_id, spawn_position)


func ensure_default_ore_node(node_id: String) -> void:
	for ore_data in MiningData.get_default_nodes():
		if String(ore_data.get("node_id", "")) != node_id:
			continue
		var grid_position := Vector2i(int(ore_data.get("grid_x", 0)), int(ore_data.get("grid_y", 0)))
		if _placed_ores.has(grid_position):
			return
		_place_ore_at(grid_position, node_id, true)
		return


func ensure_default_ore_positions_from_index(node_id: String, first_position_index: int) -> void:
	var current_index: int = 0
	for ore_data in MiningData.get_default_nodes():
		if String(ore_data.get("node_id", "")) != node_id:
			continue
		if current_index >= first_position_index:
			var grid_position := Vector2i(int(ore_data.get("grid_x", 0)), int(ore_data.get("grid_y", 0)))
			if not _placed_ores.has(grid_position):
				_place_ore_at(grid_position, node_id, true)
		current_index += 1


func ensure_all_default_ore_positions() -> void:
	for ore_data in MiningData.get_default_nodes():
		var node_id := String(ore_data.get("node_id", ""))
		var grid_position := Vector2i(int(ore_data.get("grid_x", 0)), int(ore_data.get("grid_y", 0)))
		if not _placed_ores.has(grid_position):
			_place_ore_at(grid_position, node_id, true)


func ensure_assistant_node(character_id: String, spawn_position: Vector2 = Vector2.INF) -> void:
	for child in assistants_root.get_children():
		if child.character_id == character_id:
			child.hired = true
			child.assign_to_farm(self, spawn_position)
			return
	var assistant_script = load("res://scripts/characters/Assistant.gd")
	var assistant = Node2D.new()
	assistant.set_script(assistant_script)
	assistant.character_id = character_id
	assistant.hired = RecruitmentManager.is_hired(character_id)
	assistants_root.add_child(assistant)
	assistant.assign_to_farm(self, spawn_position)


func _load_map_layout() -> void:
	_map_layout.clear()
	_water_tiles.clear()
	_farmable_tiles.clear()
	if not FileAccess.file_exists(MAP_LAYOUT_PATH):
		push_warning("FarmScene: map layout file is missing: %s" % MAP_LAYOUT_PATH)
		return
	var file := FileAccess.open(MAP_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_warning("FarmScene: failed to open map layout file: %s" % MAP_LAYOUT_PATH)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_warning("FarmScene: failed to parse map layout file: %s" % MAP_LAYOUT_PATH)
		return
	_map_layout = parser.data
	for water_position in _map_layout.get("water_tiles", []):
		var tile_position := _position_from_data(water_position)
		if _is_within_map(tile_position):
			_water_tiles[tile_position] = true
	for farm_position in _map_layout.get("farmable_tiles", []):
		var tile_position := _position_from_data(farm_position)
		if _is_within_map(tile_position) and not _is_water_tile(tile_position):
			_farmable_tiles[tile_position] = true
	_water_texture = _load_texture(WATER_AUTOTILE_TEXTURE_PATH)


func _create_tiles() -> void:
	if not _tiles.is_empty():
		return
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var tile_position := Vector2i(x, y)
			if _is_water_tile(tile_position):
				continue
			_create_farming_tile(tile_position, _farmable_tiles.has(tile_position), true)


func _create_farming_tile(tile_position: Vector2i, is_farmable: bool, show_ground: bool):
	if _tiles.has(tile_position):
		return _tiles[tile_position]
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return null
	var tile_script = load("res://scripts/farming/FarmingTile.gd")
	var tile = Node2D.new()
	tile.set_script(tile_script)
	tile.position = Vector2(tile_position.x * TILE_SIZE, tile_position.y * TILE_SIZE)
	tile.grid_position = tile_position
	tile.farmable = is_farmable
	tile.show_ground_tile = show_ground
	tile.name = "Tile_%d_%d" % [tile_position.x, tile_position.y]
	tiles_root.add_child(tile)
	_tiles[tile_position] = tile
	return tile


func _create_water_tiles() -> void:
	if _water_root == null:
		return
	for child in _water_root.get_children():
		child.queue_free()
	for tile_position in _water_tiles.keys():
		_spawn_static_collision(
			_water_root,
			"WaterCollision_%d_%d" % [tile_position.x, tile_position.y],
			Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5),
			Vector2(TILE_SIZE, TILE_SIZE)
		)


func _spawn_default_trees() -> void:
	for tree_data_variant in _map_layout.get("default_trees", []):
		var tree_data: Dictionary = tree_data_variant
		var tile_position := _position_from_data(tree_data)
		if not _can_hold_natural_resource(tile_position):
			continue
		var tile = _create_farming_tile(tile_position, false, true)
		if tile == null or tile.state != "empty":
			continue
		var stage: int = clampi(int(tree_data.get("stage", 0)), 0, CropData.get_growth_stage_count("tree") - 1)
		tile.load_save_data({
			"grid_x": tile_position.x,
			"grid_y": tile_position.y,
			"state": "grown" if stage >= CropData.get_growth_stage_count("tree") - 1 else "planted",
			"crop_id": "tree",
			"current_stage": stage,
			"growth_minutes": stage * CropData.get_stage_duration_minutes("tree"),
			"watered_today": false
		})


func _position_from_data(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("grid_x", 0)), int(data.get("grid_y", 0)))


func _is_within_map(tile_position: Vector2i) -> bool:
	return tile_position.x >= 0 and tile_position.y >= 0 and tile_position.x < GRID_WIDTH and tile_position.y < GRID_HEIGHT


func _is_water_tile(tile_position: Vector2i) -> bool:
	return _water_tiles.has(tile_position)


func _can_hold_natural_resource(tile_position: Vector2i) -> bool:
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return false
	if _placed_chests.has(tile_position) or _placed_workbenches.has(tile_position) or _placed_furnaces.has(tile_position) or _placed_ores.has(tile_position):
		return false
	return true


func _draw_water_tiles() -> void:
	for tile_position in _water_tiles.keys():
		_draw_water_tile(tile_position)


func _draw_water_tile(tile_position: Vector2i) -> void:
	var origin := Vector2(tile_position.x * TILE_SIZE, tile_position.y * TILE_SIZE)
	var tile_rect := Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE))
	draw_rect(tile_rect, Color(0.13, 0.66, 0.72))
	draw_rect(Rect2(origin + Vector2(2.0, 2.0), Vector2(TILE_SIZE - 4.0, TILE_SIZE - 4.0)), Color(0.16, 0.76, 0.78))
	draw_line(origin + Vector2(9.0, 12.0), origin + Vector2(27.0, 8.0), Color(0.72, 0.98, 0.92, 0.48), 1.0)
	draw_line(origin + Vector2(24.0, 30.0), origin + Vector2(41.0, 25.0), Color(0.73, 1.0, 0.95, 0.35), 1.0)
	_draw_water_shore(tile_position, Vector2i.UP)
	_draw_water_shore(tile_position, Vector2i.DOWN)
	_draw_water_shore(tile_position, Vector2i.LEFT)
	_draw_water_shore(tile_position, Vector2i.RIGHT)


func _draw_water_shore(tile_position: Vector2i, direction: Vector2i) -> void:
	if _is_water_tile(tile_position + direction):
		return
	var origin := Vector2(tile_position.x * TILE_SIZE, tile_position.y * TILE_SIZE)
	var shallow_color := Color(0.36, 0.84, 0.74, 0.88)
	var bank_color := Color(0.74, 0.55, 0.30, 0.92)
	var grass_color := Color(0.54, 0.78, 0.30, 0.92)
	if direction == Vector2i.UP:
		draw_rect(Rect2(origin, Vector2(TILE_SIZE, 8.0)), shallow_color)
		draw_rect(Rect2(origin, Vector2(TILE_SIZE, 3.0)), bank_color)
		draw_rect(Rect2(origin, Vector2(TILE_SIZE, 1.0)), grass_color)
	elif direction == Vector2i.DOWN:
		draw_rect(Rect2(origin + Vector2(0.0, TILE_SIZE - 8.0), Vector2(TILE_SIZE, 8.0)), shallow_color)
		draw_rect(Rect2(origin + Vector2(0.0, TILE_SIZE - 3.0), Vector2(TILE_SIZE, 3.0)), bank_color)
		draw_rect(Rect2(origin + Vector2(0.0, TILE_SIZE - 1.0), Vector2(TILE_SIZE, 1.0)), grass_color)
	elif direction == Vector2i.LEFT:
		draw_rect(Rect2(origin, Vector2(8.0, TILE_SIZE)), shallow_color)
		draw_rect(Rect2(origin, Vector2(3.0, TILE_SIZE)), bank_color)
		draw_rect(Rect2(origin, Vector2(1.0, TILE_SIZE)), grass_color)
	elif direction == Vector2i.RIGHT:
		draw_rect(Rect2(origin + Vector2(TILE_SIZE - 8.0, 0.0), Vector2(8.0, TILE_SIZE)), shallow_color)
		draw_rect(Rect2(origin + Vector2(TILE_SIZE - 3.0, 0.0), Vector2(3.0, TILE_SIZE)), bank_color)
		draw_rect(Rect2(origin + Vector2(TILE_SIZE - 1.0, 0.0), Vector2(1.0, TILE_SIZE)), grass_color)


func _get_water_atlas_region(tile_index: int) -> Rect2:
	var texture_size: Vector2 = _water_texture.get_size()
	var source_tile_width := floorf(texture_size.x / float(WATER_TILE_SOURCE_COLUMNS))
	var source_tile_height := floorf(texture_size.y / float(WATER_TILE_SOURCE_ROWS))
	var column := tile_index % WATER_TILE_SOURCE_COLUMNS
	var row := tile_index / WATER_TILE_SOURCE_COLUMNS
	return Rect2(column * source_tile_width, row * source_tile_height, source_tile_width, source_tile_height)


func _choose_water_tile_index(tile_position: Vector2i) -> int:
	var north := _is_water_tile(tile_position + Vector2i.UP)
	var south := _is_water_tile(tile_position + Vector2i.DOWN)
	var west := _is_water_tile(tile_position + Vector2i.LEFT)
	var east := _is_water_tile(tile_position + Vector2i.RIGHT)
	if not north and not west:
		return 5
	if not north and not east:
		return 6
	if not south and not west:
		return 7
	if not south and not east:
		return 8
	if east and west and not north and not south:
		return 13
	if north and south and not east and not west:
		return 14
	if north and south and east and west:
		if not _is_water_tile(tile_position + Vector2i(-1, -1)):
			return 9
		if not _is_water_tile(tile_position + Vector2i(1, -1)):
			return 10
		if not _is_water_tile(tile_position + Vector2i(-1, 1)):
			return 11
		if not _is_water_tile(tile_position + Vector2i(1, 1)):
			return 12
		return 0
	if not north:
		return 1
	if not south:
		return 2
	if not west:
		return 3
	if not east:
		return 4
	return 15


func _use_tile_action(action_name: String) -> void:
	var tile = _get_facing_tile()
	if tile == null:
		return
	match action_name:
		"till":
			if tile.till():
				_feedback_controller.play_interact()
		"plant":
			if tile.plant("wheat"):
				_feedback_controller.play_interact()
		"water":
			if tile.water():
				_feedback_controller.play_water()
		"harvest":
			var harvest_result: Dictionary = tile.harvest()
			if not harvest_result.is_empty():
				spawn_item_drop(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 1)), tile.get_feedback_position())
				_feedback_controller.play_harvest()
				print("收获了 %s x%d" % [harvest_result.get("item_id", ""), harvest_result.get("amount", 0)])


func _use_selected_tool() -> void:
	var selected_item_id: String = _hud.get_selected_item_id()
	if selected_item_id.is_empty():
		return
	var tile = _get_facing_tile()
	player.play_tool_swing(selected_item_id)
	_hud.pulse_selected_slot()
	var facing_tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if _placed_ores.has(facing_tile_position) and selected_item_id != "pickaxe":
		return
	if selected_item_id == "hoe":
		if tile != null and tile.till():
			_feedback_controller.play_interact()
	elif selected_item_id == "axe":
		var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
		if _remove_workbench_at(tile_position):
			_feedback_controller.play_harvest()
		elif _remove_furnace_at(tile_position):
			_feedback_controller.play_harvest()
		elif tile != null and tile.can_chop_tree():
			var chop_result: Dictionary = tile.chop_with_axe()
			if not chop_result.is_empty():
				_collect_chop_drops(chop_result.get("drops", []), tile.get_feedback_position())
				_feedback_controller.play_harvest()
			else:
				_feedback_controller.play_interact()
	elif selected_item_id == "watering_can":
		if tile != null and tile.water():
			_feedback_controller.play_water()
	elif selected_item_id == "scythe":
		if tile != null and tile.can_harvest():
			var harvest_result: Dictionary = tile.harvest()
			if not harvest_result.is_empty():
				spawn_item_drop(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 1)), tile.get_feedback_position())
				_feedback_controller.play_harvest()
	elif selected_item_id == "pickaxe":
		var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
		if _mine_ore_at(tile_position):
			_feedback_controller.play_harvest()
	elif ItemDatabase.is_container(selected_item_id):
		var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
		if _place_chest_at(tile_position, selected_item_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()
	elif ItemDatabase.is_placeable(selected_item_id):
		var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
		var placeable_type: String = ItemDatabase.get_placeable_type(selected_item_id)
		if placeable_type == "workbench" and _place_workbench_at(tile_position, selected_item_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()
		elif placeable_type == "furnace" and _place_furnace_at(tile_position, selected_item_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()
	elif ItemDatabase.is_seed(selected_item_id):
		if tile == null:
			return
		var crop_id: String = ItemDatabase.get_crop_id_from_seed(selected_item_id)
		if tile.plant(crop_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()


func _get_facing_tile():
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	return _tiles.get(tile_position, null)


func _collect_chop_drops(drops: Array, feedback_position: Vector2) -> void:
	var feedback_offset: float = 0.0
	for drop_variant in drops:
		var drop: Dictionary = drop_variant
		var item_id: String = String(drop.get("item_id", ""))
		var amount: int = int(drop.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		InventoryManager.add_item_prefer_hotbar(item_id, amount)
		_feedback_controller.show_pickup_feedback(
			ItemDatabase.get_display_name(item_id),
			amount,
			feedback_position + Vector2(0, feedback_offset)
		)
		feedback_offset -= 18.0


func _open_facing_chest() -> void:
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if not _placed_chests.has(tile_position):
		return
	_hud.open_chest(_placed_chests[tile_position])
	_feedback_controller.play_ui_click()


func _open_facing_workbench() -> bool:
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if not _placed_workbenches.has(tile_position):
		return false
	_hud.open_workbench()
	_feedback_controller.play_ui_click()
	return true


func _open_facing_furnace() -> bool:
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if not _placed_furnaces.has(tile_position):
		return false
	_hud.open_furnace()
	_feedback_controller.play_ui_click()
	return true


func _place_chest_at(tile_position: Vector2i, item_id: String, slots: Array = [], validate_tile: bool = true) -> bool:
	if not ItemDatabase.is_container(item_id):
		return false
	if _placed_chests.has(tile_position):
		return false
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return false
	if _placed_workbenches.has(tile_position):
		return false
	if _placed_furnaces.has(tile_position):
		return false
	if _placed_ores.has(tile_position):
		return false
	if validate_tile:
		var tile = _tiles.get(tile_position, null)
		if tile != null and tile.state != "empty":
			return false
	var chest_data := {
		"item_id": item_id,
		"slots": _normalize_chest_slots(item_id, slots)
	}
	_placed_chests[tile_position] = chest_data
	_spawn_chest_node(tile_position, item_id)
	return true


func _spawn_chest_node(tile_position: Vector2i, item_id: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Chest_%d_%d" % [tile_position.x, tile_position.y]
	sprite.texture = ItemDatabase.get_icon(item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5)
	sprite.z_index = 8
	_chests_root.add_child(sprite)
	_spawn_static_collision(
		_chests_root,
		"ChestCollision_%d_%d" % [tile_position.x, tile_position.y],
		Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.62),
		Vector2(30.0, 24.0)
	)


func _place_workbench_at(tile_position: Vector2i, item_id: String, validate_tile: bool = true) -> bool:
	if item_id != "workbench":
		return false
	if _placed_workbenches.has(tile_position) or _placed_furnaces.has(tile_position) or _placed_chests.has(tile_position) or _placed_ores.has(tile_position):
		return false
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return false
	if validate_tile:
		var tile = _tiles.get(tile_position, null)
		if tile != null and tile.state != "empty":
			return false
	_placed_workbenches[tile_position] = {"item_id": item_id}
	_spawn_workbench_node(tile_position, item_id)
	return true


func _spawn_workbench_node(tile_position: Vector2i, item_id: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Workbench_%d_%d" % [tile_position.x, tile_position.y]
	sprite.texture = ItemDatabase.get_icon(item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.47)
	sprite.z_index = 9
	if sprite.texture != null:
		var texture_size: Vector2i = sprite.texture.get_size()
		var max_dimension: float = maxf(texture_size.x, texture_size.y)
		sprite.scale = Vector2.ONE * (42.0 / max_dimension)
	_workbenches_root.add_child(sprite)
	_spawn_static_collision(
		_workbenches_root,
		"WorkbenchCollision_%d_%d" % [tile_position.x, tile_position.y],
		Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.64),
		Vector2(30.0, 22.0)
	)


func _place_furnace_at(tile_position: Vector2i, item_id: String, validate_tile: bool = true) -> bool:
	if item_id != "furnace":
		return false
	if _placed_furnaces.has(tile_position) or _placed_workbenches.has(tile_position) or _placed_chests.has(tile_position) or _placed_ores.has(tile_position):
		return false
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return false
	if validate_tile:
		var tile = _tiles.get(tile_position, null)
		if tile != null and tile.state != "empty":
			return false
	_placed_furnaces[tile_position] = {"item_id": item_id}
	_spawn_furnace_node(tile_position, item_id)
	return true


func _spawn_furnace_node(tile_position: Vector2i, item_id: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Furnace_%d_%d" % [tile_position.x, tile_position.y]
	sprite.texture = ItemDatabase.get_icon(item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.45)
	sprite.z_index = 9
	if sprite.texture != null:
		var texture_size: Vector2i = sprite.texture.get_size()
		var max_dimension: float = maxf(texture_size.x, texture_size.y)
		sprite.scale = Vector2.ONE * (44.0 / max_dimension)
	_furnaces_root.add_child(sprite)
	_spawn_static_collision(
		_furnaces_root,
		"FurnaceCollision_%d_%d" % [tile_position.x, tile_position.y],
		Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.66),
		Vector2(30.0, 24.0)
	)


func _place_ore_at(tile_position: Vector2i, node_id: String, validate_tile: bool = true) -> bool:
	if not MiningData.node_exists(node_id):
		return false
	if _placed_ores.has(tile_position) or _placed_chests.has(tile_position) or _placed_workbenches.has(tile_position) or _placed_furnaces.has(tile_position):
		return false
	if not _is_within_map(tile_position) or _is_water_tile(tile_position):
		return false
	if validate_tile:
		var tile = _tiles.get(tile_position, null)
		if tile != null and tile.state != "empty":
			return false
	_placed_ores[tile_position] = {"node_id": node_id}
	_spawn_ore_node(tile_position, node_id)
	return true


func _spawn_ore_node(tile_position: Vector2i, node_id: String) -> void:
	var node_data: Dictionary = MiningData.get_node_data(node_id)
	var ore_item_id: String = String(node_data.get("ore_item_id", ""))
	var sprite := Sprite2D.new()
	sprite.name = "Ore_%d_%d" % [tile_position.x, tile_position.y]
	sprite.texture = ItemDatabase.get_icon(ore_item_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5)
	sprite.z_index = 8
	if sprite.texture != null:
		var texture_size: Vector2i = sprite.texture.get_size()
		var max_dimension: float = maxf(texture_size.x, texture_size.y)
		sprite.scale = Vector2.ONE * (38.0 / max_dimension)
	_ores_root.add_child(sprite)
	_spawn_static_collision(
		_ores_root,
		"OreCollision_%d_%d" % [tile_position.x, tile_position.y],
		Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.58),
		Vector2(30.0, 24.0)
	)


func _mine_ore_at(tile_position: Vector2i) -> bool:
	if not _placed_ores.has(tile_position):
		return false
	var node_id: String = String(_placed_ores[tile_position].get("node_id", ""))
	var node_data: Dictionary = MiningData.get_node_data(node_id)
	var drop_item_id: String = String(node_data.get("drop_item_id", ""))
	var drop_amount: int = MiningData.roll_drop_amount(node_id)
	_clear_ore_at(tile_position)
	var drop_position := Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5)
	spawn_item_drop(drop_item_id, drop_amount, drop_position)
	_feedback_controller.show_harvest_feedback(drop_position)
	return true


func _remove_workbench_at(tile_position: Vector2i) -> bool:
	if not _placed_workbenches.has(tile_position):
		return false
	_placed_workbenches.erase(tile_position)
	var node_name := "Workbench_%d_%d" % [tile_position.x, tile_position.y]
	var workbench_node := _workbenches_root.get_node_or_null(node_name)
	if workbench_node != null:
		workbench_node.queue_free()
	var collision_name := "WorkbenchCollision_%d_%d" % [tile_position.x, tile_position.y]
	var collision_node := _workbenches_root.get_node_or_null(collision_name)
	if collision_node != null:
		collision_node.queue_free()
	spawn_item_drop("workbench", 1, Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5), Vector2.ZERO, true)
	return true


func _remove_furnace_at(tile_position: Vector2i) -> bool:
	if not _placed_furnaces.has(tile_position):
		return false
	_placed_furnaces.erase(tile_position)
	var node_name := "Furnace_%d_%d" % [tile_position.x, tile_position.y]
	var furnace_node := _furnaces_root.get_node_or_null(node_name)
	if furnace_node != null:
		furnace_node.queue_free()
	var collision_name := "FurnaceCollision_%d_%d" % [tile_position.x, tile_position.y]
	var collision_node := _furnaces_root.get_node_or_null(collision_name)
	if collision_node != null:
		collision_node.queue_free()
	spawn_item_drop("furnace", 1, Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5), Vector2.ZERO, true)
	return true


func _spawn_static_collision(parent: Node, body_name: String, body_position: Vector2, shape_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = body_position
	body.collision_layer = MAP_OBJECT_COLLISION_LAYER
	body.collision_mask = MAP_OBJECT_COLLISION_MASK
	var collision_shape := CollisionShape2D.new()
	var rectangle_shape := RectangleShape2D.new()
	rectangle_shape.size = shape_size
	collision_shape.shape = rectangle_shape
	body.add_child(collision_shape)
	parent.add_child(body)


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


func _normalize_chest_slots(item_id: String, slots: Array) -> Array:
	var result: Array = []
	var capacity: int = ItemDatabase.get_container_capacity(item_id)
	for index in range(capacity):
		if index < slots.size():
			var slot_data: Dictionary = slots[index]
			var slot_item_id: String = String(slot_data.get("item_id", ""))
			var amount: int = int(slot_data.get("amount", 0))
			if slot_item_id.is_empty() or amount <= 0:
				result.append({"item_id": "", "amount": 0})
			else:
				result.append({"item_id": slot_item_id, "amount": amount})
		else:
			result.append({"item_id": "", "amount": 0})
	return result


func _clear_placed_chests() -> void:
	_placed_chests.clear()
	if _chests_root == null:
		return
	for child in _chests_root.get_children():
		child.queue_free()


func _clear_placed_workbenches() -> void:
	_placed_workbenches.clear()
	if _workbenches_root == null:
		return
	for child in _workbenches_root.get_children():
		child.queue_free()


func _clear_placed_furnaces() -> void:
	_placed_furnaces.clear()
	if _furnaces_root == null:
		return
	for child in _furnaces_root.get_children():
		child.queue_free()


func _clear_placed_ores() -> void:
	_placed_ores.clear()
	if _ores_root == null:
		return
	for child in _ores_root.get_children():
		child.queue_free()


func _clear_ore_at(tile_position: Vector2i) -> void:
	if not _placed_ores.has(tile_position):
		return
	_placed_ores.erase(tile_position)
	if _ores_root == null:
		return
	var node_name := "Ore_%d_%d" % [tile_position.x, tile_position.y]
	var ore_node := _ores_root.get_node_or_null(node_name)
	if ore_node != null:
		ore_node.queue_free()
	var collision_name := "OreCollision_%d_%d" % [tile_position.x, tile_position.y]
	var collision_node := _ores_root.get_node_or_null(collision_name)
	if collision_node != null:
		collision_node.queue_free()


func _clear_ores_on_occupied_tiles() -> void:
	for tile_position_variant in _placed_ores.keys().duplicate():
		var tile_position: Vector2i = tile_position_variant
		if not _is_within_map(tile_position) or _is_water_tile(tile_position):
			_clear_ore_at(tile_position)
			continue
		if _tiles.has(tile_position) and _tiles[tile_position].state != "empty":
			_clear_ore_at(tile_position)


func _spawn_default_ores() -> void:
	if not _placed_ores.is_empty():
		return
	for ore_data in MiningData.get_default_nodes():
		var grid_position := Vector2i(int(ore_data.get("grid_x", 0)), int(ore_data.get("grid_y", 0)))
		_place_ore_at(grid_position, String(ore_data.get("node_id", "")), true)


func _sell_all_crops() -> void:
	var inventory: Dictionary = InventoryManager.get_all_items()
	var total_gold: int = 0
	var sold_lines: Array[String] = []
	for item_id in inventory.keys():
		if not CropData.crop_exists(String(item_id)):
			continue
		var amount: int = InventoryManager.get_item_count(String(item_id))
		if amount <= 0:
			continue
		var crop_data: Dictionary = CropData.get_crop(String(item_id))
		var sell_price: int = int(crop_data.get("sell_price", 0))
		var earned: int = sell_price * amount
		if InventoryManager.remove_item(String(item_id), amount):
			total_gold += earned
			sold_lines.append("%s x%d => %d gold" % [item_id, amount, earned])
	if total_gold > 0:
		CurrencyManager.add_gold(total_gold)
		_feedback_controller.show_gold_feedback(total_gold, player.global_position + Vector2(0, -48))
		print("已出售作物：")
		for line in sold_lines:
			print(" - %s" % line)
		print("总计获得金币：%d | 当前金币：%d" % [total_gold, CurrencyManager.gold])
	else:
		print("没有可出售的作物。")


func _spawn_existing_assistants() -> void:
	for character_id_variant in RecruitmentManager.get_hired_character_ids():
		ensure_assistant_node(String(character_id_variant))


func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func spawn_water_feedback(world_position: Vector2) -> void:
	_feedback_controller.show_water_feedback(world_position)


func spawn_harvest_feedback(world_position: Vector2) -> void:
	_feedback_controller.show_harvest_feedback(world_position)


func _ensure_feedback_controller() -> void:
	_feedback_controller = Node2D.new()
	_feedback_controller.name = "Feedback"
	_feedback_controller.set_script(FEEDBACK_SCRIPT)
	add_child(_feedback_controller)


func _ensure_water_root() -> void:
	_water_root = Node2D.new()
	_water_root.name = "Water"
	add_child(_water_root)


func _ensure_chests_root() -> void:
	_chests_root = Node2D.new()
	_chests_root.name = "Chests"
	add_child(_chests_root)


func _ensure_workbenches_root() -> void:
	_workbenches_root = Node2D.new()
	_workbenches_root.name = "Workbenches"
	add_child(_workbenches_root)


func _ensure_furnaces_root() -> void:
	_furnaces_root = Node2D.new()
	_furnaces_root.name = "Furnaces"
	add_child(_furnaces_root)


func _ensure_ores_root() -> void:
	_ores_root = Node2D.new()
	_ores_root.name = "Ores"
	add_child(_ores_root)


func _ensure_interaction_hint() -> void:
	_interaction_hint_label = Label.new()
	_interaction_hint_label.visible = false
	_interaction_hint_label.z_index = 120
	_interaction_hint_label.text = "按 E 制造"
	_interaction_hint_label.add_theme_font_size_override("font_size", 14)
	_interaction_hint_label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.08))
	_interaction_hint_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.96, 0.84, 0.85))
	_interaction_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_interaction_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_interaction_hint_label)


func _ensure_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "FarmHud"
	_hud.set_script(HUD_SCRIPT)
	add_child(_hud)
	_hud.tool_selected.connect(_on_tool_selected)
	_hud.buy_requested.connect(_on_buy_requested)
	_hud.sell_requested.connect(_on_sell_requested)
	_hud.recruit_requested.connect(_on_recruit_requested)
	_hud.ui_clicked.connect(_on_ui_clicked)


func spawn_item_drop(item_id: String, amount: int, world_position: Vector2, initial_velocity: Vector2 = Vector2.ZERO, wait_for_player_exit_pickup_range: bool = false) -> void:
	var item_drop = ITEM_DROP_SCENE.instantiate()
	add_child(item_drop)
	item_drop.set_spawn_world_position(world_position)
	item_drop.setup(item_id, amount)
	if wait_for_player_exit_pickup_range and item_drop.has_method("wait_for_player_exit_pickup_range"):
		item_drop.wait_for_player_exit_pickup_range()
	item_drop.launch(initial_velocity)


func drop_item_at_player(item_id: String, amount: int) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	spawn_item_drop(item_id, amount, player.global_position, Vector2.ZERO, true)


func craft_item_from_workbench(recipe_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if not CraftingData.can_craft(recipe_id, amount):
		_feedback_controller.show_text("材料不足", Color(1.0, 0.45, 0.30), player.global_position + Vector2(0, -72))
		return
	var recipe: Dictionary = CraftingData.get_recipe(recipe_id)
	var output_item_id: String = String(recipe.get("output_item_id", recipe_id))
	var output_amount: int = maxi(int(recipe.get("output_amount", 1)), 1) * amount
	if not CraftingData.consume_ingredients(recipe_id, amount):
		_feedback_controller.show_text("材料不足", Color(1.0, 0.45, 0.30), player.global_position + Vector2(0, -72))
		return
	var dropped_amount: int = _distribute_crafted_items(output_item_id, output_amount)
	var crafted_amount: int = output_amount - dropped_amount
	if crafted_amount > 0:
		_feedback_controller.show_pickup_feedback(ItemDatabase.get_display_name(output_item_id), crafted_amount, player.global_position + Vector2(0, -48))
	if dropped_amount > 0:
		_feedback_controller.show_text("背包已满，掉落 x%d" % dropped_amount, Color(1.0, 0.82, 0.42), player.global_position + Vector2(0, -80))
	_feedback_controller.play_ui_click()


func smelt_item_from_furnace(recipe_id: String) -> void:
	if not SmeltingData.can_smelt(recipe_id):
		_feedback_controller.show_text("材料不足", Color(1.0, 0.45, 0.30), player.global_position + Vector2(0, -72))
		return
	var recipe: Dictionary = SmeltingData.get_recipe(recipe_id)
	var output_item_id: String = String(recipe.get("output_item_id", recipe_id))
	var output_amount: int = maxi(int(recipe.get("output_amount", 1)), 1)
	if not SmeltingData.consume_ingredients(recipe_id):
		_feedback_controller.show_text("材料不足", Color(1.0, 0.45, 0.30), player.global_position + Vector2(0, -72))
		return
	var dropped_amount: int = _distribute_crafted_items(output_item_id, output_amount)
	var crafted_amount: int = output_amount - dropped_amount
	if crafted_amount > 0:
		_feedback_controller.show_pickup_feedback(ItemDatabase.get_display_name(output_item_id), crafted_amount, player.global_position + Vector2(0, -48))
	if dropped_amount > 0:
		_feedback_controller.show_text("背包已满，掉落 x%d" % dropped_amount, Color(1.0, 0.82, 0.42), player.global_position + Vector2(0, -80))
	_feedback_controller.play_ui_click()


func recruit_character(character_id: String) -> bool:
	var character_data := RecruitmentManager.get_character(character_id)
	if character_data.is_empty():
		return false
	var spawn_position: Vector2 = player.global_position + Vector2(18.0, 10.0)
	if not RecruitmentManager.hire_character(character_id, spawn_position):
		_feedback_controller.show_text("许愿石不足", Color(1.0, 0.45, 0.30), player.global_position + Vector2(0, -72))
		return false
	_feedback_controller.show_hire_feedback(String(character_data.get("name", character_id)), spawn_position + Vector2(0, -32))
	if _hud != null and _hud.has_method("refresh_recruit_panel"):
		_hud.refresh_recruit_panel()
	return true


func _distribute_crafted_items(item_id: String, amount: int) -> int:
	var dropped_amount: int = 0
	for _index in range(amount):
		if not _try_add_single_item_to_hotbar_or_inventory(item_id):
			spawn_item_drop(item_id, 1, player.global_position)
			dropped_amount += 1
	return dropped_amount


func _try_add_single_item_to_hotbar_or_inventory(item_id: String) -> bool:
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	if hotbar_manager.add_item(item_id, 1) <= 0:
		return true
	var inventory_index: int = InventoryManager.find_first_empty_slot()
	if inventory_index == -1:
		return false
	InventoryManager.set_slot(inventory_index, {"item_id": item_id, "amount": 1})
	return true


func _drop_selected_hotbar_item() -> void:
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	var selected_index: int = int(hotbar_manager.selected_index)
	var slot_data: Dictionary = hotbar_manager.get_slot(selected_index)
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return
	if not hotbar_manager.remove_from_slot(selected_index, amount):
		return
	drop_item_at_player(item_id, amount)
	_feedback_controller.play_interact()


func _update_interaction_hint() -> void:
	if _interaction_hint_label == null:
		return
	if _hud != null and _hud.is_inventory_open():
		_interaction_hint_label.visible = false
		return
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if _placed_workbenches.has(tile_position):
		_interaction_hint_label.text = "按 E 制造"
	elif _placed_furnaces.has(tile_position):
		_interaction_hint_label.text = "按 E 烧制"
	else:
		_interaction_hint_label.visible = false
		return
	_interaction_hint_label.position = Vector2(tile_position.x * TILE_SIZE + 7.0, tile_position.y * TILE_SIZE - 22.0)
	_interaction_hint_label.visible = true


func on_item_drop_collected(item_id: String, amount: int, world_position: Vector2) -> void:
	_feedback_controller.show_pickup_feedback(ItemDatabase.get_display_name(item_id), amount, world_position)


func _on_tool_selected(_item_id: String) -> void:
	pass


func _on_sell_requested(item_id: String, amount: int) -> void:
	if not _shop_sell_items.has(item_id):
		return
	var sell_price: int = ItemDatabase.get_sell_price(item_id)
	if sell_price <= 0:
		return
	if not InventoryManager.remove_item(item_id, amount):
		return
	var total_gold: int = sell_price * amount
	CurrencyManager.add_gold(total_gold)
	_feedback_controller.show_gold_feedback(total_gold, player.global_position + Vector2(0, -56))


func _on_recruit_requested(character_id: String) -> void:
	recruit_character(character_id)


func _on_buy_requested(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if not _shop_buy_items.has(item_id):
		return
	var crop_id: String = ItemDatabase.get_crop_id_from_seed(item_id)
	if crop_id.is_empty():
		return
	var seed_price: int = int(CropData.get_crop(crop_id).get("seed_price", 0))
	if seed_price <= 0:
		return
	var total_gold: int = seed_price * amount
	if not CurrencyManager.spend_gold(total_gold):
		print("金币不足，无法购买 %s x%d。" % [ItemDatabase.get_display_name(item_id), amount])
		return
	InventoryManager.add_item_prefer_hotbar(item_id, amount)
	_feedback_controller.show_text(
		"购入 %s x%d" % [ItemDatabase.get_display_name(item_id), amount],
		Color(0.74, 0.95, 1.0),
		player.global_position + Vector2(0, -72)
	)
	_feedback_controller.play_ui_click()


func _on_ui_clicked() -> void:
	_feedback_controller.play_ui_click()
