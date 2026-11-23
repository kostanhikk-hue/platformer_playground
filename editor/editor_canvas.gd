extends Node2D
## Холст конструктора: сетка, границы, контуры коллизии с подсказками, объекты, выделение, ручки.
## Картинки (фоны, арт-объекты) — отдельные спрайты в level_editor; здесь — всё, что рисуется поверх.
## Размеры ручек и толщины линий заданы в экранных пикселях (вкладка «Редактор») и не зависят от масштаба.

const Geometry := preload("res://core/geometry.gd")
const ObjectDraw := preload("res://editor/object_draw.gd")
const T := 32.0
## Цвета линий связей по режиму: Включить, Выключить, Переключить, Следовать.
const LINK_COLORS := [Color(0.45, 1.0, 0.5), Color(1.0, 0.45, 0.4), Color(1.0, 0.85, 0.3), Color(0.45, 0.75, 1.0)]

var ed
var _cache := {}        ## контур → {pts, bad, hatch}
var _cache_zoom := -1.0


func invalidate() -> void:
	_cache.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	# ручки и предпросмотр следуют за курсором
	queue_redraw()


func _draw() -> void:
	if ed == null or ed.level == null or ed.runtime != null:
		return
	if not is_equal_approx(_cache_zoom, ed.zoom()):
		_cache.clear()
		_cache_zoom = ed.zoom()
	var pv: bool = ed.player_view
	if ed.show_grid and not pv:
		_draw_grid()
	if ed.layer_visible(LevelData.Layer.SERVICE):
		_draw_bounds()
	for b in ed.level.backgrounds:
		if ed.selection.has(b):
			_outline_rect(ed.bg_rect(b), ed.ep.select_color)
	var bad: Dictionary = ed.problem_uids()
	if ed.show_collision and not pv and ed.layer_visible(LevelData.Layer.GAMEPLAY):
		for s in ed.level.shapes:
			if s.role == "" and s.kind != GeoShape.Kind.PATH:
				_draw_shape(s, bad.has(s.uid))
	if not pv and ed.layer_visible(LevelData.Layer.SERVICE):
		for s in ed.level.shapes:
			if s.kind == GeoShape.Kind.PATH:
				_draw_path(s, bad.has(s.uid))
	for o in ed.level.objects:
		if ed.layer_visible(ed.item_layer(o)):
			_draw_object(o)
	for s in ed.level.shapes:
		if s.role != "" and ed.layer_visible(ed.item_layer(s)):
			_draw_role_shape(s, bad.has(s.uid))
	if not pv:
		_draw_links()
		_draw_selection()
		_draw_object_handles()
	if ed.tool != null:
		ed.tool.draw_overlay(self)
	_draw_hero_ghost()


# ------------------------------------------------------------ вспомогательные

func w(screen_px: float) -> float:
	return ed.px(screen_px)


## Текст постоянного экранного размера.
func text(pos: Vector2, s: String, col: Color, size: int = 12) -> void:
	var k: float = 1.0 / ed.zoom()
	draw_set_transform(pos, 0.0, Vector2(k, k))
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func handle(p: Vector2, col: Color, big: bool = false) -> void:
	var r: float = w(ed.ep.first_point_size if big else ed.ep.handle_size) * 0.5
	draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), col)
	draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Color(0, 0, 0, 0.8), false, w(1.0))


func _outline_rect(r: Rect2, col: Color) -> void:
	draw_rect(r, col, false, w(2.0))


func _outline_poly(pts: PackedVector2Array, col: Color, width: float) -> void:
	if pts.size() < 2:
		return
	var c := pts.duplicate()
	c.append(pts[0])
	draw_polyline(c, col, width)


# ------------------------------------------------------------ сетка и границы

func _draw_grid() -> void:
	var vr: Rect2 = ed.view_rect()
	var step := T
	var coarse: bool = ed.zoom() < ed.ep.grid_coarse_zoom
	if coarse:
		step = T * maxi(ed.ep.grid_coarse_every, 1)
	var a: float = ed.ep.grid_alpha
	var minor := Color(1, 1, 1, a * 0.5)
	var major := Color(1, 1, 1, a)
	var x0 := floorf(vr.position.x / step) * step
	var y0 := floorf(vr.position.y / step) * step
	var lw := w(1.0)
	var x := x0
	while x <= vr.end.x:
		var is_major := is_zero_approx(fmod(absf(x), T * 5.0)) or coarse
		draw_line(Vector2(x, vr.position.y), Vector2(x, vr.end.y), major if is_major else minor, lw)
		x += step
	var y := y0
	while y <= vr.end.y:
		var is_major := is_zero_approx(fmod(absf(y), T * 5.0)) or coarse
		draw_line(Vector2(vr.position.x, y), Vector2(vr.end.x, y), major if is_major else minor, lw)
		y += step
	# подписи в тайлах по верхнему и левому краю вида
	var label_step := step * (1.0 if coarse else 5.0)
	var col := Color(1, 1, 1, 0.45)
	x = floorf(vr.position.x / label_step) * label_step
	while x <= vr.end.x:
		text(Vector2(x + w(2), vr.position.y + w(12)), "%d T" % roundi(x / T), col, 11)
		x += label_step
	y = floorf(vr.position.y / label_step) * label_step
	while y <= vr.end.y:
		text(Vector2(vr.position.x + w(4), y - w(2)), "%d T" % roundi(y / T), col, 11)
		y += label_step


func _draw_bounds() -> void:
	var b: Rect2 = ed.level.bounds
	var col := Color(1.0, 0.8, 0.35, 0.9)
	draw_rect(b, col, false, w(2.0))
	text(b.position + Vector2(0, -w(6)), "границы уровня %d×%d T" % [roundi(b.size.x / T), roundi(b.size.y / T)], col, 12)
	var ky: float = ed.level.kill_y
	var kc := Color(1, 0.3, 0.3, 0.7)
	var xs := b.position.x
	while xs < b.end.x:
		draw_line(Vector2(xs, ky), Vector2(minf(xs + w(10), b.end.x), ky), kc, w(1.5))
		xs += w(18)
	text(Vector2(b.position.x + w(4), ky - w(4)), "kill_y", kc, 11)
	if ed.tool_name == "select" and ed.selection.is_empty() and ed.layer_editable(LevelData.Layer.SERVICE):
		for p in bounds_handles():
			handle(p, col)


## Ручки рамки границ: углы и середины сторон (по часовой от левого верхнего).
func bounds_handles() -> Array:
	var b: Rect2 = ed.level.bounds
	var c := b.get_center()
	return [b.position, Vector2(c.x, b.position.y), Vector2(b.end.x, b.position.y), Vector2(b.end.x, c.y),
		b.end, Vector2(c.x, b.end.y), Vector2(b.position.x, b.end.y), Vector2(b.position.x, c.y)]


# ------------------------------------------------------------ контуры

func _shape_info(s: GeoShape) -> Dictionary:
	if _cache.has(s):
		return _cache[s]
	var pts: PackedVector2Array = ed.level.shape_world_points(s)
	var closed := s.is_closed()
	var bad := closed and Geometry.self_intersects(pts, true)
	var hatch: Array = []
	if closed and not bad and pts.size() >= 3:
		var r := Geometry.bbox(pts)
		var sp := w(ed.ep.hatch_spacing)
		var d := r.size.x + r.size.y
		var t := -r.size.y
		var guard := 0
		while t < r.size.x and guard < 2000:
			var a := Vector2(r.position.x + t, r.end.y)
			var b := a + Vector2(d, -d)
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), pts):
				hatch.append(seg)
			t += sp
			guard += 1
	var info := {"pts": pts, "bad": bad, "hatch": hatch, "fill_ok": closed and not bad and not Geometry2D.triangulate_polygon(pts).is_empty()}
	_cache[s] = info
	return info


func _draw_shape(s: GeoShape, problem: bool) -> void:
	var info := _shape_info(s)
	var pts: PackedVector2Array = info["pts"]
	if pts.is_empty():
		return
	var ep: Resource = ed.ep
	var alpha: float = ed.layers[LevelData.Layer.GAMEPLAY]["alpha"]
	var col: Color = s.color
	if s.material == GeoShape.Mat.ICE:
		col = col.lerp(ep.ice_color, 0.6)
	col.a *= alpha
	var lw := w(ep.line_width)
	var closed := s.is_closed()
	if closed:
		if info["fill_ok"]:
			draw_colored_polygon(pts, Color(col, ep.fill_alpha * alpha))
		for seg in info["hatch"]:
			draw_polyline(seg, Color(col, 0.35 * alpha), w(1.0))
		_outline_poly(pts, col, lw)
		_steep_edges_closed(pts, alpha)
	else:
		_draw_chain(s, pts, col, alpha)
	if info["bad"] or problem:
		var c := Geometry.bbox(pts).get_center()
		if info["bad"]:
			_outline_poly(pts, ep.error_color, lw * 1.5)
		draw_circle(c, w(9), ep.error_color)
		text(c + Vector2(-w(3), w(5)), "!", Color.WHITE, 14)
	if s.parent_uid != "":
		# привязанный контур: тонкая линия к центру арт-объекта
		var parent: PlacedObject = ed.level.find_object(s.parent_uid)
		if parent != null and ed.selection.has(s):
			draw_line(Geometry.bbox(pts).get_center(), parent.position, Color(1, 1, 1, 0.35), w(1.0))


## Рёбра тела, на которых нельзя стоять: смотрят вверх и круче «Макс. угла склона» героя.
func _steep_edges_closed(pts: PackedVector2Array, alpha: float) -> void:
	var max_slope: float = Params.get_res("movement").max_slope_deg
	var wall: float = ed.ep.steep_wall_deg
	var sgn := 1.0 if Geometry.signed_area(pts) > 0.0 else -1.0
	var n := pts.size()
	for i in range(n):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		if d.length() < 0.01:
			continue
		var outward := Vector2(d.y, -d.x).normalized() * sgn
		if outward.y >= 0.0:
			continue   # смотрит вниз или вбок — не пол
		var slope := Geometry.slope_deg(a, b)
		if slope > max_slope and slope < wall:
			draw_line(a, b, Color(ed.ep.steep_color, alpha), w(ed.ep.line_width * 2.0))


func _draw_chain(s: GeoShape, pts: PackedVector2Array, col: Color, alpha: float) -> void:
	var ep: Resource = ed.ep
	var max_slope: float = Params.get_res("movement").max_slope_deg
	var t := maxf(s.thickness, 1.0)
	var is_platform := s.kind == GeoShape.Kind.PLATFORM
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var slope := Geometry.slope_deg(a, b)
		var dn := Geometry.down_normal(a, b)
		var seg_col := col
		var wall_part := not is_platform or slope >= s.solid_angle_deg
		if is_platform and wall_part:
			seg_col = Color(ep.wall_color, col.a)
		if slope > max_slope and slope < ep.steep_wall_deg:
			seg_col = Color(ep.steep_color, col.a)
		# тело отрезка (под линией — как в игре) и верхняя линия
		draw_colored_polygon(PackedVector2Array([a, b, b + dn * t, a + dn * t]), Color(seg_col, 0.25 * alpha))
		draw_line(a, b, seg_col, w(ep.line_width))
		# стрелки «можно запрыгнуть снизу»
		if is_platform and s.one_way and not wall_part:
			var len := a.distance_to(b)
			var count := clampi(int(len / w(48.0)), 1, 16)
			for k in range(count):
				var m := a.lerp(b, (k + 0.5) / count)
				var up := -dn
				var tip := m + up * w(9)
				var side := (b - a).normalized() * w(4)
				draw_line(m + up * w(2) - side, tip, seg_col, w(1.5))
				draw_line(m + up * w(2) + side, tip, seg_col, w(1.5))
	for p in pts:
		draw_circle(p, w(2.0), col)


# ------------------------------------------------------------ формы объектов, пути, связи

## Пунктир по ломаной (мировые точки), шаг — в экранных пикселях.
func dashed(pts: PackedVector2Array, col: Color, width: float, dash_px: float = 8.0, gap_px: float = 6.0) -> void:
	var dash := w(dash_px)
	var gap := w(gap_px)
	var period := dash + gap
	var run := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var l := a.distance_to(b)
		if l < 0.0001:
			continue
		var n := int(floor(run / period))
		var guard := 0
		while guard < 4000:
			guard += 1
			var s0 := n * period - run
			if s0 >= l:
				break
			var s1 := minf(s0 + dash, l)
			s0 = maxf(s0, 0.0)
			if s1 > s0:
				draw_line(a.lerp(b, s0 / l), a.lerp(b, s1 / l), col, width)
			n += 1
		run += l


func _draw_role_shape(s: GeoShape, problem: bool) -> void:
	var pts: PackedVector2Array = ed.level.shape_world_points(s)
	if pts.size() < 2:
		return
	var parent: PlacedObject = ed.level.find_object(s.parent_uid)
	var col: Color = s.color
	if parent != null:
		var d: ObjectDef = ed.def_of(parent)
		if d != null:
			col = d.editor_color
	if s.role == "weak":
		col = Color(1.0, 0.5, 0.35)
	var alpha: float = ed.layers[ed.item_layer(s)]["alpha"]
	col.a *= alpha
	var closed := s.is_closed()
	if closed and pts.size() >= 3 and not Geometry.self_intersects(pts, true) and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, Color(col, 0.08 * alpha))
	var o := pts.duplicate()
	if closed:
		o.append(pts[0])
	dashed(o, col, w(ed.ep.line_width), 9.0, 5.0)
	for p in pts:
		draw_circle(p, w(1.8), col)
	if problem or (closed and Geometry.self_intersects(pts, true)):
		var c := Geometry.bbox(pts).get_center()
		draw_circle(c, w(9), ed.ep.error_color)
		text(c + Vector2(-w(3), w(5)), "!", Color.WHITE, 14)
	if ed.selection.has(s):
		text(pts[0] + Vector2(w(6), -w(6)), GeoShape.ROLE_TITLES.get(s.role, s.role) + (" · замкнутая" if closed else " · открытая"), col.lightened(0.3), 11)


func _draw_path(s: GeoShape, problem: bool) -> void:
	var pts: PackedVector2Array = ed.level.shape_world_points(s)
	if pts.size() < 2:
		return
	var col: Color = ed.kind_color(GeoShape.Kind.PATH)
	col.a *= ed.layers[LevelData.Layer.SERVICE]["alpha"]
	var o := pts.duplicate()
	if s.closed:
		o.append(pts[0])
	dashed(o, col, w(2.0), 10.0, 6.0)
	for i in range(o.size() - 1):
		var a := o[i]
		var b := o[i + 1]
		if a.distance_to(b) < w(20):
			continue
		var m := a.lerp(b, 0.5)
		var d := (b - a).normalized()
		var n := d.orthogonal()
		draw_line(m, m - d * w(9) + n * w(5), col, w(2))
		draw_line(m, m - d * w(9) - n * w(5), col, w(2))
	for i in range(pts.size()):
		draw_circle(pts[i], w(4), col)
		text(pts[i] + Vector2(w(5), -w(5)), str(i), col, 11)
	text(pts[0] + Vector2(w(5), w(14)), "путь " + s.uid + (" (по кругу)" if s.closed else ""), Color(col, 0.8), 10)
	if problem:
		draw_circle(pts[0], w(9), ed.ep.error_color)


func _draw_links() -> void:
	var sel := {}
	for r in ed.selection:
		sel[r] = true
	for o in ed.level.objects:
		if not ed.show_links and not sel.has(o):
			continue
		for l in ed.links_of(o):
			var t: Resource = ed.level.find_any(l["to"])
			var from: Vector2 = o.position
			if t == null:
				draw_line(from, from + Vector2(w(30), -w(30)), ed.ep.error_color, w(2))
				text(from + Vector2(w(32), -w(32)), "? " + String(l["to"]), ed.ep.error_color, 11)
				continue
			var to: Vector2 = ed.item_center(t)
			if t is GeoShape and t.kind == GeoShape.Kind.PATH:
				to = ed.level.shape_world_points(t)[0]
			var col: Color
			match l["kind"]:
				"link", "lit":
					col = LINK_COLORS[clampi(int(l["mode"]), 0, 3)]
				_:
					col = Color(0.6, 0.85, 1.0, 0.7)
			if l["kind"] == "path" or l["kind"] == "ref" or l["kind"] == "lit":
				dashed(PackedVector2Array([from, to]), col, w(1.5), 6.0, 5.0)
			else:
				draw_line(from, to, col, w(2))
			var d := (to - from)
			if d.length() > w(16):
				var dn := d.normalized()
				var tip := to - dn * w(10)
				draw_line(tip, tip - dn * w(10) + dn.orthogonal() * w(6), col, w(2))
				draw_line(tip, tip - dn * w(10) - dn.orthogonal() * w(6), col, w(2))
			if l["kind"] == "link" or l["kind"] == "lit":
				var mid := from.lerp(to, 0.5)
				text(mid + Vector2(w(4), -w(4)), ("☀ " if l["kind"] == "lit" else "") + ["вкл", "выкл", "перекл", "следовать"][clampi(int(l["mode"]), 0, 3)], col, 10)


## Ручки выделенного объекта: [{pos, kind: radius/size/door_dir, center, prop…}].
func object_handles(o: PlacedObject) -> Array:
	var out: Array = []
	var d: ObjectDef = ed.def_of(o)
	if d == null:
		return out
	var c := o.position
	match d.kind:
		"light":
			var r: float = ed.prop(o, "radius", 200.0)
			out.append({"pos": c + Vector2(r, 0), "kind": "radius", "center": c, "prop": "radius", "title": "Радиус действия"})
			var vr: float = ed.prop(o, "view_radius", -1.0)
			if vr >= 0.0:
				out.append({"pos": c + Vector2(0, -vr), "kind": "radius", "center": c, "prop": "view_radius", "title": "Радиус света"})
		"door":
			var sz: Vector2 = ed.object_local_size(o)
			out.append({"pos": c + sz * 0.5, "kind": "size", "center": c, "w": "width", "h": "height"})
			out.append({"pos": c + Vector2(0, -sz.y * 0.5 - w(16)), "kind": "door_dir", "center": c})
		"exit", "atmosphere":
			var sz: Vector2 = ed.object_local_size(o)
			out.append({"pos": c + sz * 0.5, "kind": "size", "center": c, "w": "width", "h": "height"})
		"plate":
			out.append({"pos": c + Vector2(float(ed.prop(o, "width", 48.0)) * 0.5, 0), "kind": "size", "center": c, "w": "width"})
	if d.has_tag("interactive") or d.kind == "paintable":
		var ir: float = Params.get_res("interact").interact_radius
		out.append({"pos": c + Vector2(-ir, 0), "kind": "radius", "center": c, "prop": "interact_radius", "global": true,
			"res": "interact", "tab": "Взаимодействие", "title": "Радиус взаимодействия"})
	return out


func _draw_object_handles() -> void:
	if ed.selection.size() != 1 or not (ed.selection[0] is PlacedObject) or ed.tool_name != "select":
		return
	var o: PlacedObject = ed.selection[0]
	for h in object_handles(o):
		match h["kind"]:
			"radius":
				var r: float = (h["pos"] as Vector2).distance_to(h["center"])
				var col := Color(1, 0.8, 0.35, 0.55) if not h.get("global", false) else Color(0.7, 0.9, 1.0, 0.35)
				draw_arc(h["center"], r, 0, TAU, 64, col, w(1.5))
				draw_circle(h["pos"], w(5), Color(col, 1.0))
				text(h["pos"] + Vector2(w(7), -w(4)), "%s %d" % [h.get("title", ""), int(r)], Color(col, 0.9), 10)
			"size":
				handle(h["pos"], ed.ep.select_color)
			"door_dir":
				var p: Vector2 = h["pos"]
				var dir := int(ed.prop(o, "open_dir", 0))
				var col := Color(1, 0.85, 0.4)
				match dir:
					0:
						draw_line(p + Vector2(0, w(8)), p - Vector2(0, w(8)), col, w(2))
						draw_line(p - Vector2(0, w(8)), p - Vector2(w(5), w(2)), col, w(2))
						draw_line(p - Vector2(0, w(8)), p - Vector2(-w(5), w(2)), col, w(2))
					1:
						draw_line(p - Vector2(w(10), 0), p + Vector2(w(10), 0), col, w(2))
						draw_line(p - Vector2(w(10), 0), p - Vector2(w(5), w(4)), col, w(2))
						draw_line(p + Vector2(w(10), 0), p + Vector2(w(5), w(4)), col, w(2))
					_:
						draw_arc(p, w(7), 0, TAU, 16, col, w(1.5))
				text(p + Vector2(w(12), w(4)), ["вверх", "в стороны", "исчезнуть"][clampi(dir, 0, 2)] + " (клик)", col, 10)


# ------------------------------------------------------------ объекты

func _draw_object(o: PlacedObject) -> void:
	var def: ObjectDef = ed.def_of(o)
	var alpha: float = ed.layers[ed.item_layer(o)]["alpha"]
	if def == null:
		var r := Rect2(o.position - Vector2(16, 16), Vector2(32, 32))
		draw_rect(r, Color(1, 0, 0, 0.5 * alpha))
		text(o.position + Vector2(-16, -20), "? " + o.def_id, Color(1, 0.4, 0.4), 12)
		return
	if def.transformable:
		if ed.object_image(o) == "" or ed.object_local_size(o) == Vector2(T, T):
			_outline_poly(ed.object_world_poly(o), Color(1, 0.4, 0.4), w(2))
		return
	if ObjectDraw.draw(self, ed, o, def, alpha):
		return
	var sz: Vector2 = ed.object_local_size(o)
	var r := Rect2(o.position - sz * 0.5, sz)
	var col := Color(def.editor_color, def.editor_color.a * alpha)
	match o.def_id:
		"start":
			draw_rect(r, Color(col, 0.35 * alpha))
			draw_rect(r, col, false, w(2))
			text(r.position + Vector2(0, -w(4)), "СТАРТ", col, 12)
		"checkpoint":
			var foot := Vector2(o.position.x, r.end.y)
			draw_line(foot, foot - Vector2(0, sz.y * 0.8), Color(0.85, 0.85, 0.85, alpha), w(2))
			var top := foot - Vector2(0, sz.y * 0.8)
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(26, 9), top + Vector2(0, 18)]), col)
			draw_rect(r, Color(col, 0.4 * alpha), false, w(1))
		"exit":
			draw_rect(r, Color(col, 0.15 * alpha))
			draw_rect(r, col, false, w(2))
			text(r.position + Vector2(w(4), w(14)), "ВЫХОД", col, 12)
		"dummy":
			draw_rect(r, Color(col, 0.7 * alpha))
			draw_rect(r, Color(0, 0, 0, 0.6 * alpha), false, w(1.5))
			var facing := -1.0 if int(o.props.get("facing", 0)) == 1 else 1.0
			var beh: String = ["стоит", "патруль", "таран"][clampi(int(o.props.get("behavior", 0)), 0, 2)]
			draw_line(o.position, o.position + Vector2(facing * sz.x * 0.6, 0), Color.WHITE, w(2))
			text(r.position + Vector2(0, -w(4)), "манекен: " + beh, col, 11)
		"note":
			var props: Resource = def.props_script.new() if def.props_script != null else null
			var s: String = o.props.get("text", props.text if props != null else "")
			var fs: int = o.props.get("font_size", props.font_size if props != null else 16)
			var ingame: bool = o.props.get("show_in_game", props.show_in_game if props != null else false)
			draw_set_transform(o.position, 0.0, Vector2.ONE)
			draw_string(ThemeDB.fallback_font, Vector2(0, fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85 * alpha) if ingame else Color(0.7, 0.9, 1.0, 0.85 * alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			draw_rect(r, Color(col, 0.3 * alpha))
			draw_rect(r, col, false, w(2))
			text(r.position + Vector2(0, -w(4)), def.title, col, 11)


# ------------------------------------------------------------ выделение

func _draw_selection() -> void:
	var sc: Color = ed.ep.select_color
	for r in ed.selection:
		if r is GeoShape:
			var pts: PackedVector2Array = ed.level.shape_world_points(r)
			if r.is_closed():
				_outline_poly(pts, sc, w(ed.ep.line_width + 1.5))
			elif pts.size() >= 2:
				draw_polyline(pts, sc, w(ed.ep.line_width + 1.5))
		elif r is PlacedObject:
			_outline_poly(ed.object_world_poly(r), sc, w(2))
	# ручки точек единственного выделенного контура
	if ed.selection.size() == 1 and ed.selection[0] is GeoShape and ed.tool_name == "select":
		var s: GeoShape = ed.selection[0]
		var pts: PackedVector2Array = ed.level.shape_world_points(s)
		for i in range(pts.size()):
			handle(pts[i], Color(1, 0.85, 0.2) if ed.sel_points.has(i) else Color.WHITE)
	# ручки масштаба фона или арт-объекта
	if ed.selection.size() == 1 and ed.tool_name == "select":
		var r = ed.selection[0]
		if r is BackgroundLayer or ed.is_art(r):
			for p in scale_handles(r):
				handle(p, sc)


## Углы фона (мир) или арт-объекта (с учётом поворота).
func scale_handles(r) -> PackedVector2Array:
	if r is BackgroundLayer:
		var b: Rect2 = ed.bg_rect(r)
		return PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)])
	return ed.object_world_poly(r)


## Силуэт героя у курсора, пока выделен фон или арт-объект (подогнать масштаб картинки под героя).
func _draw_hero_ghost() -> void:
	if not ed.ep.show_hero_ghost or ed.selection.size() != 1 or ed.player_view:
		return
	var r = ed.selection[0]
	if not (r is BackgroundLayer or ed.is_art(r)):
		return
	var m: Resource = Params.get_res("movement")
	var size := Vector2(m.body_width, m.body_height)
	var at: Vector2 = ed.mouse_world() + Vector2(w(24), -size.y * 0.5)
	var rect := Rect2(at - size * 0.5, size)
	draw_rect(rect, Color(0.49, 0.88, 0.5, 0.45))
	draw_rect(rect, Color(0.49, 0.88, 0.5, 0.95), false, w(1.5))
	text(rect.position + Vector2(0, -w(3)), "герой", Color(0.49, 0.88, 0.5), 10)
