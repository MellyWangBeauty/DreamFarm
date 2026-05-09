extends Node


var farm_scene: Node = null
var assistants: Array = []


func _ready() -> void:
	_grant_starting_resources()


func register_farm_scene(scene: Node) -> void:
	farm_scene = scene


func unregister_farm_scene(scene: Node) -> void:
	if farm_scene == scene:
		farm_scene = null


func register_assistant(assistant: Node) -> void:
	if assistant == null:
		return
	if assistants.has(assistant):
		return
	assistants.append(assistant)


func get_hired_assistants() -> Array:
	return assistants.filter(func(entry: Node) -> bool: return is_instance_valid(entry) and entry.hired)


func _grant_starting_resources() -> void:
	var should_grant := CurrencyManager.wish_stone <= 0
	should_grant = should_grant and CurrencyManager.gold == 0
	should_grant = should_grant and InventoryManager.get_all_items().is_empty()
	should_grant = should_grant and RecruitmentManager.get_hired_character_ids().is_empty()
	if should_grant:
		CurrencyManager.add_wish_stone(100)
		print("GameManager: granted 100 wish stones for MVP testing.")

