extends Node

const MINING_DATA_PATH := "res://data/mining_nodes.json"

var _nodes: Dictionary = {}


func _ready() -> void:
	_load_data()


func get_node_data(node_id: String) -> Dictionary:
	return _nodes.get(node_id, {}).duplicate(true)


func node_exists(node_id: String) -> bool:
	return _nodes.has(node_id)


func get_default_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_id_variant in _nodes.keys():
		var node_id: String = String(node_id_variant)
		var node_data: Dictionary = get_node_data(node_id)
		var positions: Array = node_data.get("default_positions", [])
		for position_variant in positions:
			var position_data: Dictionary = position_variant
			result.append({
				"node_id": node_id,
				"grid_x": int(position_data.get("grid_x", 0)),
				"grid_y": int(position_data.get("grid_y", 0))
			})
	return result


func roll_drop_amount(node_id: String) -> int:
	var node_data: Dictionary = get_node_data(node_id)
	var drop_min: int = int(node_data.get("drop_min", 1))
	var drop_max: int = int(node_data.get("drop_max", drop_min))
	return randi_range(mini(drop_min, drop_max), maxi(drop_min, drop_max))


func _load_data() -> void:
	if not FileAccess.file_exists(MINING_DATA_PATH):
		push_error("MiningData: mining_nodes.json not found.")
		return
	var file: FileAccess = FileAccess.open(MINING_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MiningData: failed to open mining_nodes.json.")
		return
	var parser := JSON.new()
	var result: int = parser.parse(file.get_as_text())
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("MiningData: failed to parse mining_nodes.json.")
		return
	_nodes = parser.data
