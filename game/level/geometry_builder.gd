extends RefCounted
## GeoShape → узлы коллизии игры. Точки переводятся в мировые координаты заранее
## (с учётом арт-объекта-родителя), поэтому у тел нет масштаба — физика не страдает.
##   Тело       → StaticBody2D + CollisionPolygon2D (сплошной; Godot сам режет вогнутое на выпуклые части)
##   Платформа  → StaticBody2D + цепочка Geometry.make_segment (пологое проходимо снизу, крутое — стена)
##   Стена      → то же, без прохода снизу
##   Блок       → StaticBody2D + прямоугольник (как block() на плейграундах)
##   Смерть     → Area2D с маской героя
##
## Стыки ломаной: верхняя грань отрезков платформы кладётся точно на нарисованную линию (тело уходит
## вниз на толщину). make_segment удлиняет отрезок на 1 px с каждой стороны — на выпуклом изломе этот
## выступ торчит над соседним отрезком торцом, и герой в него упирается. Поэтому концы каждого отрезка
## заранее укорачиваются на этот 1 px: верхние грани соседей сходятся ровно в точке излома, без
## ступенек и щелей. Под изломом ставится круг диаметром в толщину — закрывает клин между торцами.

const Geometry := preload("res://core/geometry.gd")
const Layers := preload("res://core/layers.gd")
const WORLD_LAYER := Layers.WORLD
const PLAYER_LAYER := Layers.PLAYER
const SEGMENT_OVERLAP := 1.0   ## на столько make_segment удлиняет отрезок с каждой стороны (l + 2), px


## Строит узел для контура. points_world — мировые точки (LevelData.shape_world_points).
## on_kill — что вызвать, когда герой коснулся смертельной зоны (Callable без аргументов).
static func build(s: GeoShape, points_world: PackedVector2Array, on_kill: Callable = Callable()) -> Node2D:
	if points_world.size() < s.min_points():
		return null
	var closed := GeoShape.kind_is_closed(s.kind)
	if closed and Geometry.self_intersects(points_world, true):
		push_warning("Контур %s самопересекается — в игре не создан" % s.uid)
		return null
	var node: Node2D
	match s.kind:
		GeoShape.Kind.BODY:
			node = _body(points_world)
		GeoShape.Kind.RECT:
			node = _rect(points_world)
		GeoShape.Kind.PLATFORM:
			node = _chain(points_world, s.thickness, s.one_way, s.solid_angle_deg)
		GeoShape.Kind.WALL:
			node = _chain(points_world, s.thickness, false, s.solid_angle_deg)
		GeoShape.Kind.KILL:
			node = _kill(points_world, on_kill)
	if node == null:
		return null
	node.name = s.uid
	if s.material == GeoShape.Mat.ICE and node is StaticBody2D:
		node.set_meta("ice", true)   # как у ледяных блоков: player.gd читает meta "ice" у тела под ногами
	if s.visible_in_game:
		_visual(node, s, points_world)
	return node


static func _body(pts: PackedVector2Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	cp.polygon = pts
	body.add_child(cp)
	return body


static func _is_axis_rect(pts: PackedVector2Array) -> bool:
	if pts.size() != 4:
		return false
	for i in range(4):
		var d := pts[(i + 1) % 4] - pts[i]
		if absf(d.x) > 0.01 and absf(d.y) > 0.01:
			return false
	return true


static func _rect(pts: PackedVector2Array) -> StaticBody2D:
	if not _is_axis_rect(pts):
		return _body(pts)   # повёрнутый вместе с арт-объектом блок — обычный многоугольник
	var r := Geometry.bbox(pts)
	var body := StaticBody2D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = r.get_center()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(maxf(r.size.x, 1.0), maxf(r.size.y, 1.0))
	cs.shape = rs
	body.add_child(cs)
	# точки визуала — относительно центра тела
	body.set_meta("visual_offset", -r.get_center())
	return body


static func _chain(pts: PackedVector2Array, thick: float, one_way_ok: bool, solid_angle: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	fill_chain(body, pts, thick, one_way_ok, solid_angle)
	return body


## Сплошной многоугольник в готовом теле (точки — в координатах тела). Для компонентов (тело рисуемого контура,
## ломкая и движущаяся платформа). Самопересекающийся — не создаётся (false).
static func fill_polygon(body: CollisionObject2D, pts: PackedVector2Array) -> bool:
	if pts.size() < 3 or Geometry.self_intersects(pts, true):
		return false
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	cp.polygon = pts
	body.add_child(cp)
	return true


## Цепочка отрезков платформы / стены в готовом теле (точки — в координатах тела). Верхняя грань — по точкам.
## Те же стыки без зацепов, что у контуров уровня.
static func fill_chain(body: StaticBody2D, pts: PackedVector2Array, thick: float, one_way_ok: bool, solid_angle: float) -> void:
	var t := maxf(thick, 1.0)
	var half := t * 0.5
	var n := pts.size()
	for i in range(n - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var off := Geometry.down_normal(a, b) * half
		var d := b - a
		var l := d.length()
		if l < 0.01:
			continue
		var trim := d / l * minf(SEGMENT_OVERLAP, l * 0.25)
		var cs := Geometry.make_segment(body, a + off + trim, b + off - trim, t, one_way_ok, solid_angle)
		if cs != null and l <= SEGMENT_OVERLAP * 4.0:
			(cs.shape as RectangleShape2D).size.x = l   # очень короткий отрезок: ровно его длина
	# круги в изломах
	for i in range(1, n - 1):
		var a := pts[i - 1]
		var j := pts[i]
		var b := pts[i + 1]
		var n1 := Geometry.down_normal(a, j)
		var n2 := Geometry.down_normal(j, b)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = half
		cs.shape = circle
		cs.position = j + (n1 + n2).normalized() * half if (n1 + n2).length() > 0.01 else j + n1 * half
		var ow1 := one_way_ok and Geometry.slope_deg(a, j) < solid_angle
		var ow2 := one_way_ok and Geometry.slope_deg(j, b) < solid_angle
		cs.one_way_collision = ow1 and ow2
		cs.rotation = ((Geometry.up_axis(a, j) + Geometry.up_axis(j, b)) * 0.5).angle()
		body.add_child(cs)


static func _kill(pts: PackedVector2Array, on_kill: Callable) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	cp.polygon = pts
	area.add_child(cp)
	if on_kill.is_valid():
		area.body_entered.connect(func(b: Node) -> void:
			if b.is_in_group("player"):
				on_kill.call())
	return area


static func _visual(node: Node2D, s: GeoShape, pts: PackedVector2Array) -> void:
	var off: Vector2 = node.get_meta("visual_offset", Vector2.ZERO)
	var local := Transform2D(0.0, off) * pts
	if GeoShape.kind_is_closed(s.kind):
		var poly := Polygon2D.new()
		poly.polygon = local
		poly.color = s.color
		node.add_child(poly)
		if s.kind == GeoShape.Kind.RECT:
			var r := Geometry.bbox(local)
			var edge := Polygon2D.new()
			var eh := minf(4.0, r.size.y)
			edge.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + eh), Vector2(r.position.x, r.position.y + eh)])
			edge.color = s.color.lightened(0.35)
			node.add_child(edge)
	else:
		var line := Line2D.new()
		line.points = local
		line.width = maxf(s.thickness, 1.0)
		line.default_color = s.color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		# линия рисуется так же, как коллизия: верхний край — по нарисованным точкам
		var shifted := PackedVector2Array()
		for i in range(local.size()):
			var a := local[maxi(i - 1, 0)]
			var b := local[mini(i + 1, local.size() - 1)]
			shifted.append(local[i] + Geometry.down_normal(a, b) * s.thickness * 0.5)
		line.points = shifted
		node.add_child(line)
