extends "res://game/components/component_base.gd"
## «Выход»: касание героя → экран «Уровень пройден». Активен = открыт; locked — заперт, пока не откроет связь.
## Событие entered.

signal entered_exit

var size := Vector2(64, 96)
var target_level := ""
var _area: Area2D
var _shape := RectangleShape2D.new()
var _used := false


func _setup(ctx: Dictionary) -> void:
	if props != null:
		active = not props.locked
	if ctx.has("on_exit"):
		entered_exit.connect(ctx["on_exit"])
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = _shape
	_area.add_child(cs)
	add_child(_area)
	if not Loc.locale_changed.is_connected(queue_redraw):
		Loc.locale_changed.connect(queue_redraw)


func _apply() -> void:
	if props != null:
		size = Vector2(maxf(props.width, 1.0), maxf(props.height, 1.0))
		target_level = props.target_level
	_shape.size = size


func _physics_process(delta: float) -> void:
	super(delta)
	if not active or _used:
		return
	for b in _area.get_overlapping_bodies():
		if b.is_in_group("player"):
			_used = true
			emit_event("entered")
			entered_exit.emit()
			return


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var col := Color(0.35, 0.8, 1.0) if active else Color(0.55, 0.55, 0.6)
	draw_rect(r, Color(col, 0.18 if active else 0.35))
	draw_rect(r, Color(col, 0.8), false, 2.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 16), Loc.t("ui.exit.open" if active else "ui.exit.locked"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, 1.0).lightened(0.3))
	if not active:
		var c := r.get_center()
		draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 14)), col)
		draw_arc(c + Vector2(0, -2), 6.0, PI, TAU, 12, col, 2.5)
	_draw_debug()


func _debug_height() -> float:
	return size.y * 0.5 + 12.0
