extends "res://game/ink/stroke_base.gd"
## Один штрих охры: прямая линия, растёт за draw_time, держит платформу, бьёт врагов в начале жизни, исчезает.
## Параметры: data/ink_params.gd. Общая логика жизни и урона — в stroke_base.gd.

## Размеры без заряда.
static func base_size(p: Resource) -> Dictionary:
	return {"length": p.length, "thickness": p.thickness, "damage": p.damage, "knock": 1.0, "draw_time": p.draw_time}


var dir := Vector2.RIGHT
var length := 200.0
var cur := 0.0
var draw_time := 0.1
var body: StaticBody2D
var shape: RectangleShape2D
var _axis := Vector2.RIGHT
var _brush: Dictionary = {}


## sz — размеры с учётом заряда: {length, thickness, damage, knock, draw_time}. Без заряда — base_size(params).
func setup(params: Resource, start: Vector2, d: Vector2, brush: BrushParams, sz: Dictionary) -> void:
	_base_setup(params, sz)
	dir = d.normalized()
	global_position = start
	length = sz["length"]
	draw_time = sz["draw_time"]

	_brush = Brush.build(PackedVector2Array([Vector2.ZERO, dir * length]), thickness, brush if brush != null else BrushParams.new(), new_rng())

	_axis = dir if dir.x >= 0.0 else -dir   # «верх» платформы всегда смотрит вверх
	body = StaticBody2D.new()
	body.collision_layer = STROKES_LAYER
	body.collision_mask = 0
	body.rotation = _axis.angle()
	add_child(body)
	var cs := CollisionShape2D.new()
	shape = RectangleShape2D.new()
	shape.size = Vector2(1.0, thickness)
	cs.shape = shape
	cs.one_way_collision = params.one_way and absf(dir.x) >= cos(deg_to_rad(params.solid_angle_deg))
	body.add_child(cs)
	_update_shape()


func _update_shape() -> void:
	cur = length if draw_time <= 0.0 else length * clampf(age / draw_time, 0.0, 1.0)
	shape.size = Vector2(maxf(cur, 1.0), thickness)
	body.position = dir * cur * 0.5


func _hit_segments() -> Array:
	return [{"center": dir * cur * 0.5, "angle": _axis.angle(), "len": cur}]


func _knockback() -> Vector2:
	var kx := signf(dir.x) if absf(dir.x) > 0.2 else 1.0
	return Vector2(kx * p.knockback_x, -p.knockback_y)


func _kind() -> String:
	return "ink"


func _polyline() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, dir * maxf(cur, 0.5)])


func _draw() -> void:
	var col: Color = p.color
	Brush.draw(self, _brush, cur, col)
	if cur < length:
		draw_circle(dir * cur, thickness * 0.8, col.lightened(0.3))
	if Fx.debug_hitboxes and age <= p.damage_window and damage > 0.0:
		draw_circle(dir * cur, 4.0, Color(1, 0.2, 0.2, 0.9))
