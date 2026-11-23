extends "res://game/components/component_base.gd"
## Триггер-зона: сообщает уровню (а через него — сценарию уровня) о входе и выходе героя. В игре невидима.
## Форма — контур объекта с ролью zone. Активна = работает.

var _area: Area2D
var inside := false


func _setup(_ctx: Dictionary) -> void:
	add_to_group("trigger_zone")
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	var list: Array = shapes.get("zone", [])
	var pts: PackedVector2Array = list[0]["points"] if not list.is_empty() else PackedVector2Array([Vector2(-96, -64), Vector2(96, -64), Vector2(96, 64), Vector2(-96, 64)])
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	cp.polygon = pts
	_area.add_child(cp)
	add_child(_area)
	_area.body_entered.connect(_on_enter)
	_area.body_exited.connect(_on_exit)


func resets_on_death() -> bool:
	return true


func _on_enter(b: Node) -> void:
	if not b.is_in_group("player") or not active or inside:
		return
	inside = true
	if runtime != null and runtime.has_method("zone_event"):
		runtime.zone_event(uid, true)


func _on_exit(b: Node) -> void:
	if not b.is_in_group("player") or not inside:
		return
	inside = false
	if runtime != null and runtime.has_method("zone_event"):
		runtime.zone_event(uid, false)


func _on_active(on: bool) -> void:
	if not on and inside:
		_on_exit(runtime.player if runtime != null else null)


func contains(p: Vector2) -> bool:
	for c in _area.get_children():
		if c is CollisionPolygon2D:
			return Geometry2D.is_point_in_polygon(to_local(p), c.polygon)
	return false


## Прямоугольник зоны в мире (для camera_lock).
func world_rect() -> Rect2:
	for c in _area.get_children():
		if c is CollisionPolygon2D and c.polygon.size() > 0:
			var r := Rect2(to_global(c.polygon[0]), Vector2.ZERO)
			for q in c.polygon:
				r = r.expand(to_global(q))
			return r
	return Rect2(global_position, Vector2.ZERO)


func _debug() -> String:
	return "внутри" if inside else ""


func _draw() -> void:
	if not Fx.debug_hitboxes:
		return
	for c in _area.get_children():
		if c is CollisionPolygon2D and c.polygon.size() > 2:
			var o: PackedVector2Array = c.polygon.duplicate()
			o.append(c.polygon[0])
			draw_polyline(o, Color(0.5, 1.0, 0.7, 0.5 if not inside else 0.9), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -8), uid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 1, 0.8, 0.8))
