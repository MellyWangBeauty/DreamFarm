extends Node

signal inventory_changed(items: Dictionary)
signal inventory_slots_changed

const SLOT_COUNT := 40

var _slots: Array[Dictionary] = []


func _ready() -> void:
	_reset_slots()


func add_item(item_id: String, amount: int) -> void:
	if item_id.strip_edges().is_empty():
		push_warning("背包管理器：物品 ID 不能为空。")
		return
	if amount <= 0:
		push_warning("背包管理器：添加数量必须大于 0。")
		return
	var remaining: int = amount
	for index in range(_slots.size()):
		var slot_data: Dictionary = _slots[index]
		if String(slot_data.get("item_id", "")) == item_id:
			slot_data["amount"] = int(slot_data.get("amount", 0)) + remaining
			_slots[index] = slot_data
			remaining = 0
			break
	if remaining > 0:
		var empty_index: int = find_first_empty_slot()
		if empty_index == -1:
			push_warning("背包管理器：背包已满。")
			return
		_slots[empty_index] = _make_slot_data(item_id, remaining)
	_emit_changed()


func add_item_prefer_hotbar(item_id: String, amount: int) -> void:
	if item_id.strip_edges().is_empty():
		push_warning("背包管理器：物品 ID 不能为空。")
		return
	if amount <= 0:
		push_warning("背包管理器：添加数量必须大于 0。")
		return
	var remaining: int = amount
	var hotbar_manager: Node = get_node_or_null("/root/HotbarManager")
	if hotbar_manager != null and hotbar_manager.has_method("add_item"):
		remaining = int(hotbar_manager.add_item(item_id, amount))
	if remaining > 0:
		add_item(item_id, remaining)


func remove_item(item_id: String, amount: int) -> bool:
	if item_id.strip_edges().is_empty():
		push_warning("背包管理器：物品 ID 不能为空。")
		return false
	if amount <= 0:
		push_warning("背包管理器：移除数量必须大于 0。")
		return false
	var current_amount: int = get_item_count(item_id)
	if current_amount < amount:
		return false
	var remaining: int = amount
	for index in range(_slots.size()):
		if remaining <= 0:
			break
		var slot_data: Dictionary = _slots[index]
		if String(slot_data.get("item_id", "")) != item_id:
			continue
		var slot_amount: int = int(slot_data.get("amount", 0))
		var take_amount: int = mini(slot_amount, remaining)
		slot_amount -= take_amount
		remaining -= take_amount
		if slot_amount <= 0:
			_slots[index] = _make_empty_slot()
		else:
			slot_data["amount"] = slot_amount
			_slots[index] = slot_data
	_emit_changed()
	return true


func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot_data in _slots:
		if String(slot_data.get("item_id", "")) == item_id:
			total += int(slot_data.get("amount", 0))
	return total


func get_all_items() -> Dictionary:
	var items: Dictionary = {}
	for slot_data in _slots:
		var item_id: String = String(slot_data.get("item_id", ""))
		if item_id.is_empty():
			continue
		items[item_id] = int(items.get(item_id, 0)) + int(slot_data.get("amount", 0))
	return items


func set_all_items(items: Dictionary) -> void:
	_reset_slots()
	for item_id_variant in items.keys():
		var item_id: String = String(item_id_variant)
		var amount: int = int(items.get(item_id_variant, 0))
		if amount > 0:
			add_item(item_id, amount)
	_emit_changed()


func get_slot_count() -> int:
	return SLOT_COUNT


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return _make_empty_slot()
	return _slots[index].duplicate(true)


func set_slot(index: int, slot_data: Dictionary) -> void:
	if not _is_valid_slot_index(index):
		return
	_slots[index] = _normalize_slot(slot_data)
	_emit_changed()


func swap_slots(index_a: int, index_b: int) -> void:
	if not _is_valid_slot_index(index_a) or not _is_valid_slot_index(index_b):
		return
	var temp: Dictionary = _slots[index_a]
	_slots[index_a] = _slots[index_b]
	_slots[index_b] = temp
	_emit_changed()


func swap_with_external_slot(inventory_index: int, external_slot_data: Dictionary, callback: Callable) -> void:
	if not _is_valid_slot_index(inventory_index):
		return
	var original_slot: Dictionary = _slots[inventory_index]
	_slots[inventory_index] = _normalize_slot(external_slot_data)
	_emit_changed()
	if callback.is_valid():
		callback.call(original_slot)


func find_first_empty_slot() -> int:
	for index in range(_slots.size()):
		if String(_slots[index].get("item_id", "")).is_empty():
			return index
	return -1


func get_slots() -> Array:
	var result: Array = []
	for slot_data in _slots:
		result.append(slot_data.duplicate(true))
	return result


func set_slots(slots: Array) -> void:
	_reset_slots()
	for index in range(mini(slots.size(), SLOT_COUNT)):
		var slot_data: Dictionary = slots[index]
		_slots[index] = _normalize_slot(slot_data)
	_emit_changed()


func can_place_item_in_slot(_index: int, _slot_data: Dictionary) -> bool:
	return true


func _emit_changed() -> void:
	inventory_slots_changed.emit()
	inventory_changed.emit(get_all_items())


func _reset_slots() -> void:
	_slots.clear()
	for _index in range(SLOT_COUNT):
		_slots.append(_make_empty_slot())


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


func _normalize_slot(slot_data: Dictionary) -> Dictionary:
	var item_id: String = String(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return _make_empty_slot()
	return _make_slot_data(item_id, amount)


func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()
