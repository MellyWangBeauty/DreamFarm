extends Node


const CHARACTERS_DATA_PATH := "res://data/characters.json"

var _characters: Dictionary = {}
var _hired_characters: Dictionary = {}


func _ready() -> void:
	_load_data()


func list_available_characters() -> Array:
	var available: Array = []
	for character_id in _characters.keys():
		if not _hired_characters.get(character_id, false):
			available.append(_characters[character_id].duplicate(true))
	return available


func get_character(character_id: String) -> Dictionary:
	return _characters.get(character_id, {}).duplicate(true)


func can_afford(character_id: String) -> bool:
	if not _characters.has(character_id):
		return false
	var character_data: Dictionary = _characters[character_id]
	return CurrencyManager.wish_stone >= int(character_data.get("hire_cost_wish_stone", 0))


func hire_character(character_id: String, spawn_position: Vector2 = Vector2.INF) -> bool:
	if not _characters.has(character_id):
		push_warning("RecruitmentManager: unknown character '%s'." % character_id)
		return false
	if _hired_characters.get(character_id, false):
		return false
	var character_data: Dictionary = _characters[character_id]
	var hire_cost := int(character_data.get("hire_cost_wish_stone", 0))
	if not CurrencyManager.spend_wish_stone(hire_cost):
		return false
	_hired_characters[character_id] = true
	_assign_hired_assistant(character_id, spawn_position)
	return true


func get_hired_character_ids() -> Array:
	return _hired_characters.keys()


func set_hired_character_ids(character_ids: Array) -> void:
	_hired_characters.clear()
	for character_id_variant in character_ids:
		var character_id := String(character_id_variant)
		_hired_characters[character_id] = true
	_assign_all_hired_assistants()


func is_hired(character_id: String) -> bool:
	return bool(_hired_characters.get(character_id, false))


func _assign_all_hired_assistants() -> void:
	for character_id in _hired_characters.keys():
		_assign_hired_assistant(String(character_id))


func _assign_hired_assistant(character_id: String, spawn_position: Vector2 = Vector2.INF) -> void:
	if GameManager.farm_scene == null:
		return
	if GameManager.farm_scene.has_method("ensure_assistant_node"):
		GameManager.farm_scene.ensure_assistant_node(character_id, spawn_position)


func _load_data() -> void:
	if not FileAccess.file_exists(CHARACTERS_DATA_PATH):
		push_error("RecruitmentManager: characters.json not found.")
		return
	var file := FileAccess.open(CHARACTERS_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("RecruitmentManager: failed to open characters.json.")
		return
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("RecruitmentManager: failed to parse characters.json.")
		return
	_characters = parser.data
