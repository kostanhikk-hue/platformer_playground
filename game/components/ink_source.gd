extends "res://game/components/component_base.gd"
## Источник охры (охра-камень): пополняет запас чернил касанием или по E. Активен = заряжен.
## Перезарядка (0 — однократный). Событие collected {amount}.

var _area: Area2D
var _t := 0.0
var _flash := 0.0
var _phase := 0.0


func _setup(_ctx: Dictionary) -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20.0
	cs.shape = c
	_area.add_child(cs)
	add_child(_area)
	_phase = randf() * TAU


func _apply() -> void:
	if int(props.pickup) == 1:
		add_to_group("interactive")
	elif is_in_group("interactive"):
		remove_from_group("interactive")


func _active_event(_on: bool) -> void:
	pass   # своё событие — collected


func _physics_process(delta: float) -> void:
	super(delta)
	_flash = maxf(_flash - delta, 0.0)
	_phase += delta
	if not active:
		if props.recharge > 0.0:
			_t -= delta
			if _t <= 0.0:
				set_active(true)
	elif int(props.pickup) == 0:
		for b in _area.get_overlapping_bodies():
			if b.is_in_group("player") and not b.dead:
				_collect(b)
				break
	queue_redraw()


func can_interact(_p: Node) -> bool:
	return active and int(props.pickup) == 1


func on_interact_pressed(p: Node) -> void:
	if active:
		_collect(p)


func _collect(p: Node) -> void:
	var amt: float = p.get_max_ink() if props.amount < 0.0 else props.amount
	p.add_ink(amt)
	_flash = Params.get_res("objects").ink_pickup_flash
	_t = props.recharge
	set_active(false)
	emit_event("collected", {"amount": amt})


func _snap() -> Dictionary:
	return {"t": _t}


func _restore(d: Dictionary) -> void:
	_t = d.get("t", 0.0)


func _draw() -> void:
	var col := Color(0.86, 0.48, 0.16) if active else Color(0.4, 0.33, 0.28)
	if active:
		draw_circle(Vector2.ZERO, 22.0 + 2.0 * sin(_phase * 3.0), Color(col, 0.18))
	var pts := PackedVector2Array()
	for k in range(9):
		var a := TAU * k / 9.0
		pts.append(Vector2.from_angle(a) * (14.0 + 3.0 * sin(a * 3.0 + 1.3)))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.5), 2.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 30.0 * (1.0 - _flash), Color(1, 0.9, 0.6, _flash * 2.0))
	if highlighted:
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 24, Params.get_res("interact").highlight_color, 2.0)
	_draw_debug()
