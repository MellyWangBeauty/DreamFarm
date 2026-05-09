extends Node2D


var particle_color: Color = Color.WHITE
var particles: Array[Dictionary] = []
var lifetime: float = 0.45
var elapsed: float = 0.0


func setup(color: Color, world_position: Vector2, burst_count: int, speed: float) -> void:
	particle_color = color
	global_position = world_position
	particles.clear()
	for index in range(burst_count):
		var angle := (TAU * float(index) / float(max(1, burst_count))) + randf() * 0.45
		var direction := Vector2(cos(angle), sin(angle))
		particles.append({
			"position": Vector2.ZERO,
			"velocity": direction * (speed * randf_range(0.6, 1.1)),
			"radius": randf_range(2.0, 4.5)
		})
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	for particle_variant in particles:
		var particle: Dictionary = particle_variant
		particle["position"] = particle["position"] + particle["velocity"] * delta
		particle["velocity"] = particle["velocity"] + Vector2(0, 60) * delta
	if elapsed >= lifetime:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var alpha := clampf(1.0 - (elapsed / lifetime), 0.0, 1.0)
	for particle_variant in particles:
		var particle: Dictionary = particle_variant
		var color := Color(particle_color.r, particle_color.g, particle_color.b, alpha)
		draw_circle(particle["position"], particle["radius"], color)

