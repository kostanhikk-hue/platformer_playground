extends "res://game/ink/stroke_base.gd"
## Волна: изогнутый штрих, повёрнутый вдоль направления прицела. Растёт за sweep_time,
## держит пандус и стену, бьёт врагов во время взмаха, затем мигает и исчезает.
## Параметры: data/wave_params.gd. Общая логика жизни и урона — в stroke_base.gd.
##
## Форма считается в make_points() и целиком поворачивается на угол прицела:
## при базовом угле 90° волна идёт вверх и выгибается назад — это тот же пандус, повёрнутый на 90°.


## Ось «подъёма» волны: направление, повёрнутое на 90° к «верху».
## keep_upright — если ось смотрит вниз (волна пущена назад/под углом > 90°), разворачиваем её вверх.
## lift_flip — затем выгибаем в обратную сторону.
const MAX_CURVE_STEPS := 512   ## защита от зависания: больше сегментов не нужно и очень дорого

static func lift_axis(p: Resource, d: Vector2, side: int) -> Vector2:
	var n := Vector2(d.y, -d.x) * float(side)
	if p.keep_upright and n.y > 0.001:
		n = -n
	if p.lift_flip:
		n = -n
	return n


## Размеры без заряда.
static func base_size(p: Resource) -> Dictionary:
	return {"reach": p.reach, "height": p.height, "extra": p.wall_extra, "thickness": p.thickness, "damage": p.damage, "knock": 1.0}


## Точки центральной линии (локальные координаты, первая точка — (0,0) у основания).
## Суперэллипс: curve_power = 1 даёт прямую, 2 — четверть эллипса, >2 — «острее».
## Используется и самой волной, и предпросмотром у героя.
static func make_points(p: Resource, d: Vector2, side: int, sz: Dictionary) -> PackedVector2Array:
	var reach: float = sz["reach"]
	var height: float = sz["height"]
	var extra: float = sz["extra"]
	var n := lift_axis(p, d, side)
	var e := 2.0 / maxf(p.curve_power, 0.01)
	var steps := clampi(p.curve_steps, 2, MAX_CURVE_STEPS)
	var from: float = minf(p.curve_from, p.curve_to - 0.01)
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var u := lerpf(from, p.curve_to, float(i) / steps)
		var th := (PI * 0.5) * (1.0 - u)
		var cx := pow(maxf(cos(th), 0.0), e)
		var sy := pow(maxf(sin(th), 0.0), e)
		var along := (1.0 - sy) if p.curve_invert else cx
		var up := cx if p.curve_invert else (1.0 - sy)
		pts.append(d * (reach * along) + n * (height * up))
	var base := pts[0]
	for i in range(pts.size()):
		pts[i] -= base
	if extra > 0.0:
		pts.append(pts[pts.size() - 1] + n * extra)
	return pts


var pts := PackedVector2Array()
var cum := PackedFloat32Array()
var segs: Array = []
var total := 1.0
var dir := Vector2.RIGHT
var lift := Vector2.UP
var pillar := false
var foot := Vector2.ZERO
var revealed := 0.0
var body: StaticBody2D
var _brush_main: Dictionary = {}
var _brush_pillar: Dictionary = {}


func setup(params: Resource, brush: BrushParams, origin: Vector2, d: Vector2, side: int, sz: Dictionary) -> void:
	_base_setup(params, sz)
	dir = d.normalized()
	lift = lift_axis(params, dir, side)
	pillar = params.wall_to_ground
	# верхняя грань волны начинается ровно на линии основания
	global_position = origin - lift * thickness * 0.5

	pts = make_points(params, dir, side, sz)
	var tip := pts[pts.size() - 1]
	foot = dir * tip.dot(dir)
	cum.resize(pts.size())
	cum[0] = 0.0
	for i in range(1, pts.size()):
		cum[i] = cum[i - 1] + pts[i - 1].distance_to(pts[i])
	total = maxf(cum[pts.size() - 1], 1.0)

	body = StaticBody2D.new()
	body.collision_layer = STROKES_LAYER
	body.collision_mask = 0
	add_child(body)
	for i in range(pts.size() - 1):
		_add_seg(pts[i], pts[i + 1], cum[i], params.one_way)
	if pillar:
		_add_seg(tip, foot, total, false)

	var rng := new_rng()
	var b := brush if brush != null else BrushParams.new()
	_brush_main = Brush.build(pts, thickness, b, rng)
	if pillar and tip.distance_to(foot) > 1.0:
		_brush_pillar = Brush.build(PackedVector2Array([tip, foot]), thickness, b, rng)
	_update_shape()


func _add_seg(a: Vector2, b: Vector2, start_cum: float, one_way_ok: bool) -> void:
	var cs := make_segment(body, a, b, thickness, one_way_ok, p.solid_angle_deg)
	if cs == null:
		return
	cs.disabled = true
	segs.append({"center": (a + b) * 0.5, "angle": (b - a).angle(), "len": a.distance_to(b), "start": start_cum, "shape": cs})


func _update_shape() -> void:
	var frac := 1.0 if p.sweep_time <= 0.0 else clampf(age / p.sweep_time, 0.0, 1.0)
	revealed = total * frac
	for s in segs:
		var cs: CollisionShape2D = s["shape"]
		var off: bool = float(s["start"]) > revealed
		if cs.disabled != off:
			cs.set_deferred("disabled", off)


func _hit_segments() -> Array:
	return segs.filter(func(s): return float(s["start"]) <= revealed)


## Вперёд вдоль волны и вдоль оси подъёма.
func _knockback() -> Vector2:
	return dir * p.knockback_x + lift * p.knockback_y


func _kind() -> String:
	return "wave"


func _polyline() -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	for i in range(1, pts.size()):
		if cum[i] <= revealed:
			out.append(pts[i])
		else:
			out.append(_tip_point())
			break
	if pillar and revealed >= total:
		out.append(foot)
	if out.size() == 1:
		out.append(pts[0] + dir * 0.5)
	return out


func _tip_point() -> Vector2:
	for i in range(1, pts.size()):
		if cum[i] > revealed:
			var seg := cum[i] - cum[i - 1]
			return pts[i - 1].lerp(pts[i], clampf((revealed - cum[i - 1]) / maxf(seg, 0.001), 0.0, 1.0))
	return pts[pts.size() - 1]


func _draw() -> void:
	var col: Color = p.color
	if pillar and revealed >= total and not _brush_pillar.is_empty():
		Brush.draw(self, _brush_pillar, 1.0e9, p.pillar_color)
	Brush.draw(self, _brush_main, revealed, col)
	if revealed < total:
		draw_circle(_tip_point(), thickness * 0.8, col.lightened(0.6))
	if Fx.debug_hitboxes and age <= p.damage_window and damage > 0.0:
		draw_circle(_tip_point(), 4.0, Color(1, 1, 0.2, 0.9))
