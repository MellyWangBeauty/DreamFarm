extends Node

signal hotbar_changed
signal selected_slot_changed(index: int, item_id: String)

const SLOT_COUNT := 10

var selected_index: int = 0
var _slots: Array[Dictionary] = []


func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	_slots.clear()
	for item_id in ItemDatabase.get_default_hotbar():
		_slots.append(_make_slot_data(item_id, 1 if not String(item_id).is_empty() else 0))
	selected_index = 0
	hotbar_changed.emit()
	selected_slot_changed.emit(selected_index, get_selected_item_id())


func get_slot_count() -> int:
	return SLOT_COUNT


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return _make_empty_slot()
	return _slots[index].duplicate(true)


func get_slots() -> Array:
	var slots: Array = []
	for slot_data in _slots:
		slots.append(slot_data.duplicate(true))
	return slots


func set_slots(slots: Array) -> void:
	_slots.clear()
	for index in range(SLOT_COUNT):
		if index < slots.size():
			var slot_data: Dictionary = slots[index]
			_slots.append(_normalize_slot(slot_data))
		else:
			_slots.append(_make_empty_slot())
	selected_index = clampi(selected_index, 0, SLOT_COUNT - 1)
	hotbar_changed.emit()
	selected_slot_changed.emit(selected_index, get_selected_item_id())


func set_slot(index: int, slot_data: Dictionary) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = _normalize_slot(slot_data)
	hotbar_changed.emit()
	if index == selected_index:
		selected_slot_changed.emit(selected_index, get_selected_item_id())


func swap_slots(index_a: int, index_b: int) -> void:
	if not _is_valid_index(index_a) or not _is_valid_index(index_b):
		return
	var temp: Dictionary = _slots[index_a]
	_slots[index_a] = _slots[index_b]
	_slots[index_b] = temp
	hotbar_changed.emit()
	selected_slot_changed.emit(selected_index, get_selected_item_id())


func move_or_swap_with_inventory(hotbar_index: int, inventory_index: int) -> void:
	if not _is_valid_index(hotbar_index):
		return
	InventoryManager.swap_with_external_slot(inventory_index, get_slot(hotbar_index), Callable(self, "_receive_inventory_swap").bind(hotbar_index))


func set_selected_index(index: int) -> void:
	selected_index = clampi(index, 0, SLOT_COUNT - 1)
	selected_slot_changed.emit(selected_index, get_selected_item_id())


func get_selected_item_id() -> String:
	return String(get_slot(selected_index).get("item_id", ""))


func add_item(item_id: String, amount: int) -> int:
	if item_id.strip_edges().is_empty() or amount <= 0:
		return amount
	var remaining: int = amount
	if ItemDatabase.is_stackable(item_id):
		for index in range(_slots.size()):
			var slot_data: Dictionary = _slots[index]
			if String(slot_data.get("item_id", "")) != item_id:
				continue
			slot_data["amount"] = int(slot_data.get("amount", 0)) + remaining
			_slots[index] = slot_data
			remaining = 0
			break
	if remaining > 0:
		for index in range(_slots.size()):
			var slot_data: Dictionary = _slots[index]
			if not String(slot_data.get("item_id", "")).is_empty():
				continue
			_slots[index] = _make_slot_data(item_id, remaining)
			remaining = 0
			break
	if remaining != amount:
		hotbar_changed.emit()
		selected_slot_changed.emit(selected_index, get_selected_item_id())
	return remaining


func remove_from_slot(index: int, amount: int) -> bool:
	if not _is_valid_index(index) or amount <= 0:
		return false
	var slot_data: Dictionary = _slots[index]
	var slot_amount: int = int(slot_data.get("amount", 0))
	if slot_amount < amount:
		return false
	slot_amount -= amount
	if slot_amount <= 0:
		_slots[index] = _make_empty_slot()
	else:
		slot_data["amount"] = slot_amount
		_slots[index] = slot_data
	hotbar_changed.emit()
	if index == selected_index:
		selected_slot_changed.emit(selected_index, get_selected_item_id())
	return true


func _receive_inventory_swap(new_slot_data: Dictionary, hotbar_index: int) -> void:
	set_slot(hotbar_index, new_slot_data)


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func _normalize_slot(slot_data: Dictionary) -> Dictionary:
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return _make_empty_slot()
	return _make_slot_data(item_id, amount)


func _make_empty_slot() -> Dictionary:
	return {
		"item_id": "",
		"amount": 0
	}


func _make_slot_data(item_id: String, amount: int) -> Dictionary:
	return {
		"item_id": item_id,
		"amount": max(amount, 0)
	}
