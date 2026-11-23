extends "res://game/components/component_base.gd"
## Рычаг: E рядом — переключить. Активен = включён. События activated / deactivated. Источник связей.

var _angle := -1.0   ## −1 выкл … +1 вкл (для анимации)


func _setup(_ctx: Dictionary) -> void:
	add_to_group("interactive")
	_angle = 1.0 if active else -1.0


func can_interact(_p: Node) -> bool:
	return not (int(props.mode) == 1 and active)


func on_interact_pressed(_p: Node) -> void:
	if int(props.mode) == 1 and active:
		return
	set_active(not active)


func _active_event(on: bool) -> void:
	emit_event("activated" if on else "deactivated")
	links_pulse()
	links_state(on)


func _restore(_d: Dictionary) -> void:
	_angle = 1.0 if active else -1.0


func _process(delta: float) -> void:
	var t: float = Params.get_res("objects").lever_anim_time
	var target := 1.0 if active else -1.0
	if not is_equal_approx(_angle, target):
		_angle = move_toward(_angle, target, delta * 2.0 / maxf(t, 0.001))
		queue_redraw()


func interact_point(_from: Vector2) -> Vector2:
	return global_position


func _draw() -> void:
	var base := Rect2(-16, 4, 32, 12)
	draw_rect(base, Color(0.35, 0.3, 0.27))
	draw_rect(base, Color(0, 0, 0, 0.6), false, 2.0)
	var tip := Vector2(0, 6) + Vector2.UP.rotated(deg_to_rad(35.0 * _angle)) * 30.0
	draw_line(Vector2(0, 6), tip, Color(0.75, 0.6, 0.4), 5.0)
	draw_circle(tip, 6.0, Color(0.95, 0.4, 0.3) if active else Color(0.6, 0.6, 0.65))
	if highlighted:
		draw_arc(Vector2(0, 0), 26.0, 0, TAU, 24, Params.get_res("interact").highlight_color, 2.0)
	_draw_debug()
