extends Node2D


const FLOATING_TEXT_SCRIPT := preload("res://scripts/effects/FloatingText.gd")
const BURST_EFFECT_SCRIPT := preload("res://scripts/effects/BurstEffect.gd")
const INTERACT_SFX := preload("res://assets/placeholder/audio/interact.wav")
const WATER_SFX := preload("res://assets/placeholder/audio/water.wav")
const HARVEST_SFX := preload("res://assets/placeholder/audio/harvest.wav")
const COIN_SFX := preload("res://assets/placeholder/audio/coin.wav")
const PICKUP_SFX := preload("res://assets/placeholder/audio/pickup.wav")
const UI_CLICK_SFX := preload("res://assets/placeholder/audio/ui_click.wav")

var _sfx_players: Dictionary = {}


func _ready() -> void:
	_ensure_audio_players()


func play_interact() -> void:
	_play_sfx("interact")


func play_water() -> void:
	_play_sfx("water")


func play_harvest() -> void:
	_play_sfx("harvest")


func play_coin() -> void:
	_play_sfx("coin")


func play_pickup() -> void:
	_play_sfx("pickup")


func play_ui_click() -> void:
	_play_sfx("ui_click")


func show_text(text: String, color: Color, world_position: Vector2) -> void:
	var text_node: Node2D = Node2D.new()
	text_node.set_script(FLOATING_TEXT_SCRIPT)
	add_child(text_node)
	text_node.setup(text, color, world_position)


func show_burst(world_position: Vector2, color: Color, amount: int, speed: float) -> void:
	var burst_node: Node2D = Node2D.new()
	burst_node.set_script(BURST_EFFECT_SCRIPT)
	add_child(burst_node)
	burst_node.setup(color, world_position, amount, speed)


func show_water_feedback(world_position: Vector2) -> void:
	show_burst(world_position, Color(0.49, 0.82, 1.0), 9, 34.0)


func show_harvest_feedback(world_position: Vector2) -> void:
	show_burst(world_position, Color(1.0, 0.84, 0.35), 12, 46.0)


func show_pickup_feedback(item_name: String, amount: int, world_position: Vector2) -> void:
	play_pickup()
	show_text("+%s x%d" % [item_name, amount], Color(0.90, 1.0, 0.76), world_position + Vector2(0, -16))
	show_burst(world_position, Color(0.92, 1.0, 0.78), 8, 28.0)


func show_gold_feedback(amount: int, world_position: Vector2) -> void:
	play_coin()
	show_text("+%d 金币" % amount, Color(1.0, 0.88, 0.35), world_position)


func show_hire_feedback(character_name: String, world_position: Vector2) -> void:
	play_interact()
	show_text("+%s" % character_name, Color(0.51, 0.92, 1.0), world_position)


func _ensure_audio_players() -> void:
	_sfx_players["interact"] = _make_sfx_player("InteractSfx", INTERACT_SFX)
	_sfx_players["water"] = _make_sfx_player("WaterSfx", WATER_SFX)
	_sfx_players["harvest"] = _make_sfx_player("HarvestSfx", HARVEST_SFX)
	_sfx_players["coin"] = _make_sfx_player("CoinSfx", COIN_SFX)
	_sfx_players["pickup"] = _make_sfx_player("PickupSfx", PICKUP_SFX)
	_sfx_players["ui_click"] = _make_sfx_player("UiClickSfx", UI_CLICK_SFX)


func _make_sfx_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player_node: AudioStreamPlayer = AudioStreamPlayer.new()
	player_node.name = player_name
	player_node.stream = stream
	add_child(player_node)
	return player_node


func _play_sfx(sound_name: String) -> void:
	var player_node: Variant = _sfx_players.get(sound_name, null)
	if player_node != null:
		player_node.play()
