extends Node


const CROPS_DATA_PATH := "res://data/crops.json"

var _crops: Dictionary = {}


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	if not FileAccess.file_exists(CROPS_DATA_PATH):
		push_error("CropData: crops.json not found.")
		return
	var file := FileAccess.open(CROPS_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("CropData: failed to open crops.json.")
		return
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("CropData: failed to parse crops.json.")
		return
	_crops = parser.data


func get_crop(crop_id: String) -> Dictionary:
	return _crops.get(crop_id, {}).duplicate(true)


func get_all_crops() -> Dictionary:
	return _crops.duplicate(true)


func crop_exists(crop_id: String) -> bool:
	return _crops.has(crop_id)


func get_growth_stage_count(crop_id: String) -> int:
	var crop_data: Dictionary = get_crop(crop_id)
	return maxi(int(crop_data.get("growth_stage_count", 4)), 2)


func get_stage_duration_minutes(crop_id: String) -> int:
	var crop_data: Dictionary = get_crop(crop_id)
	var stage_duration_variant: Variant = crop_data.get("stage_duration", null)
	if stage_duration_variant is Dictionary:
		var stage_duration: Dictionary = stage_duration_variant
		var days: int = maxi(int(stage_duration.get("days", 0)), 0)
		var hours: int = maxi(int(stage_duration.get("hours", 0)), 0)
		var minutes: int = maxi(int(stage_duration.get("minutes", 0)), 0)
		var total_minutes: int = days * TimeManager.get_minutes_per_day() + hours * 60 + minutes
		return maxi(total_minutes, 1)
	return maxi(int(crop_data.get("stage_minutes", 10)), 1)
