extends "res://editor/tools/tool_base.gd"
## Пипетка: клик по объекту (или пути) на холсте → его uid уходит в поле инспектора (цели связей, путь…).
## Shift — выбрать ещё (пипетка остаётся). Esc / ПКМ — отмена. Неподходящие объекты не подсвечиваются.

var accept: Callable          ## Callable(Resource) -> bool
var on_pick: Callable         ## Callable(uid: String)
var multi := false
var label := ""
var source: Resource          ## от кого тянем линию (объект в инспекторе)
var _prev_tool := "select"
var _hover: Resource


func title() -> String:
	return "Пипетка: " + label


func hint() -> String:
	return "клик по объекту — выбрать%s, Esc / ПКМ — отмена" % (" (Shift — ещё)" if multi else ", Shift — выбрать несколько")


func _candidate(p: Vector2) -> Resource:
	for it in ed.hit_items(p, true):
		if accept.is_valid() and accept.call(it):
			return it
	return null


func input(event: InputEvent) -> void:
	_hover = _candidate(ed.mouse_world())
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_finish()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hover == null:
				ed.say("Здесь нет подходящего объекта")
				return
			on_pick.call(_hover.uid)
			if not (multi or EdInput.shift()):
				_finish()


func key(event: InputEvent) -> bool:
	if EdInput.pressed(event, "ed_cancel"):
		_finish()
		return true
	return false


func _finish() -> void:
	ed.set_tool(_prev_tool if _prev_tool != "pick" else "select")


func draw_overlay(c: Node2D) -> void:
	var m: Vector2 = ed.mouse_world()
	if source != null:
		c.draw_line(ed.item_center(source), m, Color(1, 1, 1, 0.5), c.w(1.5))
	if _hover != null:
		var r: Rect2 = ed.item_bbox(_hover).grow(c.w(4))
		c.draw_rect(r, Color(0.4, 1.0, 0.6, 0.9), false, c.w(2))
		c.text(r.position + Vector2(0, -c.w(4)), "→ " + _hover.uid, Color(0.6, 1, 0.7), 12)
	c.draw_circle(m, c.w(4), Color(0.4, 1.0, 0.6))
