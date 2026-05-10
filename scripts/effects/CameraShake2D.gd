extends Camera2D


var _base_offset: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0


func _ready() -> void:
	_base_offset = offset


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var ratio := _shake_time / maxf(_shake_duration, 0.001)
		offset = _base_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * ratio
	else:
		offset = offset.lerp(_base_offset, minf(delta * 12.0, 1.0))


func shake(strength: float = 5.0, duration: float = 0.14) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = duration
	_shake_time = duration
