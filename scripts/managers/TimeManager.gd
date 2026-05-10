extends Node

signal day_started(day: int)
signal day_advanced(day: int)
signal day_progress_changed(progress: float)


var day: int = 1
var _registered_tiles: Array = []
var day_length_seconds: float = 12.0
var _day_elapsed: float = 0.0


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
	_day_elapsed = 0.0
	day_progress_changed.emit(0.0)
	day_advanced.emit(day)


func _process(delta: float) -> void:
	_day_elapsed += delta
	if _day_elapsed >= day_length_seconds:
		_day_elapsed = 0.0
		next_day()
	else:
		day_progress_changed.emit(_day_elapsed / day_length_seconds)


func next_day() -> void:
	_registered_tiles = get_tiles()
	for tile in _registered_tiles:
		tile.advance_day()
	day += 1
	_day_elapsed = 0.0
	for tile in _registered_tiles:
		tile.reset_daily_state()
	print("TimeManager: day %d" % day)
	day_started.emit(day)
	day_progress_changed.emit(0.0)
	day_advanced.emit(day)
