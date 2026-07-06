extends Node
## Juice V6 — screen shake, hit-stop, particles.
## Shake offset is snapped to integers to prevent sub-pixel jitter.

var trauma: float = 0.0
var hit_stop_timer: float = 0.0
var particles: Array = []
var shake_amount: float = 0.0

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func hit_stop(duration: float) -> void:
	hit_stop_timer = max(hit_stop_timer, duration)

func is_hit_stopped() -> bool:
	return hit_stop_timer > 0

func _process(delta: float) -> void:
	if hit_stop_timer > 0:
		hit_stop_timer -= delta
		return
	trauma = maxf(0.0, trauma - delta * 1.5)
	shake_amount = trauma * trauma

func get_shake_offset() -> Vector2:
	if shake_amount <= 0:
		return Vector2.ZERO
	var angle := randf() * TAU
	var dist := shake_amount * 5.0
	var offset := Vector2(cos(angle), sin(angle)) * dist
	# Snap to integers — sub-pixel shake causes jitter at 320x180
	return Vector2(int(offset.x), int(offset.y))

func spawn_particles(pos: Vector2, count: int, color: Color, speed: float = 40.0, life: float = 0.4, direction: Vector2 = Vector2.ZERO) -> void:
	for i in count:
		var angle: float
		if direction != Vector2.ZERO:
			angle = direction.angle() + randf_range(-PI / 3, PI / 3)
		else:
			angle = randf() * TAU
		var vel := Vector2(cos(angle), sin(angle)) * speed * randf_range(0.5, 1.0)
		particles.append({
			"pos": pos,
			"vel": vel,
			"color": color,
			"life": life * randf_range(0.7, 1.0),
			"max_life": life,
			"size": randf_range(1, 2),
		})

func update_particles(delta: float) -> void:
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= 0.92
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)

func draw_particles(canvas: CanvasItem) -> void:
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		var s := int(ceil(p.size))
		# Snap particle positions to integers
		canvas.draw_rect(Rect2(int(p.pos.x) - s, int(p.pos.y) - s, s * 2, s * 2), c, true)

func clear_particles() -> void:
	particles.clear()
