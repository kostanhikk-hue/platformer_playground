extends "res://game/components/component_base.gd"
## Чекпоинт: точка возрождения (центр героя = положение чекпоинта). Активация касанием, E или по связи
## (рисуемый контур «ладонь» → цель: этот чекпоинт). При активации: точка возрождения, снимок уровня
## (что было до — останется после смерти), лечение и охра по галочкам. Активный — один на уровень.
## Событие checkpoint.

signal reached(point: Vector2)

const TRIGGER_SIZE := Vector2(40, 72)
const POLE_HEIGHT := 56.0   ## размер флажка-заглушки, px (только картинка)

var _area: Area2D
var _glow := 0.0


func _setup(ctx: Dictionary) -> void:
	add_to_group("level_checkpoint")
	if ctx.has("on_checkpoint") and runtime == null:
		reached.connect(ctx["on_checkpoint"])
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = TRIGGER_SIZE
	cs.shape = rs
	_area.add_child(cs)
	add_child(_area)


func _apply() -> void:
	if int(props.activation) == 1:
		add_to_group("interactive")
	elif is_in_group("interactive"):
		remove_from_group("interactive")


func resets_on_death() -> bool:
	return false   # активный чекпоинт не откатывается


func _physics_process(delta: float) -> void:
	super(delta)
	_glow = move_toward(_glow, 1.0 if active else 0.0, delta * 3.0)
	if not active and int(props.activation) == 0:
		for b in _area.get_overlapping_bodies():
			if b.is_in_group("player") and not b.dead:
				set_active(true)
				break
	queue_redraw()


func can_interact(_p: Node) -> bool:
	return not active and int(props.activation) == 1


func on_interact_pressed(_p: Node) -> void:
	set_active(true)


## Снять активность без событий (активирован другой чекпоинт).
func set_current(on: bool) -> void:
	active = on
	queue_redraw()


func _active_event(on: bool) -> void:
	if not on:
		return
	emit_event("checkpoint")
	var pl = runtime.player if runtime != null and runtime.get("player") != null else null
	if pl != null and is_instance_valid(pl):
		if props.heal_full:
			pl.heal(-1.0)
		if props.refill_ink:
			pl.add_ink(pl.get_max_ink())
	if runtime != null and runtime.has_method("checkpoint_reached"):
		runtime.checkpoint_reached(self, global_position)
	reached.emit(global_position)


func _draw() -> void:
	var foot := Vector2(0, TRIGGER_SIZE.y * 0.5)
	var col := Color(0.4, 0.95, 0.5) if active else Color(0.95, 0.6, 0.3)
	var glow: float = Params.get_res("objects").checkpoint_glow * _glow
	if int(props.look) == 1:
		# ладонь: отпечаток охрой на стене
		var c := Vector2(0, -6)
		if glow > 0.5:
			draw_circle(c, 22.0 + glow, Color(col, 0.18))
		var pc := Color(0.82, 0.46, 0.14) if active else Color(0.6, 0.5, 0.4, 0.6)
		draw_circle(c + Vector2(0, 8), 13.0, pc)
		for k in range(5):
			var a := deg_to_rad(-150.0 + k * 30.0) if k < 4 else deg_to_rad(-10.0)
			var f := c + Vector2(0, 4) + Vector2.from_angle(a) * 18.0
			draw_line(c + Vector2(0, 6), f, pc, 7.0)
			draw_circle(f, 3.5, pc)
	else:
		if glow > 0.5:
			draw_circle(foot - Vector2(0, POLE_HEIGHT * 0.6), glow + 10.0, Color(col, 0.15))
		draw_line(foot, foot - Vector2(0, POLE_HEIGHT), Color(0.85, 0.85, 0.85), 3.0)
		var top := foot - Vector2(0, POLE_HEIGHT)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(26, 9), top + Vector2(0, 18)]), col)
	if highlighted:
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Params.get_res("interact").highlight_color, 2.0)
	_draw_debug()
