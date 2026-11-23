extends "res://game/components/component_base.gd"
## Источник света: PointLight2D (вид) + радиус действия (механика) для освещаемых объектов и оживших картин.
## Мерцание радиуса и яркости. Переносимый — E: взять / положить; со светом в руках приёмы недоступны
## (вкладка «Свет»). Активен = горит. События activated, deactivated, picked, dropped.

var light: PointLight2D
var carried := false
var _t := 0.0
var _flick := 1.0
var _start_pos := Vector2.ZERO
var lp: Resource
static var _tex: Texture2D
static var _tex_soft := -1.0
const TEX_SIZE := 256


func _setup(_ctx: Dictionary) -> void:
	lp = Params.get_res("light")
	add_to_group("light_source")
	light = PointLight2D.new()
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)
	_t = randf() * 10.0


func _ready() -> void:
	super()
	_start_pos = global_position


func _apply() -> void:
	if props.carryable:
		add_to_group("interactive")
	elif is_in_group("interactive"):
		remove_from_group("interactive")
	light.texture = _texture(lp.light_softness)
	light.color = props.color
	_update_light()


static func _texture(soft: float) -> Texture2D:
	if _tex != null and is_equal_approx(_tex_soft, soft):
		return _tex
	var g := Gradient.new()
	var s := clampf(soft, 0.0, 1.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.set_offset(0, 1.0 - maxf(s, 0.02))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = TEX_SIZE
	gt.height = TEX_SIZE
	_tex = gt
	_tex_soft = soft
	return gt


func view_r() -> float:
	return props.radius if props.view_radius < 0.0 else props.view_radius


func mech_r() -> float:
	return props.radius * _flick


func _update_light() -> void:
	light.enabled = active
	light.energy = props.energy * _flick
	light.texture_scale = maxf(view_r() * _flick * 2.0 / TEX_SIZE, 0.01)


## Освещает ли точку (с радиусом цели r). Используется LightQuery для освещаемых и оживших картин.
func light_reaches(point: Vector2, r: float) -> bool:
	if not active or not is_inside_tree():
		return false
	var src := global_position
	var d := src.distance_to(point)
	if d > mech_r() + r:
		return false
	if not props.line_of_sight or d < 1.0:
		return true
	var to := point if d <= mech_r() else src + (point - src).normalized() * mech_r()
	var q := PhysicsRayQueryParameters2D.create(src, to, Layers.SOLID)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return (hit["position"] as Vector2).distance_to(point) <= r + 12.0


func _physics_process(delta: float) -> void:
	super(delta)
	_t += delta
	_flick = 1.0 + props.flicker_amp * (0.6 * sin(_t * TAU * props.flicker_hz) + 0.4 * sin(_t * TAU * props.flicker_hz * 2.37 + 1.3))
	_update_light()
	if carried:
		var pl = _player()
		if pl == null or pl.dead:
			_drop(false)
		else:
			var target: Vector2 = pl.global_position + Vector2(lp.carry_offset_x * pl.facing, -lp.carry_offset_y)
			global_position = global_position.lerp(target, clampf(lp.carry_follow_speed * delta, 0.0, 1.0))
			pl.skills_locked = lp.carry_blocks_skills
			pl.move_mult_ext = lp.carry_move_mult
	queue_redraw()


func _player():
	if runtime != null and runtime.get("player") != null and is_instance_valid(runtime.player):
		return runtime.player
	return null


func can_interact(_p: Node) -> bool:
	return props.carryable


## Несомый свет отдаёт приоритет соседним объектам: его «точка» — над героем, на краю радиуса.
func interact_point(from: Vector2) -> Vector2:
	if carried:
		return from + Vector2(0, -Params.get_res("interact").interact_radius * 0.9)
	return global_position


func on_interact_pressed(_p: Node) -> void:
	if carried:
		_drop(true)
	else:
		carried = true
		emit_event("picked")


func _drop(with_event: bool) -> void:
	carried = false
	var pl = _player()
	if pl != null:
		pl.skills_locked = false
		pl.move_mult_ext = 1.0
		var from: Vector2 = pl.global_position
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, lp.drop_probe), Layers.SOLID)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		global_position = (hit["position"] as Vector2) + Vector2(0, -16) if not hit.is_empty() else from
	if with_event:
		emit_event("dropped")


func _snap() -> Dictionary:
	return {"pos": global_position if not carried else _start_pos, "carried": false}


func _restore(d: Dictionary) -> void:
	if carried:
		_drop(false)
	global_position = d.get("pos", global_position)
	_update_light()


func _draw() -> void:
	var look := int(props.look)
	if look != 2:
		var stick_col := Color(0.42, 0.3, 0.2)
		if look == 0:
			draw_line(Vector2(-6, 14), Vector2(0, -2), stick_col, 5.0)
			draw_rect(Rect2(-10, 12, 12, 6), Color(0.3, 0.3, 0.32))
		else:
			draw_line(Vector2(0, 18), Vector2(0, -2), stick_col, 5.0)
		if active:
			var f := 1.0 + 0.15 * sin(_t * 23.0)
			draw_circle(Vector2(0, -8), 8.0 * f, Color(1.0, 0.55, 0.15, 0.9))
			draw_circle(Vector2(0, -11), 4.5 * f, Color(1.0, 0.92, 0.55))
		else:
			draw_circle(Vector2(0, -6), 4.0, Color(0.35, 0.25, 0.2))
	if Fx.debug_hitboxes:
		draw_arc(Vector2.ZERO, mech_r(), 0, TAU, 48, Color(1, 0.8, 0.3, 0.35), 1.0)
	if highlighted and not carried:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Params.get_res("interact").highlight_color, 2.0)
	_draw_debug()


func _debug() -> String:
	return ("несут" if carried else "") + " радиус %d" % int(mech_r())
