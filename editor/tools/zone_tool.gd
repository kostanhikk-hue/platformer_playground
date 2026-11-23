extends "res://editor/tools/tool_base.gd"
## Зона (Z): тяни мышью прямоугольник — появится триггер-зона этой формы (id t_N — переименуй в инспекторе
## и напиши заметку). Многоугольник — кнопка «Нарисовать форму заново» в инспекторе зоны.
## Если задан target (кнопка «Прямоугольником» у выделенной зоны) — меняется форма этой зоны.

const Catalog := preload("res://game/level/catalog.gd")

var target: PlacedObject = null
var _from = null
var _to := Vector2.ZERO


func title() -> String:
	return "Зона" if target == null else "Зона %s: новый прямоугольник" % target.uid


func hint() -> String:
	return "тяни мышью прямоугольник зоны (сетка — G, Alt — без привязки), Esc — отмена"


func deactivate() -> void:
	_from = null
	target = null


func _sn(p: Vector2) -> Vector2:
	if EdInput.alt():
		return p
	return ed.snap_grid(p) if ed.grid_snap else ed.snap(p)


func input(event: InputEvent) -> void:
	var m: Vector2 = ed.mouse_world()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_from = _sn(m)
			_to = _from
		elif _from != null:
			_to = _sn(m)
			var r := Rect2(_from, _to - _from).abs()
			_from = null
			if r.size.x < 4.0 or r.size.y < 4.0:
				ed.say("Зона слишком маленькая — тяни мышью прямоугольник")
				return
			_make(r)
	elif event is InputEventMouseMotion and _from != null:
		_to = _sn(m)


func _make(r: Rect2) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	if target != null:
		# новая форма зоны; объект переезжает в центр прямоугольника (там его подпись и ручки)
		var o := target
		var old: Array = ed.level.role_shapes(o.uid, "zone")
		var before := o.position
		o.position = r.get_center()
		var s: GeoShape = ed.new_role_shape(o, "zone", pts, true)
		o.position = before
		var cmds: Array = [Commands.PropsCmd.new(o, {"position": before}, {"position": r.get_center()}, "Зона")]
		if not old.is_empty():
			cmds.append(Commands.ListCmd.new(ed.level, "shapes", old, false))
		cmds.append(Commands.ListCmd.new(ed.level, "shapes", [s], true))
		ed.exec(Commands.Batch.new(cmds, "Форма зоны"))
		target = null
		ed.set_tool("select")
		ed.set_selection([o])
		return
	var def := Catalog.get_def("zone")
	if def == null:
		ed.say("В каталоге нет «zone» — запустите tools/generate_catalog.gd")
		return
	var made: Array = ed.new_object(def, r.get_center())
	var o: PlacedObject = made[0]
	var s: GeoShape = ed.new_role_shape(o, "zone", pts, true)
	ed.exec(Commands.Batch.new([Commands.ListCmd.new(ed.level, "objects", [o], true), Commands.ListCmd.new(ed.level, "shapes", [s], true)], "Зона"))
	ed.set_tool("select")
	ed.set_selection([o])
	ed.say("Зона %s: %d×%d px. Дай ей понятный id (t_…) и заметку в инспекторе." % [o.uid, roundi(r.size.x), roundi(r.size.y)])


func key(event: InputEvent) -> bool:
	if EdInput.pressed(event, "ed_cancel"):
		_from = null
		ed.set_tool("select")
		return true
	return false


func draw_overlay(c: Node2D) -> void:
	var col := Color(0.45, 1.0, 0.65)
	if _from == null:
		c.handle(_sn(ed.mouse_world()), Color(col, 0.9))
		return
	var r := Rect2(_from, _to - _from).abs()
	c.draw_rect(r, Color(col, 0.12))
	c.draw_rect(r, col, false, c.w(1.5))
	c.text(r.end + Vector2(c.w(6), c.w(14)), "%d×%d px" % [roundi(r.size.x), roundi(r.size.y)], Color(1, 1, 1, 0.8), 11)
