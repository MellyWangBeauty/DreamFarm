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
var _placed_chests: Dictionary = {}
var _chests_root: Node2D
var _feedback_controller: Node2D
var _hud
var _shop_sell_items: Array[String] = ["wheat", "potato", "carrot"]
var _shop_buy_items: Array[String] = ["wheat_seed", "potato_seed", "carrot_seed"]


func _ready() -> void:
	GameManager.register_farm_scene(self)
	_ensure_feedback_controller()
	_ensure_chests_root()
	_ensure_hud()
	_create_tiles()
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
			_open_facing_chest()
	elif _is_key_pressed(event, KEY_G):
		if not _hud.is_inventory_open():
			_drop_selected_hotbar_item()
	elif _is_left_click(event) or _is_key_pressed(event, KEY_SPACE):
		if not _hud.is_inventory_open():
			_use_selected_tool()
	elif _is_key_pressed(event, KEY_N):
		TimeManager.next_day()
	elif _is_key_pressed(event, KEY_K):
		var hired: bool = RecruitmentManager.hire_character("aria")
		if hired:
			_feedback_controller.show_hire_feedback("阿丽亚", Vector2(350, 10))
		print("招募阿丽亚结果：%s" % hired)


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


func load_farm_tile_save_data(save_data: Array) -> void:
	for tile_data_variant in save_data:
		var tile_data: Dictionary = tile_data_variant
		var position_key: Vector2i = Vector2i(int(tile_data.get("grid_x", 0)), int(tile_data.get("grid_y", 0)))
		if _tiles.has(position_key):
			_tiles[position_key].load_save_data(tile_data)
	_spawn_existing_assistants()


func load_chest_save_data(save_data: Array) -> void:
	_clear_placed_chests()
	for chest_data_variant in save_data:
		var chest_data: Dictionary = chest_data_variant
		var grid_position := Vector2i(int(chest_data.get("grid_x", 0)), int(chest_data.get("grid_y", 0)))
		var item_id := String(chest_data.get("item_id", ""))
		if not ItemDatabase.is_container(item_id):
			continue
		_place_chest_at(grid_position, item_id, chest_data.get("slots", []), false)


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
				spawn_item_drop(String(harvest_result.get("item_id", "")), int(harvest_result.get("amount", 1)), tile.get_feedback_position())
				_feedback_controller.play_harvest()
				print("收获了 %s x%d" % [harvest_result.get("item_id", ""), harvest_result.get("amount", 0)])


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
	elif ItemDatabase.is_container(selected_item_id):
		var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
		if _place_chest_at(tile_position, selected_item_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()
	elif ItemDatabase.is_seed(selected_item_id):
		var crop_id: String = ItemDatabase.get_crop_id_from_seed(selected_item_id)
		if tile.plant(crop_id):
			_hud.consume_selected_item(1)
			_feedback_controller.play_interact()


func _get_facing_tile():
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	return _tiles.get(tile_position, null)


func _open_facing_chest() -> void:
	var tile_position: Vector2i = player.get_facing_tile_position(TILE_SIZE)
	if not _placed_chests.has(tile_position):
		return
	_hud.open_chest(_placed_chests[tile_position])
	_feedback_controller.play_ui_click()


func _place_chest_at(tile_position: Vector2i, item_id: String, slots: Array = [], validate_tile: bool = true) -> bool:
	if not ItemDatabase.is_container(item_id):
		return false
	if _placed_chests.has(tile_position):
		return false
	if not _tiles.has(tile_position):
		return false
	if validate_tile:
		var tile = _tiles[tile_position]
		if tile.state != "empty":
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


func _ensure_chests_root() -> void:
	_chests_root = Node2D.new()
	_chests_root.name = "Chests"
	add_child(_chests_root)


func _ensure_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "FarmHud"
	_hud.set_script(HUD_SCRIPT)
	add_child(_hud)
	_hud.tool_selected.connect(_on_tool_selected)
	_hud.buy_requested.connect(_on_buy_requested)
	_hud.sell_requested.connect(_on_sell_requested)
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
