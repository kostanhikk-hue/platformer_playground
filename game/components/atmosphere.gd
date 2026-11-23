extends "res://game/components/component_base.gd"
## Атмосфера: эмиттер частиц (CPUParticles2D) в прямоугольной области: пыль, искры факела, песок, лепестки.

## Пресеты: количество на 512×256, время жизни, направление, разброс, скорость, гравитация, размер, цвет.
const PRESETS := [
	{"amount": 40, "life": 6.0, "dir": Vector2(1, -0.2), "spread": 180.0, "v": 10.0, "g": Vector2(0, -2), "s": 2.0, "col": Color(0.95, 0.9, 0.8)},
	{"amount": 30, "life": 1.4, "dir": Vector2(0, -1), "spread": 25.0, "v": 70.0, "g": Vector2(0, -30), "s": 2.0, "col": Color(1.0, 0.65, 0.25)},
	{"amount": 120, "life": 2.5, "dir": Vector2(1, 0.05), "spread": 8.0, "v": 160.0, "g": Vector2(0, 10), "s": 1.5, "col": Color(0.9, 0.78, 0.55)},
	{"amount": 24, "life": 7.0, "dir": Vector2(0.3, 1), "spread": 30.0, "v": 25.0, "g": Vector2(0, 12), "s": 4.0, "col": Color(1.0, 0.75, 0.82)},
]

var particles: CPUParticles2D


func resets_on_death() -> bool:
	return false


func _setup(_ctx: Dictionary) -> void:
	particles = CPUParticles2D.new()
	add_child(particles)


func _apply() -> void:
	var pr: Dictionary = PRESETS[clampi(int(props.preset), 0, PRESETS.size() - 1)]
	var area_k: float = (props.width * props.height) / (512.0 * 256.0)
	particles.amount = clampi(int(float(pr["amount"]) * area_k * props.density), 1, 4000)
	particles.lifetime = pr["life"]
	particles.preprocess = pr["life"]
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(props.width, props.height) * 0.5
	particles.direction = pr["dir"]
	particles.spread = pr["spread"]
	particles.initial_velocity_min = float(pr["v"]) * props.speed * 0.6
	particles.initial_velocity_max = float(pr["v"]) * props.speed * 1.2
	var wind_v: Vector2 = Vector2.from_angle(deg_to_rad(-props.wind_deg)) * props.wind
	particles.gravity = (pr["g"] as Vector2) + wind_v
	particles.scale_amount_min = float(pr["s"]) * props.size * 0.6
	particles.scale_amount_max = float(pr["s"]) * props.size * 1.3
	var c: Color = pr["col"] if props.use_preset_color else props.color
	var grad := Gradient.new()
	grad.set_color(0, Color(c, 0.0))
	grad.set_color(1, Color(c, 0.0))
	grad.add_point(0.2, Color(c, props.alpha))
	grad.add_point(0.8, Color(c, props.alpha))
	particles.color_ramp = grad
	if int(props.preset) == 3:
		particles.angular_velocity_min = -90.0
		particles.angular_velocity_max = 90.0
	particles.emitting = active


func _on_active(on: bool) -> void:
	if particles != null:
		particles.emitting = on
