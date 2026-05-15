extends Node


const SAVE_PATH := "user://save_game.json"


func save_game() -> void:
	var farm_data: Array = []
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("get_farm_tile_save_data"):
		farm_data = GameManager.farm_scene.get_farm_tile_save_data()
	var chest_data: Array = []
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("get_chest_save_data"):
		chest_data = GameManager.farm_scene.get_chest_save_data()
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	var payload: Dictionary = {
		"day": TimeManager.day,
		"time_minutes": TimeManager.current_time_minutes,
		"gold": CurrencyManager.gold,
		"wish_stone": CurrencyManager.wish_stone,
		"inventory": InventoryManager.get_all_items(),
		"inventory_slots": InventoryManager.get_slots(),
		"hotbar_slots": hotbar_manager.get_slots(),
		"hired_characters": RecruitmentManager.get_hired_character_ids(),
		"farm_tiles": farm_data,
		"farm_chests": chest_data
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("保存管理器：打开存档文件失败。")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	print("保存管理器：游戏已保存到 %s" % SAVE_PATH)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("保存管理器：存档文件不存在。")
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("保存管理器：读取存档文件失败。")
		return
	var raw_text: String = file.get_as_text()
	var parser: JSON = JSON.new()
	var result: int = parser.parse(raw_text)
	if result != OK:
		push_error("保存管理器：解析存档文件失败。")
		return
	var payload: Dictionary = parser.data
	var hotbar_manager: Node = get_node("/root/HotbarManager")
	TimeManager.set_day(int(payload.get("day", 1)))
	TimeManager.set_time_minutes(int(payload.get("time_minutes", TimeManager.START_TIME_MINUTES)))
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
	if hotbar_manager.has_method("ensure_item_present"):
		hotbar_manager.ensure_item_present("axe", 1)
	RecruitmentManager.set_hired_character_ids(payload.get("hired_characters", []))
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("load_farm_tile_save_data"):
		GameManager.farm_scene.load_farm_tile_save_data(payload.get("farm_tiles", []))
	if GameManager.farm_scene != null and GameManager.farm_scene.has_method("load_chest_save_data"):
		GameManager.farm_scene.load_chest_save_data(payload.get("farm_chests", []))
	print("保存管理器：游戏已从 %s 读取。" % SAVE_PATH)
