extends "res://game/components/component_base.gd"
## Дверь: активна = открыта. Открывается вверх, в стороны или растворяется за open_time. События opened / closed.
## Закрытая (solid) — твёрдая; зажатого дверью героя выталкивает (группа "crusher", см. player._check_crush).

var _body: StaticBody2D
var _a := CollisionShape2D.new()
var _b := CollisionShape2D.new()
var _ra := RectangleShape2D.new()
var _rb := RectangleShape2D.new()
var _p := 0.0   ## 0 закрыта … 1 открыта


func _setup(_ctx: Dictionary) -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = WORLD_LAYER
	_body.collision_mask = 0
	_body.add_to_group("crusher")
	_a.shape = _ra
	_b.shape = _rb
	_body.add_child(_a)
	_body.add_child(_b)
	add_child(_body)
	_p = 1.0 if active else 0.0


func _apply() -> void:
	_update_shapes()


func _active_event(on: bool) -> void:
	emit_event("opened" if on else "closed")


func _restore(_d: Dictionary) -> void:
	_p = 1.0 if active else 0.0
	_update_shapes()


func _physics_process(delta: float) -> void:
	super(delta)
	var target := 1.0 if active else 0.0
	if not is_equal_approx(_p, target):
		var t: float = props.open_time
		_p = target if t <= 0.0 else move_toward(_p, target, delta / t)
		_update_shapes()
		queue_redraw()


func _update_shapes() -> void:
	var w: float = maxf(props.width, 1.0)
	var h: float = maxf(props.height, 1.0)
	var off: bool = not props.solid
	match int(props.open_dir):
		0:
			_ra.size = Vector2(w, h)
			_a.position = Vector2(0, -h * _p)
			_b.disabled = true
			_a.set_deferred("disabled", off or _p >= 0.98)
		1:
			var hw := w * 0.5
			_ra.size = Vector2(hw, h)
			_rb.size = Vector2(hw, h)
			_a.position = Vector2(-hw * 0.5 - hw * _p, 0)
			_b.position = Vector2(hw * 0.5 + hw * _p, 0)
			_a.set_deferred("disabled", off or _p >= 0.98)
			_b.set_deferred("disabled", off or _p >= 0.98)
		_:
			_ra.size = Vector2(w, h)
			_a.position = Vector2.ZERO
			_b.disabled = true
			_a.set_deferred("disabled", off or _p >= 0.5)


func _draw() -> void:
	var w: float = props.width
	var h: float = props.height
	var col: Color = props.color
	var frame := Rect2(-w * 0.5, -h * 0.5, w, h)
	if _p > 0.02:
		draw_rect(frame, Color(col, 0.35), false, 1.5)
	match int(props.open_dir):
		0:
			var r := Rect2(-w * 0.5, -h * 0.5 - h * _p, w, h)
			_panel(r.intersection(Rect2(-w * 0.5, -h * 1.5, w, h * 2.0)), col)
		1:
			var hw := w * 0.5
			_panel(Rect2(-w * 0.5 - hw * _p, -h * 0.5, hw, h), col)
			_panel(Rect2(-hw * _p, -h * 0.5, hw, h), col)
		_:
			_panel(frame, Color(col, col.a * (1.0 - _p)))
	_draw_debug()


func _panel(r: Rect2, col: Color) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	draw_rect(r, col)
	draw_rect(r, Color(0, 0, 0, 0.55 * col.a), false, 2.0)
	var y := r.position.y + 12.0
	while y < r.end.y - 4.0:
		draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Color(0, 0, 0, 0.2 * col.a), 1.0)
		y += 16.0


func _debug_height() -> float:
	return props.height * 0.5 + 12.0
