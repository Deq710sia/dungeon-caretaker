extends Node
## Juice V6 — screen shake, hit-stop, particles, ghost trail.
## Shake offset is snapped to integers to prevent sub-pixel jitter.
## Ghost trail: fading afterimages at previous positions, drawn back-to-front.

var trauma: float = 0.0
var hit_stop_timer: float = 0.0
var particles: Array = []
var shake_amount: float = 0.0

# Ghost trail — DESIGN_PLAN 1A "faint ghost trail: 3-4 fading afterimages
# at 0.3s intervals, drawn as semi-transparent ghost sprites at previous
# positions." Each phase that has a ghost calls trail_sample(pos, modulate)
# every frame; the trail system stores the last N samples at fixed interval.
const TRAIL_MAX_SAMPLES: int = 4
const TRAIL_INTERVAL: float = 0.07  # seconds between samples
const TRAIL_LIFETIME: float = 0.28  # total trail duration
var _trail_samples: Array = []  # [{pos, modulate, age}]
var _trail_timer: float = 0.0
# Trail tint — set per-phase (default ghost blue). draw_texture_rect is
# used by phases to draw the ghost; here we only record positions, the
# phase draws the trail using its own ghost sprite. See trail_draw().
var trail_tint: Color = Color(0.55, 0.75, 0.95, 0.5)
# When the ghost is phasing, the trail tints bluer and draws longer —
# set by phases when phase_active changes. Defaults to false.
var trail_phasing: bool = false

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
	# Trail aging — age out old samples whether or not new ones are added.
	for s in _trail_samples:
		s.age += delta
	_trail_samples = _trail_samples.filter(func(s): return s.age < TRAIL_LIFETIME)
	_trail_timer += delta

func trail_sample(pos: Vector2, modulate: Color = Color(1, 1, 1, 1)) -> void:
	# Called by walkable phases every frame. Records a sample at TRAIL_INTERVAL.
	# Phasing ghosts sample faster (denser trail) for a stronger effect.
	var interval := TRAIL_INTERVAL * (0.5 if trail_phasing else 1.0)
	if _trail_timer < interval:
		return
	_trail_timer = 0.0
	_trail_samples.append({"pos": Vector2(int(pos.x), int(pos.y)), "modulate": modulate, "age": 0.0})
	if _trail_samples.size() > TRAIL_MAX_SAMPLES * (2 if trail_phasing else 1):
		_trail_samples.pop_front()

func trail_clear() -> void:
	_trail_samples.clear()
	_trail_timer = 0.0

func trail_draw(canvas: CanvasItem, ghost_tex: Texture2D, base_size: int = 16) -> void:
	# Draws the trail back-to-front so the oldest sample is most faded.
	# Each sample's alpha is its age-relative-to-lifetime inverted.
	# Phasing samples tint bluer per DESIGN_PLAN 1B.
	for s in _trail_samples:
		var life_pct: float = 1.0 - (s.age / TRAIL_LIFETIME)
		var alpha: float = life_pct * (0.6 if trail_phasing else 0.4)
		var tint: Color = trail_tint if trail_phasing else s.modulate
		var c := Color(tint.r, tint.g, tint.b, alpha)
		var sz := int(base_size * (0.8 + life_pct * 0.2))
		canvas.draw_texture_rect(ghost_tex, Rect2(s.pos.x - sz / 2.0, s.pos.y - sz / 2.0, sz, sz), false, c)

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
