extends "res://editor/tools/tool_base.gd"
## Поставить объект из палитры: клик в холсте. Shift — поставить ещё (инструмент не сбрасывается).
## Объекты «на пол» (рычаг, дверь, чекпоинт…) опускаются до пола под курсором; Alt — без этого.

const Catalog := preload("res://game/level/catalog.gd")

var def: ObjectDef


func title() -> String:
	return "Поставить: " + (def.title if def != null else "—")


func hint() -> String:
	var s := "клик — поставить (Shift — ещё один), Esc — отмена"
	if def != null and def.snap_to_floor:
		s += ", ставится на пол (Alt — свободно)"
	return s


func _point() -> Vector2:
	return ed.place_point(def, ed.snap(ed.mouse_world()))


func input(event: InputEvent) -> void:
	if def == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		ed.place_object(def, _point())
		if not EdInput.shift():
			ed.set_tool("select")


func draw_overlay(c: Node2D) -> void:
	if def == null:
		return
	var p := _point()
	if not def.kit.is_empty():
		for it in def.kit:
			var d := Catalog.get_def(it.get("def_id", ""))
			if d == null:
				continue
			var at: Vector2 = p + (it.get("offset", Vector2.ZERO) as Vector2)
			if it.has("shapes"):
				for sh in it["shapes"]:
					var pts: PackedVector2Array = Transform2D(0.0, at) * (sh["points"] as PackedVector2Array)
					if sh["closed"] and pts.size() > 0:
						pts.append(pts[0])
					c.draw_polyline(pts, Color(d.editor_color, 0.8), c.w(1.5))
			else:
				var sz := d.editor_size
				c.draw_rect(Rect2(at - sz * 0.5, sz), Color(d.editor_color, 0.3))
				c.draw_rect(Rect2(at - sz * 0.5, sz), d.editor_color, false, c.w(1.5))
		c.text(p + Vector2(0, -c.w(60)), def.title, def.editor_color, 11)
		return
	if not def.shapes.is_empty():
		for sh in def.shapes:
			var pts: PackedVector2Array = Transform2D(0.0, p + sh.position) * sh.points
			if sh.is_closed() and pts.size() > 0:
				pts.append(pts[0])
			c.draw_polyline(pts, Color(def.editor_color, 0.8), c.w(1.5))
	var sz := def.editor_size
	c.draw_rect(Rect2(p - sz * 0.5, sz), Color(def.editor_color, 0.25))
	c.draw_rect(Rect2(p - sz * 0.5, sz), def.editor_color, false, c.w(1.5))
	c.text(p + Vector2(-sz.x * 0.5, -sz.y * 0.5 - c.w(4)), def.title, def.editor_color, 11)
