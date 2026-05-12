extends Node

signal day_started(day: int)
signal day_advanced(day: int)
signal day_progress_changed(progress: float)
signal time_changed(day: int, hour: int, minute: int)

const START_TIME_MINUTES: int = 6 * 60
const END_TIME_MINUTES: int = 26 * 60
const MINUTES_PER_TICK: int = 10

var day: int = 1
var _registered_tiles: Array = []
var seconds_per_time_tick: float = 7.3
var current_time_minutes: int = START_TIME_MINUTES
var _tick_elapsed: float = 0.0


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
	current_time_minutes = START_TIME_MINUTES
	_tick_elapsed = 0.0
	_emit_time_signals()
	day_advanced.emit(day)


func set_time_minutes(value: int) -> void:
	current_time_minutes = clampi(value, START_TIME_MINUTES, END_TIME_MINUTES - MINUTES_PER_TICK)
	_tick_elapsed = 0.0
	_emit_time_signals()


func get_display_hour() -> int:
	return int((current_time_minutes % (24 * 60)) / 60)


func get_display_minute() -> int:
	return int(current_time_minutes % 60)


func get_day_progress() -> float:
	var elapsed_minutes: float = float(current_time_minutes - START_TIME_MINUTES)
	var total_day_minutes: float = float(END_TIME_MINUTES - START_TIME_MINUTES)
	var partial_tick: float = clampf(_tick_elapsed / seconds_per_time_tick, 0.0, 1.0) * float(MINUTES_PER_TICK)
	return clampf((elapsed_minutes + partial_tick) / total_day_minutes, 0.0, 1.0)


func get_minutes_per_day() -> int:
	return END_TIME_MINUTES - START_TIME_MINUTES


func _process(delta: float) -> void:
	_tick_elapsed += delta
	while _tick_elapsed >= seconds_per_time_tick:
		_tick_elapsed -= seconds_per_time_tick
		_advance_clock_tick()
	_emit_time_signals()


func next_day() -> void:
	_registered_tiles = get_tiles()
	day += 1
	current_time_minutes = START_TIME_MINUTES
	_tick_elapsed = 0.0
	for tile in _registered_tiles:
		tile.reset_daily_state()
	print("TimeManager: day %d" % day)
	day_started.emit(day)
	_emit_time_signals()
	day_advanced.emit(day)


func _advance_clock_tick() -> void:
	_registered_tiles = get_tiles()
	for tile in _registered_tiles:
		if tile.has_method("advance_time"):
			tile.advance_time(MINUTES_PER_TICK)
	var next_time_minutes: int = current_time_minutes + MINUTES_PER_TICK
	if next_time_minutes >= END_TIME_MINUTES:
		next_day()
		return
	current_time_minutes = next_time_minutes


func _emit_time_signals() -> void:
	day_progress_changed.emit(get_day_progress())
	time_changed.emit(day, get_display_hour(), get_display_minute())
