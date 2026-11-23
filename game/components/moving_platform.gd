extends "res://game/components/component_base.gd"
## Движущаяся платформа: AnimatableBody2D (sync_to_physics) едет по пути — герой стоит на ней без проскальзывания.
## Зажатого героя выталкивает или убивает (вкладка «Объекты», группа "crusher"). Активна = едет.
## Сквозь штрихи не проезжает: перед каждым шагом проверяет путь своей формой по маске «Штрихи» (shape cast),
## перекрыт — реакция из on_blocked: ждать / развернуться / сломать штрих (ТЗ Ф2, 3.8).
## События reached_point {index}, reached_end.

const GeometryBuilder := preload("res://game/level/geometry_builder.gd")
const PathFollow := preload("res://game/components/path_follow.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
enum Blocked { WAIT, TURN, BREAK }
## px: если до штриха меньше — не подъезжать по кусочку. Стоящая платформа не сдвигается на доли пикселя каждый кадр.
const CREEP_MIN := 0.5
## Сколько раз за один шаг ломать штрихи (защита от бесконечного цикла).
const BREAK_MAX := 4

var body: AnimatableBody2D
var follow := PathFollow.new()
var _form := PackedVector2Array()
var _closed := false
var _origin := Vector2.ZERO     ## первая точка пути (мир)
var _waiting := false
var _img: Node2D
var _img_path := ""
var _paths: Dictionary = {}
var _blocked := false      ## стоит: путь перекрыт штрихом
var _turned := false       ## уже развернулась перед штрихом — второй раз не крутится (перекрыто с двух сторон)
var _cast := PhysicsShapeQueryParameters2D.new()


func _setup(ctx: Dictionary) -> void:
	_paths = ctx.get("paths", {})
	var list: Array = shapes.get("form", [])
	if not list.is_empty():
		_form = list[0]["points"]
		_closed = list[0]["closed"]
	else:
		_form = PackedVector2Array([Vector2(-64, 0), Vector2(64, 0)])
	body = AnimatableBody2D.new()
	body.sync_to_physics = true
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.add_to_group("crusher")
	add_child(body)
	_cast.collision_mask = STROKES_LAYER
	_cast.collide_with_areas = false


func _apply() -> void:
	for c in body.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.queue_free()
	if not (_closed and GeometryBuilder.fill_polygon(body, _form)):
		GeometryBuilder.fill_chain(body, _form, props.thickness, props.one_way, 60.0)
	var path: Dictionary = _paths.get(props.path_uid, {})
	var keep := [follow.i, follow.dirn, follow.u, follow.finished]
	var had := follow.pts.size() >= 2
	if path.is_empty():
		follow.setup(PackedVector2Array(), false, props.mode)
	else:
		follow.setup(path["points"], path["closed"], props.mode)
		_origin = (path["points"] as PackedVector2Array)[0]
		if had and follow.pts.size() >= 2:
			follow.i = clampi(keep[0], 0, follow.pts.size() - 1)
			follow.dirn = keep[1]
			follow.u = keep[2]
	_waiting = props.wait_for_player and follow.i == 0 and follow.u == 0.0
	if props.image != _img_path:
		if _img != null:
			_img.queue_free()
		_img = null
		_img_path = props.image
		if _img_path != "" and ArtLoader.exists(_img_path):
			_img = ArtLoader.make_node(_img_path, Rect2(), true)
			body.add_child(_img)
	if _img != null:
		_img.scale = Vector2.ONE * props.image_scale
	_place()


func _place() -> void:
	if follow.pts.size() >= 2:
		body.position = follow.pos(props.ease) - _origin


func _physics_process(delta: float) -> void:
	super(delta)
	if not active or follow.finished:
		return
	if _waiting:
		var pl = runtime.player if runtime != null else null
		if pl != null and is_instance_valid(pl) and pl.standing_on(body):
			_waiting = false
		else:
			return
	for e in _advance(delta):
		if e[0] == "point":
			emit_event("reached_point", {"index": e[1]})
		else:
			emit_event("reached_end")
			if props.wait_for_player:
				_waiting = true
	_place()
	queue_redraw()


## Шаг по пути с проверкой штрихов. Возвращает события пути сделанного шага. Путь перекрыт — реакция из on_blocked;
## стоящая перед штрихом платформа не двигается, только проверяет путь каждый кадр.
func _advance(delta: float) -> Array:
	var from := body.position
	var s0 := _fstate()
	var evs := follow.step(delta, props.speed, props.pause, props.ease)
	var hit := _cast_strokes(_motion(from))
	if hit.is_empty():
		_blocked = false
		_turned = false
		return evs
	match int(props.on_blocked):
		Blocked.BREAK:
			var n := 0
			while not hit.is_empty() and n < BREAK_MAX:
				var strokes := _breakable(hit["hits"])
				if strokes.is_empty():
					break   # результат рисуемого контура не ломается — перед ним ждём
				for st in strokes:
					st.break_stroke(uid)
				n += 1
				hit = _cast_strokes(_motion(from))
			if hit.is_empty():
				_blocked = false
				return evs
		Blocked.TURN:
			if not _turned:
				_fset(s0)
				follow.reverse()
				_turned = true
				s0 = _fstate()
				evs = follow.step(delta, props.speed, props.pause, props.ease)
				hit = _cast_strokes(_motion(from))
				if hit.is_empty():
					_blocked = false
					return evs
	# ждать: доехать вплотную до штриха и стоять, пока путь не освободится
	_blocked = true
	var full := _motion(from).length()
	_fset(s0)
	var safe: float = hit["safe"]
	if full * safe < CREEP_MIN:
		return []
	evs = follow.step(delta * safe, props.speed, props.pause, props.ease)
	if not _cast_strokes(_motion(from)).is_empty():
		_fset(s0)
		return []
	return evs


## Сдвиг тела (в мире) из положения from в текущую точку пути.
func _motion(from: Vector2) -> Vector2:
	return global_transform.basis_xform(follow.pos(props.ease) - _origin - from)


## Проверка пути формой тела по маске «Штрихи». Свободно — {}; иначе {safe: доля сдвига без касания, hits: [тела]}.
## Штрих, который уже пересекает платформу (нарисован сквозь неё), не мешает — так работает shape cast.
func _cast_strokes(motion: Vector2) -> Dictionary:
	if motion.length_squared() < 0.000001:
		return {}
	var space := get_world_2d().direct_space_state
	var bxf := body.global_transform
	var parts: Array = []   # [rid формы, её преобразование в мире]
	for owner_id in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var oxf := bxf * body.shape_owner_get_transform(owner_id)
		for j in body.shape_owner_get_shape_count(owner_id):
			parts.append([body.shape_owner_get_shape(owner_id, j).get_rid(), oxf])
	var best := 1.0
	var best_unsafe := 1.0
	for pt in parts:
		_cast.shape_rid = pt[0]
		_cast.transform = pt[1]
		_cast.motion = motion
		var r := space.cast_motion(_cast)
		if r.size() == 2 and r[0] < best:
			best = r[0]
			best_unsafe = r[1]
	if best >= 1.0:
		return {}
	var hits: Array = []
	_cast.motion = Vector2.ZERO
	for pt in parts:
		_cast.shape_rid = pt[0]
		_cast.transform = (pt[1] as Transform2D).translated(motion * best_unsafe)
		for c in space.intersect_shape(_cast, 8):
			if not hits.has(c["collider"]):
				hits.append(c["collider"])
	return {"safe": best, "hits": hits}


## Штрихи, которые можно сломать, среди задетых тел (тело штриха — дочернее у узла штриха).
func _breakable(hits: Array) -> Array:
	var out: Array = []
	for c in hits:
		var n = (c as Node).get_parent() if c is Node else null
		if n != null and n.has_method("break_stroke") and not n.broken and not out.has(n):
			out.append(n)
	return out


func _fstate() -> Array:
	return [follow.i, follow.dirn, follow.u, follow.wait, follow.finished]


func _fset(s: Array) -> void:
	follow.i = s[0]
	follow.dirn = s[1]
	follow.u = s[2]
	follow.wait = s[3]
	follow.finished = s[4]


func _snap() -> Dictionary:
	return {"i": follow.i, "dirn": follow.dirn, "u": follow.u, "wait": follow.wait, "fin": follow.finished, "waiting": _waiting}


func _restore(d: Dictionary) -> void:
	follow.i = d.get("i", 0)
	follow.dirn = d.get("dirn", 1)
	follow.u = d.get("u", 0.0)
	follow.wait = d.get("wait", 0.0)
	follow.finished = d.get("fin", false)
	_waiting = d.get("waiting", false)
	_place()
	body.reset_physics_interpolation()


func _draw() -> void:
	draw_set_transform(body.position)
	var col: Color = props.color
	if _closed and _form.size() >= 3:
		draw_colored_polygon(_form, col)
		var o := _form.duplicate()
		o.append(_form[0])
		draw_polyline(o, Color(0, 0, 0, 0.5), 2.0)
	elif _img == null:
		var th: float = props.thickness
		for i in range(_form.size() - 1):
			var a := _form[i]
			var b := _form[i + 1]
			var dn := (b - a).orthogonal().normalized()
			if dn.y < 0.0:
				dn = -dn
			draw_colored_polygon(PackedVector2Array([a, b, b + dn * th, a + dn * th]), col)
			draw_line(a, b, col.lightened(0.35), 3.0)
	draw_set_transform(Vector2.ZERO)
	_draw_debug()


func _debug() -> String:
	if _waiting:
		return "ждёт героя · точка %d" % follow.i
	if not active or follow.finished:
		return "стоит · точка %d" % follow.i
	return ("ждёт: путь перекрыт штрихом" if _blocked else "едет") + " · точка %d" % follow.i
