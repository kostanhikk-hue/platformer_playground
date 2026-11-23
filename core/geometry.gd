extends RefCounted
## Общая геометрия (статические функции). Используется штрихами кисти, сборкой уровня и конструктором.
##   const Geometry := preload("res://core/geometry.gd")
##   Geometry.make_segment(body, a, b, толщина, one_way, solid_angle_deg)


## Твёрдый отрезок a→b внутри body. Пологие (|угол| < solid_angle_deg) можно проходить снизу, если one_way.
## Перенесено из game/ink/stroke_base.gd без изменения поведения.
static func make_segment(body: StaticBody2D, a: Vector2, b: Vector2, thick: float, one_way_ok: bool, solid_angle_deg: float) -> CollisionShape2D:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return null
	var dn := d / l
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(l + 2.0, thick)
	cs.shape = rs
	cs.position = (a + b) * 0.5
	var axis := dn if dn.x >= 0.0 else -dn   # «верх» платформы всегда смотрит вверх
	cs.rotation = axis.angle()
	cs.one_way_collision = one_way_ok and absf(dn.x) >= cos(deg_to_rad(solid_angle_deg))
	body.add_child(cs)
	return cs


## Угол отрезка к горизонту, 0…90°.
static func slope_deg(a: Vector2, b: Vector2) -> float:
	var d := b - a
	if d.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(absf(d.y), absf(d.x)))


## Ось отрезка, у которой «верх» смотрит вверх (как в make_segment), и нормаль «вниз» от неё.
static func up_axis(a: Vector2, b: Vector2) -> Vector2:
	var dn := (b - a).normalized()
	return dn if dn.x >= 0.0 else -dn


static func down_normal(a: Vector2, b: Vector2) -> Vector2:
	var ax := up_axis(a, b)
	return Vector2(-ax.y, ax.x)


## Ориентированная площадь (>0 — по часовой в экранных координатах с Y вниз).
static func signed_area(pts: PackedVector2Array) -> float:
	var s := 0.0
	var n := pts.size()
	for i in range(n):
		var p := pts[i]
		var q := pts[(i + 1) % n]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


## Есть ли у ломаной/многоугольника самопересечения (соседние рёбра не считаются).
static func self_intersects(pts: PackedVector2Array, closed: bool) -> bool:
	var n := pts.size()
	var edges := n if closed else n - 1
	if edges < 3:
		return false
	for i in range(edges):
		var a1 := pts[i]
		var a2 := pts[(i + 1) % n]
		for j in range(i + 2, edges):
			if closed and i == 0 and j == edges - 1:
				continue   # первое и последнее ребро соседние
			var b1 := pts[j]
			var b2 := pts[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return true
	return false


## Упрощение ломаной (Рамер — Дуглас — Пекер). tolerance — допустимое отклонение, px.
static func simplify(pts: PackedVector2Array, tolerance: float, closed: bool) -> PackedVector2Array:
	var n := pts.size()
	if n < 3 or tolerance <= 0.0:
		return pts
	if closed:
		# разрезаем замкнутый контур в самой дальней от первой точке и упрощаем две половины
		var far := 0
		var best := -1.0
		for i in range(n):
			var d := pts[0].distance_squared_to(pts[i])
			if d > best:
				best = d
				far = i
		var a := pts.slice(0, far + 1)
		var b := pts.slice(far)
		b.append(pts[0])
		var ra := _rdp(a, tolerance)
		var rb := _rdp(b, tolerance)
		var out := ra.slice(0, ra.size() - 1)
		out.append_array(rb.slice(0, rb.size() - 1))
		return out if out.size() >= 3 else pts
	return _rdp(pts, tolerance)


static func _rdp(pts: PackedVector2Array, tol: float) -> PackedVector2Array:
	var n := pts.size()
	if n < 3:
		return pts
	var keep := PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	keep[0] = 1
	keep[n - 1] = 1
	var stack: Array = [[0, n - 1]]
	while not stack.is_empty():
		var span: Array = stack.pop_back()
		var s: int = span[0]
		var e: int = span[1]
		var best := -1.0
		var idx := -1
		for i in range(s + 1, e):
			var d := dist_to_segment(pts[i], pts[s], pts[e])
			if d > best:
				best = d
				idx = i
		if idx >= 0 and best > tol:
			keep[idx] = 1
			stack.append([s, idx])
			stack.append([idx, e])
	var out := PackedVector2Array()
	for i in range(n):
		if keep[i] == 1:
			out.append(pts[i])
	return out


static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Убирает точки ближе min_dist к предыдущей.
static func merge_close(pts: PackedVector2Array, min_dist: float, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= min_dist:
			out.append(p)
	if closed and out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < min_dist:
		out.remove_at(out.size() - 1)
	return out


static func bbox(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func transform_points(xf: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	return xf * pts
