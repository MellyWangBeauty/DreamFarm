extends Node

signal inventory_changed(items: Dictionary)

var _items: Dictionary = {}


func add_item(item_id: String, amount: int) -> void:
	if item_id.strip_edges().is_empty():
		push_warning("InventoryManager.add_item: item_id is empty.")
		return
	if amount <= 0:
		push_warning("InventoryManager.add_item: amount must be greater than zero.")
		return
	_items[item_id] = get_item_count(item_id) + amount
	inventory_changed.emit(get_all_items())


func remove_item(item_id: String, amount: int) -> bool:
	if item_id.strip_edges().is_empty():
		push_warning("InventoryManager.remove_item: item_id is empty.")
		return false
	if amount <= 0:
		push_warning("InventoryManager.remove_item: amount must be greater than zero.")
		return false
	var current_amount := get_item_count(item_id)
	if current_amount < amount:
		return false
	var new_amount := current_amount - amount
	if new_amount == 0:
		_items.erase(item_id)
	else:
		_items[item_id] = new_amount
	inventory_changed.emit(get_all_items())
	return true


func get_item_count(item_id: String) -> int:
	return int(_items.get(item_id, 0))


func get_all_items() -> Dictionary:
	return _items.duplicate(true)


func set_all_items(items: Dictionary) -> void:
	_items = items.duplicate(true)
	inventory_changed.emit(get_all_items())
