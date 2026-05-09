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

