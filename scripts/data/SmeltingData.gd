extends Node

const RECIPES_DATA_PATH := "res://data/smelting_recipes.json"

var _recipes: Dictionary = {}


func _ready() -> void:
	_load_data()


func get_recipe(recipe_id: String) -> Dictionary:
	return _recipes.get(recipe_id, {}).duplicate(true)


func get_all_recipes() -> Dictionary:
	return _recipes.duplicate(true)


func recipe_exists(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)


func can_smelt(recipe_id: String) -> bool:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id_variant in ingredients.keys():
		var item_id: String = String(item_id_variant)
		var required_amount: int = int(ingredients[item_id_variant])
		if _get_total_item_count(item_id) < required_amount:
			return false
	return true


func consume_ingredients(recipe_id: String) -> bool:
	if not can_smelt(recipe_id):
		return false
	var recipe: Dictionary = get_recipe(recipe_id)
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id_variant in ingredients.keys():
		var item_id: String = String(item_id_variant)
		var required_amount: int = int(ingredients[item_id_variant])
		if not _remove_item(item_id, required_amount):
			return false
	return true


func _get_total_item_count(item_id: String) -> int:
	var total: int = InventoryManager.get_item_count(item_id)
	var hotbar_manager: Node = get_node_or_null("/root/HotbarManager")
	if hotbar_manager == null:
		return total
	for index in range(int(hotbar_manager.get_slot_count())):
		var slot_data: Dictionary = hotbar_manager.get_slot(index)
		if String(slot_data.get("item_id", "")) == item_id:
			total += int(slot_data.get("amount", 0))
	return total


func _remove_item(item_id: String, amount: int) -> bool:
	var remaining: int = amount
	var inventory_amount: int = mini(InventoryManager.get_item_count(item_id), remaining)
	if inventory_amount > 0:
		if not InventoryManager.remove_item(item_id, inventory_amount):
			return false
		remaining -= inventory_amount
	if remaining <= 0:
		return true
	var hotbar_manager: Node = get_node_or_null("/root/HotbarManager")
	if hotbar_manager == null or not hotbar_manager.has_method("remove_item"):
		return false
	return bool(hotbar_manager.remove_item(item_id, remaining))


func _load_data() -> void:
	if not FileAccess.file_exists(RECIPES_DATA_PATH):
		push_error("SmeltingData: recipes file not found.")
		return
	var file: FileAccess = FileAccess.open(RECIPES_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("SmeltingData: failed to open recipes file.")
		return
	var parser := JSON.new()
	var result: int = parser.parse(file.get_as_text())
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("SmeltingData: failed to parse recipes file.")
		return
	_recipes = parser.data
