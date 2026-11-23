extends "res://game/components/component_base.gd"
## Закрашивание (Coverage): поверхность, которую закрашивают штрихи и удары. Основа боссов «победить — закрасить».
## Область — сетка ячеек cell_size (вкладка «Закраска») внутри контура area (или только внутри уязвимых мест weak).
## Ячейка закрашена, если до штриха ≤ толщина/2 × paint_strength, или она в прямоугольнике удара.
## Отмывание: wash_rate % покрытия в секунду сходит само. Пороги — события painted_percent {value},
## 100 % — painted_full и действие on_full; отмывание ниже порога — washed_below {value}.
## Может жить внутри другого объекта (манекен-холст) — тогда двигается вместе с ним.

var cp: Resource
var area := PackedVector2Array()
var weak: Array = []
var cells := PackedVector2Array()     ## центры ячеек (локально)
var painted := PackedByteArray()
var cell_col: Array = []
var _blob: PackedFloat32Array = PackedFloat32Array()   ## размер пятна
var _jit := PackedVector2Array()
var _grid := PackedInt32Array()
var _cols := 0
var _rows := 0
var _origin := Vector2.ZERO
var _cell := 8.0
var count := 0
var _reported := {}
var _full := false
var _wash_acc := 0.0
var _strokes: Array = []
var owner_node: Node = null          ## владелец (для «Уничтожить владельца»)
var _thr: Array = []


func _setup(ctx: Dictionary) -> void:
	cp = Params.get_res("coverage")
	var a: Array = shapes.get("area", [])
	if not a.is_empty():
		area = a[0]["points"]
	weak = []
	for w in shapes.get("weak", []):
		if w["closed"] and (w["points"] as PackedVector2Array).size() >= 3:
			weak.append(w["points"])
	if ctx.has("owner_node"):
		owner_node = ctx["owner_node"]
	_build_cells()
	Events.stroke_spawned.connect(_on_stroke)
	Events.hit_area.connect(_on_hit_area)


func _exit_tree() -> void:
	if Events.stroke_spawned.is_connected(_on_stroke):
		Events.stroke_spawned.disconnect(_on_stroke)
	if Events.hit_area.is_connected(_on_hit_area):
		Events.hit_area.disconnect(_on_hit_area)


func _ready() -> void:
	super()
	if props.owner_uid != "" and owner_node == null:
		_attach.call_deferred()


func _attach() -> void:
	if runtime == null:
		return
	var o: Node = runtime.get_component(props.owner_uid)
	if o == null or o == self:
		return
	owner_node = o
	var g := global_position
	get_parent().remove_child(self)
	o.add_child(self)
	global_position = g


func _apply() -> void:
	_thr = []
	for part in str(props.thresholds).split(",", false):
		var v := part.strip_edges()
		if v.is_valid_float():
			_thr.append(clampi(int(float(v)), 1, 100))
	_thr.sort()


func _build_cells() -> void:
	cells = PackedVector2Array()
	if area.size() < 3:
		return
	_cell = maxf(cp.cell_size, 2.0)
	var r := Rect2(area[0], Vector2.ZERO)
	for q in area:
		r = r.expand(q)
	_origin = r.position
	_cols = clampi(int(ceil(r.size.x / _cell)), 1, 400)
	_rows = clampi(int(ceil(r.size.y / _cell)), 1, 400)
	_grid = PackedInt32Array()
	_grid.resize(_cols * _rows)
	_grid.fill(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid)
	for y in range(_rows):
		for x in range(_cols):
			var c := _origin + Vector2(x + 0.5, y + 0.5) * _cell
			if not Geometry2D.is_point_in_polygon(c, area):
				continue
			if not weak.is_empty():
				var inside := false
				for w in weak:
					if Geometry2D.is_point_in_polygon(c, w):
						inside = true
						break
				if not inside:
					continue
			_grid[x + y * _cols] = cells.size()
			cells.append(c)
			_blob.append(rng.randf_range(-1.0, 1.0))
			_jit.append(Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)))
	painted = PackedByteArray()
	painted.resize(cells.size())
	painted.fill(0)
	cell_col.resize(cells.size())
	count = 0


func percent() -> float:
	return 0.0 if cells.is_empty() else 100.0 * count / cells.size()


func _on_stroke(s: Node) -> void:
	_strokes.append(weakref(s))


func _accepts(kind: String) -> bool:
	match kind:
		"ink": return props.accept_ink
		"wave": return props.accept_wave
		"melee": return props.accept_melee
	return false


func _on_hit_area(rect: Rect2, kind: String, _source: Node) -> void:
	if not active or _full or not _accepts(kind) or not is_inside_tree():
		return
	var pad: float = cp.melee_pad
	var inv := global_transform.affine_inverse()
	var a: Vector2 = inv * rect.position
	var b: Vector2 = inv * rect.end
	var lr := Rect2(a, Vector2.ZERO).expand(b).grow(pad)
	var changed := false
	var x0 := clampi(int(floor((lr.position.x - _origin.x) / _cell)), 0, _cols - 1)
	var x1 := clampi(int(floor((lr.end.x - _origin.x) / _cell)), 0, _cols - 1)
	var y0 := clampi(int(floor((lr.position.y - _origin.y) / _cell)), 0, _rows - 1)
	var y1 := clampi(int(floor((lr.end.y - _origin.y) / _cell)), 0, _rows - 1)
	if lr.end.x < _origin.x or lr.end.y < _origin.y or lr.position.x > _origin.x + _cols * _cell or lr.position.y > _origin.y + _rows * _cell:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var id := _grid[x + y * _cols]
			if id >= 0 and painted[id] == 0 and lr.has_point(cells[id]):
				painted[id] = 1
				cell_col[id] = cp.melee_color
				count += 1
				changed = true
	if changed:
		_after_change(true)


func _physics_process(delta: float) -> void:
	super(delta)
	if cells.is_empty() or not active:
		_strokes.clear()
		return
	var changed := false
	var up := false
	if not _full:
		var inv := global_transform.affine_inverse()
		var alive: Array = []
		for w in _strokes:
			var s = w.get_ref()
			if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
				continue
			alive.append(w)
			var poly: Dictionary = s.get_world_polyline()
			if not _accepts(poly["kind"]):
				continue
			var pts: PackedVector2Array = inv * (poly["points"] as PackedVector2Array)
			var r: float = float(poly["thickness"]) * 0.5 * props.paint_strength
			var col: Color = s.p.color if s.get("p") != null else cp.paint_color
			for j in range(pts.size() - 1):
				if _paint_segment(pts[j], pts[j + 1], r, col):
					changed = true
					up = true
		_strokes = alive
	if props.wash_rate > 0.0 and count > 0:
		_wash_acc += props.wash_rate / 100.0 * cells.size() * delta
		while _wash_acc >= 1.0 and count > 0:
			_wash_acc -= 1.0
			_unpaint_random()
			changed = true
	if changed:
		_after_change(up)


func _paint_segment(a: Vector2, b: Vector2, r: float, col: Color) -> bool:
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(r)
	if box.end.x < _origin.x or box.end.y < _origin.y or box.position.x > _origin.x + _cols * _cell or box.position.y > _origin.y + _rows * _cell:
		return false
	var x0 := clampi(int(floor((box.position.x - _origin.x) / _cell)), 0, _cols - 1)
	var x1 := clampi(int(floor((box.end.x - _origin.x) / _cell)), 0, _cols - 1)
	var y0 := clampi(int(floor((box.position.y - _origin.y) / _cell)), 0, _rows - 1)
	var y1 := clampi(int(floor((box.end.y - _origin.y) / _cell)), 0, _rows - 1)
	var changed := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var id := _grid[x + y * _cols]
			if id < 0 or painted[id] == 1:
				continue
			if Geometry2D.get_closest_point_to_segment(cells[id], a, b).distance_to(cells[id]) <= r:
				painted[id] = 1
				cell_col[id] = col if cp.use_stroke_color else cp.paint_color
				count += 1
				changed = true
	return changed


func _unpaint_random() -> void:
	var n := cells.size()
	var start := randi() % n
	for k in range(n):
		var id := (start + k) % n
		if painted[id] == 1:
			painted[id] = 0
			count -= 1
			return


func _after_change(_up: bool) -> void:
	queue_redraw()
	var pct := percent()
	for t in _thr:
		if pct >= t - 0.0001 and not _reported.has(t):
			_reported[t] = true
			emit_event("painted_percent", {"value": t})
		elif pct < t - 0.0001 and _reported.has(t):
			_reported.erase(t)
			emit_event("washed_below", {"value": t})
	if pct >= 99.999 and not _full:
		_full = true
		emit_event("painted_full")
		match int(props.on_full):
			1:
				_destroy_owner()
			2:
				links_pulse()
				links_state(true)
	elif pct < 99.999 and _full:
		_full = false
		if int(props.on_full) == 2:
			links_state(false)


func _destroy_owner() -> void:
	var o := owner_node if owner_node != null else get_parent()
	if o != null and o.has_method("vanish"):
		o.vanish()
	elif owner_node == null:
		visible = false
		active = false


func _snap() -> Dictionary:
	return {"painted": painted.duplicate(), "count": count, "rep": _reported.duplicate(), "full": _full}


func _restore(d: Dictionary) -> void:
	var p: PackedByteArray = d.get("painted", PackedByteArray())
	if p.size() == painted.size():
		painted = p.duplicate()
	count = d.get("count", 0)
	_reported = d.get("rep", {}).duplicate()
	_full = d.get("full", false)
	_strokes.clear()
	visible = true
	queue_redraw()


func _draw() -> void:
	if cells.is_empty():
		return
	if cp.show_area and area.size() >= 3:
		var o := area.duplicate()
		o.append(area[0])
		draw_polyline(o, Color(1, 1, 1, cp.area_alpha), 1.0)
		for w in weak:
			var wo: PackedVector2Array = (w as PackedVector2Array).duplicate()
			wo.append(w[0])
			draw_polyline(wo, Color(1, 0.6, 0.4, cp.area_alpha * 1.5), 1.5)
	var base: float = _cell * cp.blob_size * 0.5
	var jit: float = cp.blob_jitter
	for i in range(cells.size()):
		if painted[i] == 0:
			continue
		var c: Color = cell_col[i] if cell_col[i] is Color else cp.paint_color
		draw_circle(cells[i] + _jit[i] * _cell * jit, maxf(base * (1.0 + _blob[i] * jit * 0.6), 0.5), Color(c, cp.paint_alpha))
	_draw_debug()


func _debug() -> String:
	return "закрашено %d%% (%d/%d)%s" % [roundi(percent()), count, cells.size(), ", отмывается %.1f%%/с" % props.wash_rate if props.wash_rate > 0.0 else ""]
