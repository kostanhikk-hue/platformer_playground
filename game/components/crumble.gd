extends "res://game/components/component_base.gd"
## Ломкая платформа: герой встал сверху → через delay с рушится (дрожит перед этим), через restore_time — снова.
## События crumbled, restored.

const GeometryBuilder := preload("res://game/level/geometry_builder.gd")

var _body: StaticBody2D
var _form := PackedVector2Array()
var _closed := false
var _state := 0       ## 0 цела, 1 дрожит, 2 рухнула
var _t := 0.0
var _fall := 0.0


func _setup(_ctx: Dictionary) -> void:
	var list: Array = shapes.get("form", [])
	if not list.is_empty():
		_form = list[0]["points"]
		_closed = list[0]["closed"]
	else:
		_form = PackedVector2Array([Vector2(-48, 0), Vector2(48, 0)])


func _apply() -> void:
	_rebuild()


func _rebuild() -> void:
	if _body != null:
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.collision_layer = WORLD_LAYER
	_body.collision_mask = 0
	if not (_closed and GeometryBuilder.fill_polygon(_body, _form)):
		GeometryBuilder.fill_chain(_body, _form, props.thickness, props.one_way, 60.0)
	add_child(_body)
	_set_solid(_state != 2)


func _set_solid(on: bool) -> void:
	for c in _body.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", not on)


func _physics_process(delta: float) -> void:
	super(delta)
	match _state:
		0:
			var pl = runtime.player if runtime != null else null
			if pl != null and is_instance_valid(pl) and pl.standing_on(_body):
				_state = 1
				_t = props.delay
		1:
			_t -= delta
			if _t <= 0.0:
				_state = 2
				_t = props.restore_time
				_fall = 0.0
				_set_solid(false)
				emit_event("crumbled")
		2:
			_fall += delta
			if props.restore_time > 0.0:
				_t -= delta
				if _t <= 0.0:
					_state = 0
					_set_solid(true)
					emit_event("restored")
	queue_redraw()


func _snap() -> Dictionary:
	return {"state": 0 if _state == 1 else _state, "t": _t}


func _restore(d: Dictionary) -> void:
	_state = d.get("state", 0)
	_t = d.get("t", 0.0)
	_fall = 10.0
	_set_solid(_state != 2)


func _draw() -> void:
	var op: Resource = Params.get_res("objects")
	var off := Vector2.ZERO
	var alpha := 1.0
	if _state == 1 and props.shake:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * op.crumble_shake
	elif _state == 2:
		off = Vector2(0, op.crumble_fall_speed * _fall * _fall * 0.5)
		alpha = 0.0 if op.crumble_fade <= 0.0 else clampf(1.0 - _fall / op.crumble_fade, 0.0, 1.0)
		if alpha <= 0.0:
			_draw_ghost()
			return
	var col: Color = Color(props.color, props.color.a * alpha)
	var pts := PackedVector2Array()
	for q in _form:
		pts.append(q + off)
	if _closed and pts.size() >= 3:
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.5 * alpha), 2.0)
	else:
		var th: float = props.thickness
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var dn := (b - a).orthogonal().normalized()
			if dn.y < 0.0:
				dn = -dn
			draw_colored_polygon(PackedVector2Array([a, b, b + dn * th, a + dn * th]), col)
			# трещины
			var m := a.lerp(b, 0.5)
			draw_line(m, m + dn * th * 0.8 + (b - a).normalized() * 5.0, Color(0, 0, 0, 0.35 * alpha), 1.5)
	_draw_debug()


func _draw_ghost() -> void:
	if props.restore_time <= 0.0:
		return
	var pts := _form.duplicate()
	if _closed and pts.size() > 0:
		pts.append(pts[0])
	draw_polyline(pts, Color(props.color, 0.2), 1.0)


func _debug() -> String:
	return ["цела", "дрожит %.2f с" % _t, "рухнула" + (" (вернётся через %.1f с)" % _t if props.restore_time > 0.0 else "")][_state]
