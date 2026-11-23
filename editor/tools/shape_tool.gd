extends "res://editor/tools/tool_base.gd"
## Обводка контура по точкам: тело (P), платформа (N), стена (W), смерть (K), путь (L), форма объекта.
## Клик — точка; зажатая ЛКМ — «лассо» (точки через lasso_step). Замкнуть: клик по первой точке или Enter.
## Закончить открытый: Enter или двойной клик. Backspace — убрать точку, Esc — отменить контур.
## Привязки: магнит к другим контурам, G — сетка, Shift — угол, Alt — без привязок.
## Если контур начат поверх выделенного арт-объекта — он привязывается к объекту.
## Путь (L) и форма объекта могут быть и замкнутыми, и открытыми: клик по первой точке — замкнуть,
## Enter / двойной клик — оставить открытым.
## Форма объекта (target_obj + target_role): «Нарисовать форму заново» в инспекторе — новый контур
## заменяет старую форму (replace) или добавляется (уязвимое место).

var kind := GeoShape.Kind.BODY
var pts := PackedVector2Array()    ## мировые точки
var attach: PlacedObject = null
var target_obj: PlacedObject = null
var target_role := ""
var replace: GeoShape = null
var allow_open := true
var _lasso := false
var _press_pos := Vector2.ZERO
var _last_click_t := -10.0


func _init(editor, k: int) -> void:
	super(editor)
	kind = k


func _flexible() -> bool:
	return kind == GeoShape.Kind.PATH or target_obj != null


func title() -> String:
	if target_obj != null:
		return "Форма «%s» объекта %s" % [GeoShape.ROLE_TITLES.get(target_role, target_role), target_obj.uid]
	return "Контур: " + GeoShape.KIND_TITLES[kind]


func hint() -> String:
	if pts.is_empty():
		if target_obj != null:
			return "обведите форму: клик — точка, держи ЛКМ — лассо; Esc — отмена"
		if kind == GeoShape.Kind.PATH:
			return "путь: клик — точка, клик по первой — замкнуть (по кругу), Enter / двойной клик — открытый"
		return "клик — точка, держи ЛКМ — лассо; над выделенным арт-объектом контур привяжется к нему"
	if _flexible():
		return ("клик по первой точке — замкнуть" + (", Enter / двойной клик — открытый" if allow_open else ", Enter — замкнуть")) + ", Backspace — убрать точку, Esc — отменить"
	return ("клик по первой точке / Enter — замкнуть" if _closed() else "Enter / двойной клик — закончить") + ", Backspace — убрать точку, Esc — отменить, Shift — угол, Alt — без привязок"


func deactivate() -> void:
	_cancel()
	target_obj = null
	replace = null


func _closed() -> bool:
	return GeoShape.kind_is_closed(kind)


func _min() -> int:
	return GeoShape.MIN_POINTS[kind]


func _snapped(p: Vector2) -> Vector2:
	var prev = pts[pts.size() - 1] if not pts.is_empty() else null
	return ed.snap(p, prev)


func _near_first(p: Vector2) -> bool:
	var can_close := _closed() or _flexible()
	return pts.size() >= 3 and can_close and p.distance_to(pts[0]) <= ed.px(ed.ep.first_point_size)


func _add_point(p: Vector2) -> void:
	if not pts.is_empty() and pts[pts.size() - 1].distance_to(p) < ed.ep.merge_dist:
		return
	if pts.is_empty() and target_obj == null and kind != GeoShape.Kind.PATH:
		var sel: Array = ed.selection
		attach = null
		if sel.size() == 1 and ed.is_art(sel[0]) and Geometry2D.is_point_in_polygon(p, ed.object_world_poly(sel[0])):
			attach = sel[0]
	pts.append(p)


func input(event: InputEvent) -> void:
	var m: Vector2 = ed.mouse_world()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var now := Time.get_ticks_msec() / 1000.0
				var dbl: bool = mb.double_click or now - _last_click_t <= ed.ep.double_click_time and _press_pos.distance_to(m) < ed.px(ed.ep.handle_size)
				_last_click_t = now
				_press_pos = m
				if dbl and (not _closed() or _flexible()) and pts.size() >= 2:
					_finish(false)
					return
				if _near_first(m):
					_finish(true)
					return
				_add_point(_snapped(m))
				_lasso = true
			else:
				_lasso = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_backspace()
	elif event is InputEventMouseMotion and _lasso and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not pts.is_empty() and pts[pts.size() - 1].distance_to(m) >= ed.ep.lasso_step and not _near_first(m):
			_add_point(ed.snap(m) if not EdInput.alt() else m)


func key(event: InputEvent) -> bool:
	if pts.is_empty():
		if target_obj != null and EdInput.pressed(event, "ed_cancel"):
			_back_to_select()
			return true
		return false
	if EdInput.pressed(event, "ed_finish"):
		_finish(_closed() or (_flexible() and not allow_open))
		return true
	if EdInput.pressed(event, "ed_backspace", true) or EdInput.pressed(event, "ed_undo", true):
		_backspace()
		return true
	if EdInput.pressed(event, "ed_cancel"):
		_cancel()
		return true
	return false


func _backspace() -> void:
	if not pts.is_empty():
		pts.remove_at(pts.size() - 1)
	if pts.is_empty():
		attach = null


func _cancel() -> void:
	pts = PackedVector2Array()
	attach = null
	_lasso = false


func _back_to_select() -> void:
	var o := target_obj
	_cancel()
	target_obj = null
	replace = null
	ed.set_tool("select")
	if o != null and ed.level.objects.has(o):
		ed.set_selection([o])


func _finish(close: bool) -> void:
	if _flexible() and not close and not allow_open:
		close = true
	var is_closed := close if _flexible() else _closed()
	var clean := Geometry.merge_close(pts, maxf(ed.ep.merge_dist, 0.01), is_closed)
	var need := 3 if is_closed else 2
	if not _flexible():
		need = _min()
	if clean.size() < need:
		ed.say("Мало точек: нужно минимум %d" % need)
		return
	if target_obj != null:
		_finish_form(clean, is_closed)
		return
	var s: GeoShape = ed.new_shape(kind, clean, attach)
	if kind == GeoShape.Kind.PATH:
		s.closed = is_closed
	ed.add_items("shapes", [s], "Контур: " + GeoShape.KIND_TITLES[kind])
	if Geometry.self_intersects(clean, is_closed) and is_closed and kind != GeoShape.Kind.PATH:
		ed.say("Контур %s самопересекается — в игре он не будет создан. Поправьте точки." % s.uid)
	elif kind == GeoShape.Kind.PATH:
		ed.say("Путь %s: точек %d, %s. Выберите его у платформы пипеткой ⌖." % [s.uid, clean.size(), "замкнутый" if is_closed else "открытый"])
	else:
		ed.say("Контур %s: %s, точек %d%s" % [s.uid, GeoShape.KIND_TITLES[kind], clean.size(), (", привязан к " + attach.uid) if attach != null else ""])
	_cancel()


func _finish_form(clean: PackedVector2Array, is_closed: bool) -> void:
	var s: GeoShape = ed.new_role_shape(target_obj, target_role, clean, is_closed)
	var cmds: Array = []
	if replace != null and ed.level.shapes.has(replace):
		cmds.append(Commands.ListCmd.new(ed.level, "shapes", [replace], false))
	cmds.append(Commands.ListCmd.new(ed.level, "shapes", [s], true))
	ed.exec(Commands.Batch.new(cmds, "Форма объекта"))
	if is_closed and Geometry.self_intersects(clean, true):
		ed.say("Форма самопересекается — поправьте точки (тело по ней не построится).")
	else:
		ed.say("Форма «%s» объекта %s: точек %d, %s. Двойной клик по объекту — правка точек." % [GeoShape.ROLE_TITLES.get(target_role, target_role), target_obj.uid, clean.size(), "замкнутая" if is_closed else "открытая"])
	_cancel()
	target_obj = null
	replace = null
	ed.set_tool("select")
	ed.set_selection([s])


func draw_overlay(c: Node2D) -> void:
	var col: Color = ed.kind_color(kind) if target_obj == null else Color(1.0, 0.85, 0.55)
	var m: Vector2 = ed.mouse_world()
	var cur := _snapped(m) if not _lasso else m
	if target_obj != null and replace != null and ed.level.shapes.has(replace):
		var old: PackedVector2Array = ed.level.shape_world_points(replace)
		if replace.is_closed() and old.size() > 0:
			old.append(old[0])
		c.draw_polyline(old, Color(1, 1, 1, 0.25), c.w(1.0))
	if pts.is_empty():
		c.handle(ed.snap(m), Color(col, 0.6))
		return
	var lw: float = c.w(ed.ep.line_width)
	if pts.size() >= 2:
		c.draw_polyline(pts, col, lw)
	c.draw_line(pts[pts.size() - 1], cur, Color(col, 0.6), lw)
	if (_closed() or _flexible()) and pts.size() >= 2:
		c.draw_line(cur, pts[0], Color(col, 0.25), c.w(1.0))
	for i in range(pts.size()):
		var big := i == 0 and (_closed() or _flexible())
		var hot := big and _near_first(m)
		c.handle(pts[i], Color(1, 1, 0.3) if hot else (col if big else Color.WHITE), big)
	if attach != null:
		c.text(pts[0] + Vector2(c.w(8), -c.w(8)), "→ " + attach.uid, Color(1, 1, 1, 0.7), 11)
	# длина и угол текущего отрезка
	var d := cur - pts[pts.size() - 1]
	c.text(cur + Vector2(c.w(12), c.w(18)), "%d px  %d°" % [roundi(d.length()), roundi(rad_to_deg(atan2(-d.y, d.x)))], Color(1, 1, 1, 0.7), 11)
