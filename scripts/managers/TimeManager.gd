extends Node

signal day_started(day: int)
signal day_advanced(day: int)


var day: int = 1
var _registered_tiles: Array = []


func register_tile(tile: Node) -> void:
	if tile == null:
		return
	if _registered_tiles.has(tile):
		return
	_registered_tiles.append(tile)


func unregister_tile(tile: Node) -> void:
	_registered_tiles.erase(tile)


func get_tiles() -> Array:
	return _registered_tiles.filter(func(tile: Node) -> bool: return is_instance_valid(tile))


func set_day(value: int) -> void:
	day = max(value, 1)
	day_advanced.emit(day)


func next_day() -> void:
	_registered_tiles = get_tiles()
	day += 1
	for tile in _registered_tiles:
		tile.reset_daily_state()
	day_started.emit(day)
	for tile in _registered_tiles:
		tile.advance_day()
	print("TimeManager: day %d" % day)
	day_advanced.emit(day)
