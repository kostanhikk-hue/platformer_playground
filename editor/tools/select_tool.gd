extends "res://editor/tools/tool_base.gd"
## Выделение и правка (V).
##   Клик — выделить (повторный клик в то же место — следующий объект под курсором), рамка — несколько;
##   Shift — добавить, Ctrl — убрать. Перетаскивание — сдвиг (с привязкой к сетке, если включена).
##   У единственного выделенного контура — ручки точек: тянуть точку; клик по ребру — вставить точку
##   (с Ctrl — без перетаскивания); ПКМ по точке — удалить; Ctrl + рамка — выделить несколько точек.
##   У фона и арт-объекта — ручки углов: масштаб (Shift — без сохранения пропорций).
##   Без выделения — ручки рамки границ уровня.

enum S { IDLE, PRESS, MOVE, BOX, POINTS, BOX_POINTS, SCALE, BOUNDS, HANDLE }

var state := S.IDLE
var _press := Vector2.ZERO          ## мир
var _press_screen := Vector2.ZERO
var _cur := Vector2.ZERO
var _before: Array = []             ## [[ресурс, снимок]]
var _start_pos: Dictionary = {}     ## ресурс → position на старте перетаскивания
var _box_mode := 0                  ## 0 заменить, 1 добавить, 2 убрать
var _pending_pick = null            ## что выделить по отпусканию (клик без движения)
var _cycle_from := Vector2(INF, INF)
var _scale_item = null
var _scale_corner := 0
var _bounds_handle := -1
var _points_start := PackedVector2Array()
var _drag_index := -1
var _handle: Dictionary = {}
var _handle_obj: PlacedObject
var _handle_before: Dictionary = {}


func title() -> String:
	return "Выделение"


func hint() -> String:
	if ed.selection.size() == 1 and ed.selection[0] is GeoShape:
		var s: GeoShape = ed.selection[0]
		var tail := ", Esc — к объекту" if s.role != "" else ""
		return "тяни точку, клик по ребру — новая точка (Ctrl — без перетаскивания), ПКМ — удалить точку, Ctrl+рамка — несколько точек, стрелки — сдвиг" + tail
	if ed.selection.size() == 1 and ed.selection[0] is PlacedObject and not ed.level.role_shapes(ed.selection[0].uid).is_empty():
		return "двойной клик — правка формы объекта; тяни ручки — радиус / размер; X/Y — отразить"
	return "клик / рамка (Shift — добавить, Ctrl — убрать), повторный клик — следующий под курсором, X/Y — отразить, R — повернуть"


func deactivate() -> void:
	state = S.IDLE


func _drag_started() -> bool:
	return ed.get_viewport().get_mouse_position().distance_to(_press_screen) > ed.ep.handle_size * 0.5


func _single_shape() -> GeoShape:
	if ed.selection.size() == 1 and ed.selection[0] is GeoShape and ed.item_selectable(ed.selection[0]):
		return ed.selection[0]
	return null


func _point_at(s: GeoShape, p: Vector2) -> int:
	var wp: PackedVector2Array = ed.level.shape_world_points(s)
	var r: float = ed.px(ed.ep.handle_size)
	for i in range(wp.size() - 1, -1, -1):
		if wp[i].distance_to(p) <= r:
			return i
	return -1


## Ребро под курсором: [индекс начала, точка на ребре] или [].
func _edge_at(s: GeoShape, p: Vector2) -> Array:
	var wp: PackedVector2Array = ed.level.shape_world_points(s)
	var n := wp.size()
	var edges := n if s.is_closed() else n - 1
	var r: float = ed.px(ed.ep.handle_size)
	for i in range(edges):
		var c := Geometry2D.get_closest_point_to_segment(p, wp[i], wp[(i + 1) % n])
		if c.distance_to(p) <= r:
			return [i, c]
	return []


# ------------------------------------------------------------ мышь

func input(event: InputEvent) -> void:
	var m: Vector2 = ed.mouse_world()
	_cur = m
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click and _on_double(m):
				state = S.IDLE
				return
			if mb.pressed:
				_on_press(m, mb.position)
			else:
				_on_release(m)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_on_right(m)
	elif event is InputEventMouseMotion:
		_on_motion(m)


## Двойной клик по объекту с формой — правка формы (ручки точек).
func _on_double(m: Vector2) -> bool:
	for h in ed.hit_items(m):
		if h is PlacedObject and ed.enter_form_edit(h, m):
			return true
		if h is GeoShape and h.role != "":
			ed.set_selection([h])
			return true
	return false


func _on_press(m: Vector2, screen: Vector2) -> void:
	_press = m
	_press_screen = screen
	var ctrl := EdInput.ctrl()
	var shift := EdInput.shift()
	# 0. ручки объекта (радиус света, размер двери…)
	if ed.selection.size() == 1 and ed.selection[0] is PlacedObject and ed.item_selectable(ed.selection[0]):
		var o: PlacedObject = ed.selection[0]
		for h in ed.canvas.object_handles(o):
			if (h["pos"] as Vector2).distance_to(m) <= ed.px(ed.ep.handle_size):
				if h["kind"] == "door_dir":
					var cur := int(ed.prop(o, "open_dir", 0))
					_set_props(o, {"open_dir": (cur + 1) % 3}, "Дверь: как открывается")
					state = S.IDLE
					return
				_handle = h
				_handle_obj = o
				_handle_before = o.props.duplicate(true)
				state = S.HANDLE
				return
	# 1. точки единственного выделенного контура
	var s := _single_shape()
	if s != null:
		var pi := _point_at(s, m)
		if pi >= 0:
			if shift:
				if not ed.sel_points.has(pi):
					ed.sel_points.append(pi)
			elif not ed.sel_points.has(pi):
				ed.sel_points = [pi]
			_begin_points(s, pi)
			return
		var e := _edge_at(s, m)
		if not e.is_empty():
			var b := Commands.snap(s, ["points"])
			var local: Vector2 = ed.level.shape_xform(s).affine_inverse() * (e[1] as Vector2)
			var pts := s.points.duplicate()
			pts.insert(e[0] + 1, local)
			s.points = pts
			ed.sel_points = [e[0] + 1]
			if ctrl:
				ed.push_done(Commands.props_from(s, b, "Вставить точку"))
				return
			_before = [[s, b]]
			_points_start = s.points.duplicate()
			_drag_index = e[0] + 1
			state = S.POINTS
			ed.refresh_view()
			return
		if ctrl:
			state = S.BOX_POINTS
			return
	# 2. ручки масштаба фона / арт-объекта
	if ed.selection.size() == 1:
		var it = ed.selection[0]
		if (it is BackgroundLayer or ed.is_art(it)) and ed.layer_editable(ed.item_layer(it)):
			var hs: PackedVector2Array = ed.canvas.scale_handles(it)
			for i in range(hs.size()):
				if hs[i].distance_to(m) <= ed.px(ed.ep.handle_size):
					_scale_item = it
					_scale_corner = i
					_before = [[it, Commands.snap(it, ["position", "scale"])]]
					state = S.SCALE
					return
	# 3. ручки границ уровня
	if ed.selection.is_empty() and ed.layer_editable(LevelData.Layer.SERVICE):
		var bh: Array = ed.canvas.bounds_handles()
		for i in range(bh.size()):
			if (bh[i] as Vector2).distance_to(m) <= ed.px(ed.ep.handle_size):
				_bounds_handle = i
				_before = [[ed.level, Commands.snap(ed.level, ["bounds"])]]
				state = S.BOUNDS
				return
	# 4. объекты под курсором
	var hits: Array = ed.hit_items(m)
	if hits.is_empty():
		_box_mode = 1 if shift else (2 if ctrl else 0)
		state = S.BOX
		return
	if ctrl:
		var rem: Array = ed.selection.duplicate()
		for h in hits:
			if rem.has(h):
				rem.erase(h)
				break
		ed.set_selection(rem)
		state = S.IDLE
		return
	var under_sel = null
	for h in hits:
		if ed.selection.has(h):
			under_sel = h
			break
	if shift:
		var add: Array = ed.selection.duplicate()
		for h in hits:
			if not add.has(h):
				add.append(h)
				break
		ed.set_selection(add)
	elif under_sel == null:
		ed.set_selection([hits[0]])
		_cycle_from = Vector2(INF, INF)
	else:
		# клик по уже выделенному: на отпускании без движения — следующий под курсором
		_pending_pick = hits
	state = S.PRESS


func _begin_points(s: GeoShape, idx: int) -> void:
	_before = [[s, Commands.snap(s, ["points"])]]
	_points_start = s.points.duplicate()
	_drag_index = idx
	state = S.POINTS


func _begin_move() -> void:
	_before.clear()
	_start_pos.clear()
	for r in ed.moveable_selection():
		if not ed.item_selectable(r):
			continue
		_before.append([r, Commands.snap(r, ["position"])])
		_start_pos[r] = r.position
	state = S.MOVE


func _on_motion(m: Vector2) -> void:
	match state:
		S.PRESS:
			if _drag_started():
				_pending_pick = null
				_begin_move()
				_on_motion(m)
		S.MOVE:
			var delta := m - _press
			if not _start_pos.is_empty() and ed.grid_snap and not EdInput.alt():
				var first = _start_pos.keys()[0]
				var target: Vector2 = ed.snap_grid(_world_pos(first, _start_pos[first]) + delta)
				delta = target - _world_pos(first, _start_pos[first])
			for r in _start_pos:
				r.position = _start_pos[r] + ed.move_delta_for(r, delta)
			ed.refresh_view()
		S.POINTS:
			var s: GeoShape = ed.selection[0]
			var inv: Transform2D = ed.level.shape_xform(s).affine_inverse()
			var anchor_world: Vector2 = ed.level.shape_xform(s) * _points_start[_drag_index]
			var prev = null
			if _drag_index > 0:
				prev = ed.level.shape_xform(s) * _points_start[_drag_index - 1]
			var target: Vector2 = ed.snap(m, prev, s, _drag_index)
			var delta_local: Vector2 = inv * target - inv * anchor_world
			var pts := _points_start.duplicate()
			for i in ed.sel_points:
				if i < pts.size():
					pts[i] = _points_start[i] + delta_local
			s.points = pts
			ed.refresh_view()
		S.SCALE:
			_apply_scale(m)
			ed.refresh_view()
		S.BOUNDS:
			_apply_bounds(m)
			ed.refresh_view()
		S.HANDLE:
			_apply_handle(m)
			ed.refresh_view()


func _world_pos(r: Resource, pos: Vector2) -> Vector2:
	if r is GeoShape and r.parent_uid != "":
		var parent: PlacedObject = ed.level.find_object(r.parent_uid)
		if parent != null:
			return LevelData.object_xform(parent) * pos
	return pos


func _on_release(m: Vector2) -> void:
	match state:
		S.PRESS:
			if _pending_pick != null:
				var hits: Array = _pending_pick
				if hits.size() > 1 and _press.distance_to(_cycle_from) < ed.px(ed.ep.handle_size):
					var cur = ed.selection[0] if not ed.selection.is_empty() else null
					var i := hits.find(cur)
					ed.set_selection([hits[(i + 1) % hits.size()]])
				elif ed.selection.size() > 1:
					ed.set_selection([hits.filter(func(h): return ed.selection.has(h))[0]])
				_cycle_from = _press
			else:
				_cycle_from = _press
			_pending_pick = null
		S.HANDLE:
			if _handle.get("global", false):
				pass
			elif _handle_obj != null and _handle_obj.props != _handle_before:
				ed.push_done(Commands.PropsCmd.new(_handle_obj, {"props": _handle_before}, {"props": _handle_obj.props.duplicate(true)}, "Ручка"))
			_handle = {}
		S.MOVE, S.POINTS, S.SCALE, S.BOUNDS:
			var cmds: Array = []
			for pair in _before:
				var c = Commands.props_from(pair[0], pair[1], "Правка")
				if c != null:
					cmds.append(c)
			if not cmds.is_empty():
				ed.push_done(Commands.Batch.new(cmds, "Правка"))
			_before.clear()
		S.BOX:
			var r := Rect2(_press, m - _press).abs()
			if r.size.length() < ed.px(ed.ep.handle_size * 0.5):
				if _box_mode == 0:
					ed.set_selection([])
			else:
				var inside: Array = ed.items_in_rect(r)
				var sel: Array = ed.selection.duplicate() if _box_mode != 0 else []
				for it in inside:
					if _box_mode == 2:
						sel.erase(it)
					elif not sel.has(it):
						sel.append(it)
				ed.set_selection(sel)
		S.BOX_POINTS:
			var s := _single_shape()
			if s != null:
				var r := Rect2(_press, m - _press).abs()
				var wp: PackedVector2Array = ed.level.shape_world_points(s)
				var pick: Array = []
				for i in range(wp.size()):
					if r.has_point(wp[i]):
						pick.append(i)
				ed.sel_points = pick
	state = S.IDLE


func _on_right(m: Vector2) -> void:
	var s := _single_shape()
	if s == null:
		return
	var pi := _point_at(s, m)
	if pi < 0:
		return
	if s.points.size() <= s.min_points():
		ed.say("Нельзя удалить точку: у контура «%s» минимум %d" % [GeoShape.KIND_TITLES[s.kind], s.min_points()])
		return
	var b := Commands.snap(s, ["points"])
	var pts := s.points.duplicate()
	pts.remove_at(pi)
	s.points = pts
	ed.sel_points.clear()
	ed.push_done(Commands.props_from(s, b, "Удалить точку"))


func key(event: InputEvent) -> bool:
	var s := _single_shape()
	if s != null and not ed.sel_points.is_empty() and EdInput.pressed(event, "ed_delete"):
		var left: int = s.points.size() - ed.sel_points.size()
		if left < s.min_points():
			ed.say("Нельзя: останется %d точек, минимум %d" % [left, s.min_points()])
			return true
		var b := Commands.snap(s, ["points"])
		var pts := PackedVector2Array()
		for i in range(s.points.size()):
			if not ed.sel_points.has(i):
				pts.append(s.points[i])
		s.points = pts
		ed.sel_points.clear()
		ed.push_done(Commands.props_from(s, b, "Удалить точки"))
		return true
	return false


# ------------------------------------------------------------ ручки объектов

func _set_props(o: PlacedObject, vals: Dictionary, n: String) -> void:
	var before: Dictionary = o.props.duplicate(true)
	var after: Dictionary = o.props.duplicate(true)
	for k in vals:
		after[k] = vals[k]
	ed.exec(Commands.PropsCmd.new(o, {"props": before}, {"props": after}, n))


func _apply_handle(m: Vector2) -> void:
	var h := _handle
	var c: Vector2 = h["center"]
	match h["kind"]:
		"radius":
			var r := snappedf(maxf(c.distance_to(m), 4.0), 1.0)
			if h.get("global", false):
				Params.get_res(h["res"]).set(h["prop"], r)
				ed.say("%s: %d px (общий параметр — сохраните на вкладке «%s»)" % [h["title"], int(r), h["tab"]])
			else:
				var p := _handle_obj.props.duplicate(true)
				p[h["prop"]] = r
				_handle_obj.props = p
		"size":
			var d := (m - c).abs() * 2.0
			var p := _handle_obj.props.duplicate(true)
			if h.has("w"):
				p[h["w"]] = snappedf(maxf(d.x, 8.0), 2.0 if not ed.grid_snap else ed.grid_step())
			if h.has("h"):
				p[h["h"]] = snappedf(maxf(d.y, 8.0), 2.0 if not ed.grid_snap else ed.grid_step())
			_handle_obj.props = p


# ------------------------------------------------------------ масштаб и границы

func _apply_scale(m: Vector2) -> void:
	var it = _scale_item
	var free := EdInput.shift()
	if it is BackgroundLayer:
		var b0: Dictionary = _before[0][1]
		var full: Vector2 = ed.bg_size(it) / it.scale   # размер картинки без масштаба
		var sc0: Vector2 = b0["scale"]
		var p0: Vector2 = b0["position"]
		var size0 := full * sc0
		var corners := [p0, p0 + Vector2(size0.x, 0), p0 + size0, p0 + Vector2(0, size0.y)]
		var fixed: Vector2 = corners[(_scale_corner + 2) % 4]
		var dragged: Vector2 = corners[_scale_corner]
		var d0 := dragged - fixed
		var d := m - fixed
		var k := Vector2(d.x / d0.x if absf(d0.x) > 0.001 else 1.0, d.y / d0.y if absf(d0.y) > 0.001 else 1.0)
		if not free:
			var u := maxf(k.x, k.y)
			k = Vector2(u, u)
		k = Vector2(maxf(k.x, 0.01), maxf(k.y, 0.01))
		it.scale = sc0 * k
		var size1: Vector2 = full * it.scale
		var signs := Vector2(signf(d0.x), signf(d0.y))
		it.position = Vector2(fixed.x if signs.x > 0 else fixed.x - size1.x, fixed.y if signs.y > 0 else fixed.y - size1.y)
	else:
		var b0: Dictionary = _before[0][1]
		var sc0: Vector2 = b0["scale"]
		var half: Vector2 = ed.object_local_size(it) * 0.5
		var rot: float = deg_to_rad(it.rotation_deg)
		var local: Vector2 = (m - it.position).rotated(-rot)
		var k := Vector2(absf(local.x) / maxf(half.x * absf(sc0.x), 0.001), absf(local.y) / maxf(half.y * absf(sc0.y), 0.001))
		if not free:
			var u := maxf(k.x, k.y)
			k = Vector2(u, u)
		it.scale = Vector2(maxf(absf(sc0.x) * k.x, 0.01), maxf(absf(sc0.y) * k.y, 0.01))


func _apply_bounds(m: Vector2) -> void:
	var b0: Rect2 = _before[0][1]["bounds"]
	var p: Vector2 = ed.snap_grid(m) if ed.grid_snap and not EdInput.alt() else m
	var l := b0.position.x
	var t := b0.position.y
	var r := b0.end.x
	var bt := b0.end.y
	match _bounds_handle:
		0: l = p.x; t = p.y
		1: t = p.y
		2: r = p.x; t = p.y
		3: r = p.x
		4: r = p.x; bt = p.y
		5: bt = p.y
		6: l = p.x; bt = p.y
		7: l = p.x
	ed.level.bounds = Rect2(Vector2(minf(l, r), minf(t, bt)), Vector2(absf(r - l), absf(bt - t)))


func draw_overlay(c: Node2D) -> void:
	if state == S.BOX or state == S.BOX_POINTS:
		var r := Rect2(_press, _cur - _press).abs()
		var col: Color = ed.ep.select_color if state == S.BOX else Color(1, 0.85, 0.2)
		c.draw_rect(r, Color(col, 0.12))
		c.draw_rect(r, col, false, c.w(1.0))
	if state == S.MOVE and not _start_pos.is_empty():
		var first = _start_pos.keys()[0]
		var d: Vector2 = _world_pos(first, first.position) - _world_pos(first, _start_pos[first])
		c.text(_cur + Vector2(c.w(14), c.w(18)), "Δ %d, %d px" % [roundi(d.x), roundi(d.y)], Color(1, 1, 1, 0.8), 11)
