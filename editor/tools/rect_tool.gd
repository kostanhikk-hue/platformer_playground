extends "res://editor/tools/tool_base.gd"
## Блок (B): прямоугольник по сетке — быстрая заглушка, как block() на плейграундах. Тянуть мышью.
## Шаг — привязка к сетке из вкладки «Редактор»; Alt — без привязки.

var _from = null
var _to := Vector2.ZERO


func title() -> String:
	return "Блок"


func hint() -> String:
	return "тяни мышью прямоугольник (по сетке; Alt — свободно), Esc — отмена"


func deactivate() -> void:
	_from = null


func _sn(p: Vector2) -> Vector2:
	return p if EdInput.alt() else ed.snap_grid(p)


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
			if r.size.x < 1.0 or r.size.y < 1.0:
				return
			var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			var attach = null
			var sel: Array = ed.selection
			if sel.size() == 1 and ed.is_art(sel[0]) and Geometry2D.is_point_in_polygon(r.position, ed.object_world_poly(sel[0])):
				attach = sel[0]
			var s: GeoShape = ed.new_shape(GeoShape.Kind.RECT, pts, attach)
			ed.add_items("shapes", [s], "Блок")
			ed.say("Блок %s: %d×%d px" % [s.uid, roundi(r.size.x), roundi(r.size.y)])
	elif event is InputEventMouseMotion and _from != null:
		_to = _sn(m)


func key(event: InputEvent) -> bool:
	if _from != null and EdInput.pressed(event, "ed_cancel"):
		_from = null
		return true
	return false


func draw_overlay(c: Node2D) -> void:
	if _from == null:
		c.handle(_sn(ed.mouse_world()), Color(ed.ep.block_color, 0.9))
		return
	var r := Rect2(_from, _to - _from).abs()
	c.draw_rect(r, Color(ed.ep.block_color, 0.6))
	c.draw_rect(r, Color.WHITE, false, c.w(1.5))
	c.text(r.end + Vector2(c.w(6), c.w(14)), "%d×%d px (%.1f×%.1f T)" % [roundi(r.size.x), roundi(r.size.y), r.size.x / 32.0, r.size.y / 32.0], Color(1, 1, 1, 0.8), 11)
