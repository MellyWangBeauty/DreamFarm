extends Node

signal gold_changed(value: int)
signal wish_stone_changed(value: int)

var gold: int = 0
var wish_stone: int = 0


func add_gold(amount: int) -> void:
	if amount <= 0:
		push_warning("CurrencyManager.add_gold: amount must be greater than zero.")
		return
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		push_warning("CurrencyManager.spend_gold: amount must be greater than zero.")
		return false
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_wish_stone(amount: int) -> void:
	if amount <= 0:
		push_warning("CurrencyManager.add_wish_stone: amount must be greater than zero.")
		return
	wish_stone += amount
	wish_stone_changed.emit(wish_stone)


func spend_wish_stone(amount: int) -> bool:
	if amount <= 0:
		push_warning("CurrencyManager.spend_wish_stone: amount must be greater than zero.")
		return false
	if wish_stone < amount:
		return false
	wish_stone -= amount
	wish_stone_changed.emit(wish_stone)
	return true


func set_gold(value: int) -> void:
	gold = max(value, 0)
	gold_changed.emit(gold)


func set_wish_stone(value: int) -> void:
	wish_stone = max(value, 0)
	wish_stone_changed.emit(wish_stone)
