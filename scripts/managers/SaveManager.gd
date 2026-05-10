extends Node


const SAVE_PATH := "user://save_game.json"


func save_game() -> void:
	var farm_data: Array = []
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("get_farm_tile_save_data"):
		farm_data = GameManager.farm_scene.get_farm_tile_save_data()
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	var payload: Dictionary = {
		"day": TimeManager.day,
		"gold": CurrencyManager.gold,
		"wish_stone": CurrencyManager.wish_stone,
		"inventory": InventoryManager.get_all_items(),
		"inventory_slots": InventoryManager.get_slots(),
		"hotbar_slots": hotbar_manager.get_slots(),
		"hired_characters": RecruitmentManager.get_hired_character_ids(),
		"farm_tiles": farm_data
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager.save_game: failed to open save file.")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	print("SaveManager: game saved to %s" % SAVE_PATH)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveManager.load_game: save file does not exist.")
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager.load_game: failed to read save file.")
		return
	var raw_text: String = file.get_as_text()
	var parser: JSON = JSON.new()
	var result: int = parser.parse(raw_text)
	if result != OK:
		push_error("SaveManager.load_game: failed to parse save file.")
		return
	var payload: Dictionary = parser.data
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	TimeManager.set_day(int(payload.get("day", 1)))
	CurrencyManager.set_gold(int(payload.get("gold", 0)))
	CurrencyManager.set_wish_stone(int(payload.get("wish_stone", 0)))
	if payload.has("inventory_slots"):
		InventoryManager.set_slots(payload.get("inventory_slots", []))
	else:
		InventoryManager.set_all_items(payload.get("inventory", {}))
	if payload.has("hotbar_slots"):
		hotbar_manager.set_slots(payload.get("hotbar_slots", []))
	else:
		hotbar_manager.reset_to_default()
	RecruitmentManager.set_hired_character_ids(payload.get("hired_characters", []))
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("load_farm_tile_save_data"):
		GameManager.farm_scene.load_farm_tile_save_data(payload.get("farm_tiles", []))
	print("SaveManager: game loaded from %s" % SAVE_PATH)
