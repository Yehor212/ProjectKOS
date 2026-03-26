extends Node

## Централізований менеджер VFX — шаблони частинок для всіх ефектів.
## Дублює шаблон-ноду, додає до поточної сцени, запускає, самознищення.

const CLEANUP_MARGIN: float = 0.5

var _active_particles: Array[CPUParticles2D] = []

## ── Precomputed scale curves (allocated once, reused) ──
static var _curve_burst: Curve = null       ## grow→peak→shrink для вибухів
static var _curve_pop: Curve = null         ## pop-in→fade для sparkles
static var _curve_rain: Curve = null        ## slow grow→shrink для дощу
static var _curve_ring: Curve = null        ## expand→fade для кілець


static func _get_burst_curve() -> Curve:
	if _curve_burst:
		return _curve_burst
	_curve_burst = Curve.new()
	_curve_burst.add_point(Vector2(0.0, 0.0))
	_curve_burst.add_point(Vector2(0.08, 1.4))
	_curve_burst.add_point(Vector2(0.25, 1.1))
	_curve_burst.add_point(Vector2(0.6, 0.7))
	_curve_burst.add_point(Vector2(1.0, 0.0))
	return _curve_burst


static func _get_pop_curve() -> Curve:
	if _curve_pop:
		return _curve_pop
	_curve_pop = Curve.new()
	_curve_pop.add_point(Vector2(0.0, 0.2))
	_curve_pop.add_point(Vector2(0.06, 1.3))
	_curve_pop.add_point(Vector2(0.2, 1.0))
	_curve_pop.add_point(Vector2(0.5, 0.6))
	_curve_pop.add_point(Vector2(1.0, 0.0))
	return _curve_pop


static func _get_rain_curve() -> Curve:
	if _curve_rain:
		return _curve_rain
	_curve_rain = Curve.new()
	_curve_rain.add_point(Vector2(0.0, 0.1))
	_curve_rain.add_point(Vector2(0.15, 1.0))
	_curve_rain.add_point(Vector2(0.6, 0.9))
	_curve_rain.add_point(Vector2(0.85, 0.4))
	_curve_rain.add_point(Vector2(1.0, 0.0))
	return _curve_rain


static func _get_ring_curve() -> Curve:
	if _curve_ring:
		return _curve_ring
	_curve_ring = Curve.new()
	_curve_ring.add_point(Vector2(0.0, 0.4))
	_curve_ring.add_point(Vector2(0.1, 1.1))
	_curve_ring.add_point(Vector2(0.4, 0.8))
	_curve_ring.add_point(Vector2(0.75, 0.3))
	_curve_ring.add_point(Vector2(1.0, 0.0))
	return _curve_ring

@onready var _confetti: CPUParticles2D = $ConfettiTemplate
@onready var _tap_stars: CPUParticles2D = $TapStarsTemplate
@onready var _error_smoke: CPUParticles2D = $ErrorSmokeTemplate


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_removed.connect(_on_node_removed)


func _on_node_removed(node: Node) -> void:
	## Очистка при зміні сцени — видаляємо всі активні частинки
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	if node == tree.current_scene:
		_cleanup_all_particles()


func _cleanup_all_particles() -> void:
	for p: CPUParticles2D in _active_particles:
		if is_instance_valid(p):
			p.queue_free()
	_active_particles.clear()


func spawn_confetti(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	_spawn_from_template(_confetti, pos)


func spawn_tap_stars(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	_spawn_from_template(_tap_stars, pos)


func spawn_error_smoke(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	_spawn_from_template(_error_smoke, pos)


func spawn_premium_celebration(pos: Vector2, color: Color = Color("FFD166")) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ багатошарове святкування: confetti + burst + glow halo + gold ring (LAW 28).
	## Шар 1: конфеті дощ від позиції
	_spawn_from_template(_confetti, pos)
	## Шар 2: іскристий burst з текстурою та scale curve
	var tex: Texture2D = null
	var tex_path: String = "res://assets/sprites/particles/star_06.png"
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 1.0
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 100.0
	burst.initial_velocity_max = 200.0
	burst.gravity = Vector2(0, 120)
	burst.angular_velocity_min = -420.0
	burst.angular_velocity_max = 420.0
	burst.scale_amount_min = 0.3
	burst.scale_amount_max = 0.8
	burst.scale_amount_curve = _get_burst_curve()
	if tex:
		burst.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(color, 1.0))
	grad.add_point(0.25, Color(1.0, 1.0, 0.9, 0.95))
	grad.add_point(0.5, Color(color, 0.8))
	grad.add_point(0.75, Color("ef476f", 0.5))
	grad.set_color(1, Color(color, 0.0))
	burst.color_ramp = grad
	_add_to_scene(burst, pos)
	## Шар 3: soft glow halo (flare texture)
	if not is_inside_tree():
		return
	var flare_path: String = "res://assets/sprites/particles/flare_01.png"
	if ResourceLoader.exists(flare_path):
		var flare_tex: Texture2D = load(flare_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 8
		glow.lifetime = 0.7
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 30.0
		glow.initial_velocity_max = 80.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 60.0
		glow.damping_max = 100.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 3.0
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = flare_tex
		var glow_grad: Gradient = Gradient.new()
		glow_grad.set_color(0, Color(color, 0.3))
		glow_grad.add_point(0.25, Color(color.lightened(0.15), 0.2))  ## м'яке ядро
		glow_grad.add_point(0.5, Color(color, 0.1))  ## середнє згасання
		glow_grad.add_point(0.75, Color(color, 0.03))  ## фінальне згасання
		glow_grad.set_color(glow_grad.get_point_count() - 1, Color(color, 0.0))
		glow.color_ramp = glow_grad
		_add_to_scene(glow, pos)
	## Шар 4: золоте кільце — затримка 0.15с
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var ring: CPUParticles2D = CPUParticles2D.new()
		ring.one_shot = true
		ring.explosiveness = 1.0
		ring.amount = 32
		ring.lifetime = 0.7
		ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		ring.emission_sphere_radius = 8.0
		ring.direction = Vector2.ZERO
		ring.spread = 180.0
		ring.initial_velocity_min = 140.0
		ring.initial_velocity_max = 220.0
		ring.gravity = Vector2.ZERO
		ring.damping_min = 100.0
		ring.damping_max = 160.0
		ring.scale_amount_min = 0.4
		ring.scale_amount_max = 0.9
		ring.scale_amount_curve = _get_ring_curve()
		var ring_grad: Gradient = Gradient.new()
		ring_grad.set_color(0, Color(1.0, 1.0, 0.9))
		ring_grad.add_point(0.3, Color("FFD166"))
		ring_grad.add_point(0.65, Color("FFD166", 0.5))
		ring_grad.set_color(1, Color("FFD166", 0.0))
		ring.color_ramp = ring_grad
		_add_to_scene(ring, pos)
	)


func spawn_match_sparkle(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ іскри при збігу пари — sparkle burst + soft circle glow underlayer.
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_01.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.5
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 15.0
		glow.initial_velocity_max = 40.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color("06d6a0", 0.25))
		glow_g.add_point(0.25, Color("80ffdb", 0.18))  ## світле бірюзове ядро
		glow_g.add_point(0.5, Color("06d6a0", 0.1))  ## середнє згасання
		glow_g.add_point(0.75, Color("06d6a0", 0.03))  ## фінальне згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color("06d6a0", 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні іскри
	var tex_path: String = "res://assets/sprites/particles/star_04.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.6
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 70)
	p.angular_velocity_min = -250.0
	p.angular_velocity_max = 250.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.scale_amount_curve = _get_pop_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color("06d6a0"))
	grad.add_point(0.2, Color("80ffdb"))
	grad.add_point(0.5, Color("FFD166"))
	grad.add_point(0.75, Color("06d6a0", 0.5))
	grad.set_color(1, Color("06d6a0", 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_bubble_pop(pos: Vector2, color: Color) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ кольорові бризки при лопанні пузиря — з текстурою та scale curve
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_04.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.6
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 30.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color(color, 0.25))
		glow_g.add_point(0.3, Color(color.lightened(0.15), 0.15))  ## м'яке ядро
		glow_g.add_point(0.6, Color(color, 0.06))  ## згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color(color, 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні частинки
	var tex_path: String = "res://assets/sprites/particles/circle_04.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.6
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.scale_amount_curve = _get_pop_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(color, 0.9))
	grad.add_point(0.2, Color(color.lightened(0.2), 0.75))  ## світліший відтінок
	grad.add_point(0.45, Color(1.0, 0.97, 0.97, 0.55))  ## білий пік свічення
	grad.add_point(0.72, Color(color, 0.2))  ## теплий відхід
	grad.set_color(grad.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_heart_particles(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ рожеві серця при кліку на тварину — з текстурою та scale curve
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_04.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.6
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 30.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color("ff5c8a", 0.25))
		glow_g.add_point(0.3, Color("ff8fab", 0.15))  ## м'яке рожеве ядро
		glow_g.add_point(0.6, Color("ff5c8a", 0.06))  ## згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color("ff5c8a", 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні частинки
	var tex_path: String = "res://assets/sprites/particles/symbol_01.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 12
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 80)
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.scale_amount_curve = _get_burst_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.45, 0.65, 0.9))
	grad.add_point(0.2, Color(1.0, 0.6, 0.78, 0.8))  ## світліший рожевий
	grad.add_point(0.45, Color(1.0, 0.92, 0.94, 0.6))  ## білий пік свічення
	grad.add_point(0.73, Color(1.0, 0.5, 0.68, 0.2))  ## теплий відхід
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.4, 0.6, 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_note_particles(pos: Vector2, color: Color) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ музичні ноти — з текстурою, scale curve та gradient
	var tex_path: String = "res://assets/sprites/particles/symbol_02.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 10
	p.lifetime = 1.0
	p.direction = Vector2.UP
	p.spread = 50.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, -30)
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _get_burst_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(color, 0.9))
	grad.add_point(0.2, Color(color.lightened(0.15), 0.78))  ## світліший відтінок
	grad.add_point(0.45, Color(1.0, 0.97, 0.97, 0.55))  ## білий пік свічення
	grad.add_point(0.73, Color(color, 0.2))  ## теплий відхід
	grad.set_color(grad.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_golden_burst(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ золотий вибух — текстуровані зірки + bokeh underlayer (LAW 28)
	## Підшар: soft light bokeh
	var light_path: String = "res://assets/sprites/particles/light_01.png"
	if ResourceLoader.exists(light_path):
		var light_tex: Texture2D = load(light_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 8
		glow.lifetime = 0.8
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 20.0
		glow.initial_velocity_max = 60.0
		glow.gravity = Vector2(0, -20)
		glow.damping_min = 50.0
		glow.damping_max = 80.0
		glow.scale_amount_min = 2.0
		glow.scale_amount_max = 4.0
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = light_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color(1.0, 0.95, 0.7, 0.3))
		glow_g.add_point(0.25, Color(1.0, 0.97, 0.82, 0.2))  ## тепле світле ядро
		glow_g.add_point(0.5, Color("FFD166", 0.12))  ## золоте згасання
		glow_g.add_point(0.75, Color("FFD166", 0.04))  ## фінальне згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color("FFD166", 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основний burst — зірки з scale curve
	var tex_path: String = "res://assets/sprites/particles/star_06.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 28
	p.lifetime = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 220)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _get_burst_curve()
	if tex:
		p.texture = tex
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.95))
	gradient.add_point(0.15, Color(1.0, 0.95, 0.5))
	gradient.add_point(0.4, Color("FFD166"))
	gradient.add_point(0.7, Color("FFD166", 0.5))
	gradient.set_color(1, Color("FFD166", 0.0))
	p.color_ramp = gradient
	_add_to_scene(p, pos)


func spawn_success_ripple(pos: Vector2, color: Color) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ кільцевий пульс — з circle текстурою та expanding scale curve
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_04.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.6
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 30.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color(color, 0.25))
		glow_g.add_point(0.3, Color(color.lightened(0.15), 0.15))  ## м'яке ядро
		glow_g.add_point(0.6, Color(color, 0.06))  ## згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color(color, 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні частинки
	var tex_path: String = "res://assets/sprites/particles/circle_04.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.6
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.scale_amount_curve = _get_ring_curve()
	if tex:
		p.texture = tex
	p.damping_min = 100.0
	p.damping_max = 200.0
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(color.lightened(0.3), 0.9))
	gradient.add_point(0.2, Color(color, 0.8))
	gradient.add_point(0.6, Color(color, 0.4))
	gradient.set_color(1, Color(color, 0.0))
	p.color_ramp = gradient
	_add_to_scene(p, pos)


func spawn_snap_pulse(pos: Vector2, color: Color = Color.WHITE) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ пульс посадки — soft light texture + scale curve
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_04.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.6
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 30.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color(color, 0.25))
		glow_g.add_point(0.3, Color(color.lightened(0.15), 0.15))  ## м'яке ядро
		glow_g.add_point(0.6, Color(color, 0.06))  ## згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color(color, 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні частинки
	var tex_path: String = "res://assets/sprites/particles/light_03.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.45
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO
	p.damping_min = 140.0
	p.damping_max = 220.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	p.scale_amount_curve = _get_pop_curve()
	if tex:
		p.texture = tex
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(color, 0.7))
	gradient.add_point(0.18, Color(color.lightened(0.15), 0.55))  ## світліший відтінок
	gradient.add_point(0.42, Color(1.0, 0.98, 0.98, 0.4))  ## білий пік свічення
	gradient.add_point(0.72, Color(color, 0.12))  ## теплий відхід
	gradient.set_color(gradient.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = gradient
	_add_to_scene(p, pos)


## ────────────────────────────────────────────────────────────
## УНІКАЛЬНІ ЕФЕКТИ — для level_complete_overlay та main_menu
## ────────────────────────────────────────────────────────────

func spawn_firework_fountain(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ фонтан феєрверків — 3 хвилі + trail texture (LAW 28).
	var tex_path: String = "res://assets/sprites/particles/magic_03.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var trail_tex: Texture2D = null
	var trail_path: String = "res://assets/sprites/particles/trace_01.png"
	if ResourceLoader.exists(trail_path):
		trail_tex = load(trail_path)
	## Хвиля 1 — теплі кольори + scale curve
	var p1: CPUParticles2D = CPUParticles2D.new()
	p1.one_shot = true
	p1.explosiveness = 0.85
	p1.amount = 24
	p1.lifetime = 1.3
	p1.direction = Vector2.UP
	p1.spread = 40.0
	p1.initial_velocity_min = 220.0
	p1.initial_velocity_max = 350.0
	p1.gravity = Vector2(0, 300)
	p1.angular_velocity_min = -200.0
	p1.angular_velocity_max = 200.0
	p1.scale_amount_min = 0.5
	p1.scale_amount_max = 1.3
	p1.scale_amount_curve = _get_burst_curve()
	if tex:
		p1.texture = tex
	var g1: Gradient = Gradient.new()
	g1.set_color(0, Color(1.0, 1.0, 0.9))
	g1.add_point(0.2, Color("FFD166"))
	g1.add_point(0.5, Color("ef476f"))
	g1.add_point(0.75, Color("a78bfa", 0.5))
	g1.set_color(1, Color("ef476f", 0.0))
	p1.color_ramp = g1
	_add_to_scene(p1, pos)
	if not is_inside_tree():
		return
	## Хвиля 2 — холодні кольори, затримка 0.3с
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var p2: CPUParticles2D = CPUParticles2D.new()
		p2.one_shot = true
		p2.explosiveness = 0.85
		p2.amount = 18
		p2.lifetime = 1.1
		p2.direction = Vector2.UP
		p2.spread = 50.0
		p2.initial_velocity_min = 200.0
		p2.initial_velocity_max = 320.0
		p2.gravity = Vector2(0, 340)
		p2.angular_velocity_min = -150.0
		p2.angular_velocity_max = 150.0
		p2.scale_amount_min = 0.4
		p2.scale_amount_max = 1.1
		p2.scale_amount_curve = _get_burst_curve()
		if tex:
			p2.texture = tex
		var g2: Gradient = Gradient.new()
		g2.set_color(0, Color("06d6a0"))
		g2.add_point(0.3, Color("80ffdb"))
		g2.add_point(0.6, Color("118ab2"))
		g2.set_color(1, Color("a78bfa", 0.0))
		p2.color_ramp = g2
		_add_to_scene(p2, pos)
	)
	## Хвиля 3 — trail шлейфи, затримка 0.6с
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var p3: CPUParticles2D = CPUParticles2D.new()
		p3.one_shot = true
		p3.explosiveness = 0.9
		p3.amount = 12
		p3.lifetime = 0.9
		p3.direction = Vector2.UP
		p3.spread = 35.0
		p3.initial_velocity_min = 180.0
		p3.initial_velocity_max = 280.0
		p3.gravity = Vector2(0, 300)
		p3.angular_velocity_min = -90.0
		p3.angular_velocity_max = 90.0
		p3.scale_amount_min = 0.6
		p3.scale_amount_max = 1.4
		p3.scale_amount_curve = _get_rain_curve()
		if trail_tex:
			p3.texture = trail_tex
		var g3: Gradient = Gradient.new()
		g3.set_color(0, Color("a78bfa"))
		g3.add_point(0.2, Color("c4b5fd"))  ## світліший фіолетовий
		g3.add_point(0.45, Color("FFD166"))  ## золотий пік
		g3.add_point(0.72, Color("ef476f", 0.4))  ## теплий рожевий відхід
		g3.set_color(g3.get_point_count() - 1, Color("ef476f", 0.0))
		p3.color_ramp = g3
		_add_to_scene(p3, pos)
	)


func spawn_rainbow_ring(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## Веселкове кільце — кольорові точки розлітаються від центру кільцем.
	var tex_path: String = "res://assets/sprites/particles/circle_03.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	## Кільце 1 — велике
	var p1: CPUParticles2D = CPUParticles2D.new()
	p1.one_shot = true
	p1.explosiveness = 1.0
	p1.amount = 20
	p1.lifetime = 0.8
	p1.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p1.emission_sphere_radius = 15.0
	p1.direction = Vector2.ZERO
	p1.spread = 180.0
	p1.initial_velocity_min = 100.0
	p1.initial_velocity_max = 160.0
	p1.gravity = Vector2.ZERO
	p1.damping_min = 80.0
	p1.damping_max = 120.0
	p1.scale_amount_min = 0.8
	p1.scale_amount_max = 1.5
	p1.scale_amount_curve = _get_ring_curve()
	if tex:
		p1.texture = tex
	var g1: Gradient = Gradient.new()
	g1.set_color(0, Color("ef476f"))
	g1.add_point(0.17, Color("FFD166"))
	g1.add_point(0.33, Color("06d6a0"))
	g1.add_point(0.5, Color("118ab2"))
	g1.add_point(0.67, Color("a78bfa"))
	g1.set_color(1, Color("ef476f", 0.0))
	p1.color_ramp = g1
	_add_to_scene(p1, pos)
	## Кільце 2 — менше, затримка 0.3с
	if not is_inside_tree():
		return
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var p2: CPUParticles2D = CPUParticles2D.new()
		p2.one_shot = true
		p2.explosiveness = 1.0
		p2.amount = 14
		p2.lifetime = 0.7
		p2.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p2.emission_sphere_radius = 10.0
		p2.direction = Vector2.ZERO
		p2.spread = 180.0
		p2.initial_velocity_min = 60.0
		p2.initial_velocity_max = 100.0
		p2.gravity = Vector2.ZERO
		p2.damping_min = 60.0
		p2.damping_max = 100.0
		p2.scale_amount_min = 0.6
		p2.scale_amount_max = 1.2
		p2.scale_amount_curve = _get_ring_curve()
		if tex:
			p2.texture = tex
		var g2: Gradient = Gradient.new()
		g2.set_color(0, Color(1.0, 0.95, 0.9))
		g2.add_point(0.2, Color("a78bfa"))
		g2.add_point(0.5, Color("06d6a0"))
		g2.add_point(0.75, Color("FFD166", 0.5))
		g2.set_color(1, Color("118ab2", 0.0))
		p2.color_ramp = g2
		_add_to_scene(p2, pos)
	)


func spawn_sparkle_pop(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ іскристий спалах — variety текстури + scale curve + richer gradient.
	## Підшар: soft glow
	var circle_path: String = "res://assets/sprites/particles/circle_04.png"
	if ResourceLoader.exists(circle_path):
		var circle_tex: Texture2D = load(circle_path)
		var glow: CPUParticles2D = CPUParticles2D.new()
		glow.one_shot = true
		glow.explosiveness = 1.0
		glow.amount = 6
		glow.lifetime = 0.6
		glow.direction = Vector2.ZERO
		glow.spread = 180.0
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 30.0
		glow.gravity = Vector2(0, -25)
		glow.damping_min = 40.0
		glow.damping_max = 60.0
		glow.scale_amount_min = 1.5
		glow.scale_amount_max = 2.5
		glow.scale_amount_curve = _get_ring_curve()
		glow.texture = circle_tex
		var glow_g: Gradient = Gradient.new()
		glow_g.set_color(0, Color("06d6a0", 0.25))
		glow_g.add_point(0.3, Color("80ffdb", 0.15))  ## м'яке бірюзове ядро
		glow_g.add_point(0.6, Color("06d6a0", 0.06))  ## згасання
		glow_g.set_color(glow_g.get_point_count() - 1, Color("06d6a0", 0.0))
		glow.color_ramp = glow_g
		_add_to_scene(glow, pos)
	## Основні частинки
	var tex_paths: Array[String] = [
		"res://assets/sprites/particles/star_04.png",
		"res://assets/sprites/particles/star_06.png",
		"res://assets/sprites/particles/magic_03.png",
	]
	var tex_path: String = tex_paths[randi() % tex_paths.size()]
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var palette: Array[Color] = [Color("06d6a0"), Color("FFD166"), Color("118ab2"), Color("a78bfa")]
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.5
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2.ZERO
	p.damping_min = 160.0
	p.damping_max = 230.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _get_pop_curve()
	if tex:
		p.texture = tex
	var base_color: Color = palette[randi() % palette.size()]
	var grad: Gradient = Gradient.new()
	grad.set_color(0, base_color)
	grad.add_point(0.3, Color(base_color.lightened(0.25), 0.8))
	grad.add_point(0.6, Color(base_color, 0.5))
	grad.set_color(1, Color(base_color, 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_gift_unwrap(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## Розпакування подарунка — частинки спіралюють назовні як стрічка.
	var tex_path: String = "res://assets/sprites/particles/twirl_02.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 18
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 200.0
	p.angular_velocity_min = 360.0
	p.angular_velocity_max = 720.0
	p.gravity = Vector2(0, -30)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.scale_amount_curve = _get_burst_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.85))
	grad.add_point(0.2, Color("ffb5a7"))
	grad.add_point(0.5, Color("FFD166", 0.8))
	grad.add_point(0.8, Color("a78bfa", 0.4))
	grad.set_color(1, Color("ffb5a7", 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)
	## 4 плаваючі іскринки
	var spark_tex_path: String = "res://assets/sprites/particles/star_02.png"
	if not ResourceLoader.exists(spark_tex_path):
		return
	var spark_tex: Texture2D = load(spark_tex_path)
	var scene: Node = get_tree().current_scene
	if not scene:
		return
	for i: int in 4:
		var spark: Control = Control.new()
		spark.custom_minimum_size = Vector2(16, 16)
		spark.size = Vector2(16, 16)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.modulate = Color("FFD166", 0.0)
		spark.position = pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
		spark.pivot_offset = Vector2(8, 8)
		spark.draw.connect(func() -> void:
			spark.draw_texture_rect(spark_tex, Rect2(Vector2.ZERO, Vector2(16, 16)), false)
		)
		scene.add_child(spark)
		var delay: float = 0.2 + float(i) * 0.15
		var tw: Tween = scene.create_tween().set_parallel(true)
		tw.tween_property(spark, "modulate:a", 0.9, 0.2).set_delay(delay)
		tw.tween_property(spark, "position:y", spark.position.y - randf_range(80, 140), 0.8)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "position:x",
			spark.position.x + randf_range(-30, 30), 0.8)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE)
		tw.tween_property(spark, "scale", Vector2(1.2, 1.2), 0.4).set_delay(delay)
		tw.chain().tween_property(spark, "modulate:a", 0.0, 0.3)
		tw.chain().tween_property(spark, "scale", Vector2(0.3, 0.3), 0.3)
		tw.chain().tween_callback(spark.queue_free)




func spawn_confetti_rain(vp_size: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## Дощ конфеті зверху — для perfect score (5 зірок). 2 хвилі, 1.5с.
	var tex_path: String = "res://assets/sprites/particles/magic_03.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	if not is_inside_tree():
		return
	for wave: int in 2:
		var delay: float = float(wave) * 0.6
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			var p: CPUParticles2D = CPUParticles2D.new()
			p.one_shot = true
			p.explosiveness = 0.3
			p.amount = 24
			p.lifetime = 1.8
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(vp_size.x * 0.4, 5)
			p.direction = Vector2.DOWN
			p.spread = 30.0
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 150.0
			p.gravity = Vector2(0, 200)
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.5
			p.scale_amount_curve = _get_rain_curve()
			if tex:
				p.texture = tex
			var g: Gradient = Gradient.new()
			g.set_color(0, Color("FFD166"))
			g.add_point(0.3, Color("ef476f"))
			g.add_point(0.6, Color("06d6a0"))
			g.set_color(1, Color("a78bfa", 0.0))
			p.color_ramp = g
			_add_to_scene(p, Vector2(vp_size.x * 0.5, -20))
		)


func spawn_correct_sparkle(pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## HQ compact sparkle — spark + flare flash для правильної відповіді (LAW 28).
	## Flare flash underlayer
	var flare_path: String = "res://assets/sprites/particles/flare_01.png"
	if ResourceLoader.exists(flare_path):
		var flare_tex: Texture2D = load(flare_path)
		var flash: CPUParticles2D = CPUParticles2D.new()
		flash.one_shot = true
		flash.explosiveness = 1.0
		flash.amount = 4
		flash.lifetime = 0.4
		flash.direction = Vector2.ZERO
		flash.spread = 180.0
		flash.initial_velocity_min = 5.0
		flash.initial_velocity_max = 15.0
		flash.gravity = Vector2.ZERO
		flash.scale_amount_min = 1.8
		flash.scale_amount_max = 2.8
		flash.scale_amount_curve = _get_ring_curve()
		flash.texture = flare_tex
		var flash_g: Gradient = Gradient.new()
		flash_g.set_color(0, Color("FFD166", 0.25))
		flash_g.add_point(0.2, Color(1.0, 0.97, 0.82, 0.18))  ## тепле ядро
		flash_g.add_point(0.45, Color("FFD166", 0.1))  ## середнє згасання
		flash_g.add_point(0.7, Color("FFD166", 0.03))  ## фінальне згасання
		flash_g.set_color(flash_g.get_point_count() - 1, Color("FFD166", 0.0))
		flash.color_ramp = flash_g
		_add_to_scene(flash, pos)
	## Основні іскри
	var tex_path: String = "res://assets/sprites/particles/star_04.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.5
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 50)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.scale_amount_curve = _get_pop_curve()
	if tex:
		p.texture = tex
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0))
	grad.add_point(0.15, Color(1.0, 0.98, 0.8))
	grad.add_point(0.4, Color("FFD166"))
	grad.add_point(0.7, Color("FFD166", 0.45))
	grad.set_color(1, Color("FFD166", 0.0))
	p.color_ramp = grad
	_add_to_scene(p, pos)


func spawn_premium_confetti_rain(vp_size: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	## Текстурований дощ конфеті — для perfect score (5 зірок). 3 хвилі (LAW 28).
	var star_tex: Texture2D = null
	var magic_tex: Texture2D = null
	var star_path: String = "res://assets/sprites/particles/star_06.png"
	var magic_path: String = "res://assets/sprites/particles/magic_03.png"
	if ResourceLoader.exists(star_path):
		star_tex = load(star_path)
	if ResourceLoader.exists(magic_path):
		magic_tex = load(magic_path)
	if not is_inside_tree():
		return
	## Хвиля 1: золоті зірки
	_spawn_rain_wave(vp_size, star_tex, 0.0,
		[Color(1.0, 1.0, 0.9), Color("FFD166"), Color("FFD166", 0.0)])
	## Хвиля 2: кольорові іскри (затримка 0.4с)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_spawn_rain_wave(vp_size, magic_tex, 0.0,
			[Color("ef476f"), Color("06d6a0"), Color("a78bfa", 0.0)])
	)
	## Хвиля 3: фінальний шлейф (затримка 0.9с)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_spawn_rain_wave(vp_size, star_tex, 0.0,
			[Color("118ab2"), Color("06d6a0"), Color("FFD166", 0.0)])
	)


func _spawn_rain_wave(vp_size: Vector2, tex: Texture2D, _delay: float,
		colors: Array) -> void:
	## HQ допоміжна — одна хвиля дощу конфеті з scale curve.
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.3
	p.amount = 30
	p.lifetime = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp_size.x * 0.45, 5)
	p.direction = Vector2.DOWN
	p.spread = 35.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.gravity = Vector2(0, 220)
	p.angular_velocity_min = -270.0
	p.angular_velocity_max = 270.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.9
	p.scale_amount_curve = _get_rain_curve()
	if tex:
		p.texture = tex
	if colors.size() >= 3:
		var g: Gradient = Gradient.new()
		g.set_color(0, colors[0])
		g.add_point(0.2, Color(colors[0]).lightened(0.15))  ## світліший відтінок
		g.add_point(0.5, colors[1])  ## основний колір
		g.add_point(0.75, Color(colors[1], 0.35))  ## теплий відхід
		g.set_color(g.get_point_count() - 1, colors[2])
		p.color_ramp = g
	_add_to_scene(p, Vector2(vp_size.x * 0.5, -20))


func _spawn_from_template(template: CPUParticles2D, pos: Vector2) -> void:
	if not template:
		push_warning("VFXManager: шаблон не знайдено")
		return
	var copy: CPUParticles2D = template.duplicate()
	_add_to_scene(copy, pos)


func _add_to_scene(particles: CPUParticles2D, pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		push_warning("VFXManager: SceneTree недоступне")
		return
	var scene: Node = tree.current_scene
	if not scene:
		push_warning("VFXManager: поточна сцена недоступна")
		return
	particles.position = pos
	particles.emitting = true
	scene.add_child(particles)
	_active_particles.append(particles)
	var cleanup_time: float = particles.lifetime + CLEANUP_MARGIN
	var p_ref: WeakRef = weakref(particles)
	if not is_inside_tree():
		return
	get_tree().create_timer(cleanup_time).timeout.connect(func() -> void:
		var p: CPUParticles2D = p_ref.get_ref() as CPUParticles2D
		if p:
			_active_particles.erase(p)
			p.queue_free()
		else:
			## Частинка вже видалена — чистимо стейл-посилання з масиву
			var cleaned: Array[CPUParticles2D] = []
			for pp: CPUParticles2D in _active_particles:
				if is_instance_valid(pp):
					cleaned.append(pp)
			_active_particles = cleaned
	)
