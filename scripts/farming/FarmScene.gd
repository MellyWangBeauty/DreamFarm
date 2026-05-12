extends Node2D


const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const TILE_SIZE := 48.0
const HUD_SCRIPT := preload("res://scripts/ui/FarmHud.gd")
const FEEDBACK_SCRIPT := preload("res://scripts/effects/FarmFeedback.gd")
const ITEM_DROP_SCENE := preload("res://scenes/items/ItemDrop.tscn")

@onready var player = $Player
@onready var tiles_root: Node2D = $Tiles
@onready var assistants_root: Node = $Assistants

var _tiles: Dictionary = {}
var _feedback_controller: Node2D
var _hud


func _ready() -> void:
	GameManager.register_farm_scene(self)
	_ensure_feedback_controller()
	_ensure_hud()
	_create_tiles()
	_spawn_existing_assistants()
	queue_redraw()
	print("FarmScene ready. 1-0 hotbar, LMB use, B bag, N next day, K hire aria, F5 save, F9 load.")


func _exit_tree() -> void:
	GameManager.unregister_farm_scene(self)


func _unhandled_input(event: InputEvent) -> void:
	if _hud != null and _hud.has_method("handle_global_input") and _hud.handle_global_input(event):
		return
	if _is_left_click(event) or _is_key_pressed(event, KEY_SPACE):
		if not _hud.is_inventory_open():
			_use_selected_tool()
	elif _is_key_pressed(event, KEY_N):
		TimeManager.next_day()
	elif _is_key_pressed(event, KEY_K):
		var hired: bool = RecruitmentManager.hire_character("aria")
		if hired:
			_feedback_controller.show_hire_feedback("Aria", Vector2(350, 10))
		print("Hire aria result: %s" % hired)
	elif _is_key_pressed(event, KEY_F5):
		SaveManager.save_game()
	elif _is_key_pressed(event, KEY_F9):
		SaveManager.load_game()


func _draw() -> void:
	draw_rect(Rect2(-256, -180, 1600, 1100), Color(0.63, 0.83, 0.44))
	draw_rect(Rect2(-20, -20, GRID_WIDTH * TILE_SIZE + 40, GRID_HEIGHT * TILE_SIZE + 40), Color(0.76, 0.67, 0.45, 0.85))
	for x in range(GRID_WIDTH + 1):
		var x_pos: float = x * TILE_SIZE
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, GRID_HEIGHT * TILE_SIZE), Color(0.45, 0.38, 0.20, 0.15), 1.0)
	for y in range(GRID_HEIGHT + 1):
		var y_pos: float = y * TILE_SIZE
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
	var assistant_script = load("res://scripts/characters/Assistant.gd")
	var assistant = Node2D.new()
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
			var tile_script = load("res://scripts/farming/FarmingTile.gd")
			var tile = Node2D.new()
			tile.set_script(tile_script)
			tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			tile.grid_position = Vector2i(x, y)
			tile.name = "Tile_%d_%d" % [x, y]
			tiles_root.add_child(tile)
			_tiles[Vector2i(x, y)] = tile


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
				InventoryManager.add_item(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 0)))
				_feedback_controller.show_text("+%s" % String(harvest_result.get("item_id", "")), Color(1.0, 0.95, 0.72), tile.get_feedback_position() + Vector2(0, -20))
				_feedback_controller.play_harvest()
				print("Harvested %s x%d" % [harvest_result.get("item_id", ""), harvest_result.get("amount", 0)])


func _use_selected_tool() -> void:
	var selected_item_id: String = _hud.get_selected_item_id()
	if selected_item_id.is_empty():
		return
	var tile = _get_facing_tile()
	if tile == null:
		return
	player.play_tool_swing(selected_item_id)
	_hud.pulse_selected_slot()
	if selected_item_id == "hoe":
		if tile.till():
			_feedback_controller.play_interact()
	elif selected_item_id == "watering_can":
		if tile.water():
			_feedback_controller.play_water()
	elif selected_item_id == "scythe":
		if tile.can_harvest():
			var harvest_result: Dictionary = tile.harvest()
			if not harvest_result.is_empty():
				spawn_item_drop(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 1)), tile.get_feedback_position())
				_feedback_controller.play_harvest()
	elif ItemDatabase.is_seed(selected_item_id):
		var crop_id: String = ItemDatabase.get_crop_id_from_seed(selected_item_id)
		if tile.plant(crop_id):
			_feedback_controller.play_interact()


func _get_facing_tile():
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	return _tiles.get(tile_position, null)


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


func _ensure_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "FarmHud"
	_hud.set_script(HUD_SCRIPT)
	add_child(_hud)
	_hud.tool_selected.connect(_on_tool_selected)
	_hud.sell_requested.connect(_on_sell_requested)
	_hud.ui_clicked.connect(_on_ui_clicked)

func spawn_item_drop(item_id: String, amount: int, world_position: Vector2) -> void:
	var item_drop = ITEM_DROP_SCENE.instantiate()
	add_child(item_drop)
	item_drop.set_spawn_world_position(world_position)
	item_drop.setup(item_id, amount)
	item_drop.launch(Vector2(randf_range(-42.0, 42.0), randf_range(-12.0, 16.0)))


func on_item_drop_collected(item_id: String, amount: int, world_position: Vector2) -> void:
	_feedback_controller.show_pickup_feedback(ItemDatabase.get_display_name(item_id), amount, world_position)


func _on_tool_selected(_item_id: String) -> void:
	pass


func _on_sell_requested(item_id: String, amount: int) -> void:
	var sell_price: int = ItemDatabase.get_sell_price(item_id)
	if sell_price <= 0:
		return
	if not InventoryManager.remove_item(item_id, amount):
		return
	var total_gold: int = sell_price * amount
	CurrencyManager.add_gold(total_gold)
	_feedback_controller.show_gold_feedback(total_gold, player.global_position + Vector2(0, -56))


func _on_ui_clicked() -> void:
	_feedback_controller.play_ui_click()
