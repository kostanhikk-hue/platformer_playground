extends Node2D
## Общая основа всех штрихов кисти (линия-охра, волна, будущие приёмы).
## Берёт на себя: время жизни, мигание перед исчезновением, окно урона, поиск целей, хитстоп и тряску.
##
## Ресурс параметров штриха должен содержать поля (одинаковые имена у линии и волны):
##   lifetime, fade_time, fade_blink_hz, fade_min_alpha,
##   damage_window, knockback_x, knockback_y, hitstop, hit_shake, hit_shake_time,
##   hit_pad_along, hit_pad_across, color
##
## Наследник переопределяет:
## В setup() наследник вызывает _base_setup(params, sz), где sz = {damage, thickness, knock}.
##   _update_shape()            — рост/изменение формы каждый кадр (вызывается после age += delta);
##   _hit_segments() -> Array   — отрезки, которые сейчас бьют: [{center: Vector2 (локально), angle: float, len: float}];
##   _knockback() -> Vector2    — вектор отброса цели;
##   _kind() -> String          — тип удара для take_hit ("ink", "wave", ...).
## Цель получает take_hit({"damage", "knockback", "kind"}) — достаточно, чтобы у неё был этот метод.
## Твёрдое тело штриха наследник кладёт в поле body (слой «Штрихи», STROKES_LAYER) — его выключает break_stroke().

const BrushParams := preload("res://data/brush_params.gd")
const Brush := preload("res://game/ink/brush.gd")
const Geometry := preload("res://core/geometry.gd")
const Layers := preload("res://core/layers.gd")
const ENEMY_LAYER := Layers.ENEMY
const STROKES_LAYER := Layers.STROKES

var p: Resource
var damage := 0.0
var thickness := 12.0
var kb_mult := 1.0          ## множитель отброса (заряд)
var age := 0.0
var hit_set: Array = []
var broken := false         ## сломан досрочно (break_stroke): уже не твёрдый и не бьёт, доживает мигание
var _q := PhysicsShapeQueryParameters2D.new()
var _qshape := RectangleShape2D.new()


## sz — размеры конкретного штриха (с учётом заряда): damage, thickness, knock (необязательно).
func _base_setup(params: Resource, sz: Dictionary) -> void:
	p = params
	damage = sz["damage"]
	thickness = maxf(sz["thickness"], 1.0)
	kb_mult = sz.get("knock", 1.0)
	_q.shape = _qshape
	_q.collision_mask = ENEMY_LAYER
	_q.collide_with_areas = false


static func new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


func _physics_process(delta: float) -> void:
	age += delta
	if age >= p.lifetime:
		queue_free()
		return
	_update_shape()
	if damage > 0.0 and age <= p.damage_window:
		_hurt()
	if p.fade_time > 0.0 and p.lifetime - age < p.fade_time:
		var on := int(age * p.fade_blink_hz * 2.0) % 2 == 0
		modulate.a = 1.0 if on else p.fade_min_alpha
	queue_redraw()


func _hurt() -> void:
	var space := get_world_2d().direct_space_state
	for s in _hit_segments():
		_qshape.size = Vector2(maxf(float(s["len"]) + p.hit_pad_along, 1.0), maxf(thickness + p.hit_pad_across, 1.0))
		_q.transform = Transform2D(float(s["angle"]), global_position + (s["center"] as Vector2))
		for r in space.intersect_shape(_q, 16):
			var c: Object = r["collider"]
			if c == null or hit_set.has(c) or not c.has_method("take_hit"):
				continue
			hit_set.append(c)
			var info := {"damage": damage, "knockback": _knockback() * kb_mult, "kind": _kind()}
			if c.take_hit(info):
				Fx.hitstop(p.hitstop)
				Fx.shake(p.hit_shake, p.hit_shake_time)


## Твёрдый отрезок a→b внутри body. Пологие (|угол| < solid_angle_deg) можно проходить снизу, если one_way.
## Сама функция живёт в core/geometry.gd (общая для штрихов и уровня); здесь — обёртка для наследников.
static func make_segment(body: StaticBody2D, a: Vector2, b: Vector2, thick: float, one_way_ok: bool, solid_angle_deg: float) -> CollisionShape2D:
	return Geometry.make_segment(body, a, b, thick, one_way_ok, solid_angle_deg)


## Досрочное исчезновение (например, движущаяся платформа с on_blocked = «Сломать штрих»): твёрдость и урон
## пропадают сразу, дальше обычное мигание fade_time и удаление. by_uid — кто сломал (пусто — без объекта).
## Событие stroke_broken {kind} в шину; исчезновение по времени события не даёт.
func break_stroke(by_uid: String = "") -> void:
	if broken or is_queued_for_deletion():
		return
	broken = true
	damage = 0.0
	var b = get("body")
	if b is CollisionObject2D and is_instance_valid(b):
		b.collision_layer = 0
	age = maxf(age, p.lifetime - p.fade_time)
	Events.emit_event(by_uid, "stroke_broken", {"kind": _kind()})


## Нарисованная на данный момент часть штриха в мировых координатах (для рисуемых контуров и закрашивания):
## {points: PackedVector2Array, thickness: float, kind: String ("ink" / "wave")}.
func get_world_polyline() -> Dictionary:
	var local := _polyline()
	var out := PackedVector2Array()
	var xf := global_transform
	for q in local:
		out.append(xf * q)
	return {"points": out, "thickness": thickness, "kind": _kind()}


## Наследник: нарисованная часть центральной линии в локальных координатах.
func _polyline() -> PackedVector2Array:
	return PackedVector2Array()


func _update_shape() -> void:
	pass

func _hit_segments() -> Array:
	return []

func _knockback() -> Vector2:
	return Vector2.ZERO

func _kind() -> String:
	return "stroke"
