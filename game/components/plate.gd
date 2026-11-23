extends "res://game/components/component_base.gd"
## Нажимная плита: активна, пока на ней что-то из отмеченного галочками: герой / враги / штрихи / другие тела.
## Герой, враги, другие тела — область Area2D (маска по галочкам). Штрихи — статические тела, Area2D их не видит,
## поэтому для них отдельный запрос формой плиты по слою «Штрихи». События pressed / released.
## Положение объекта — середина плиты, плита лежит на полу (низ = положение + 6 px).

const H := 12.0
var _area: Area2D
var _shape := RectangleShape2D.new()
var _release_t := 0.0
var _stroke_q := PhysicsShapeQueryParameters2D.new()


func _setup(_ctx: Dictionary) -> void:
	active = false
	_area = Area2D.new()
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = _shape
	cs.position = Vector2(0, -H * 0.5)
	_area.add_child(cs)
	add_child(_area)
	_stroke_q.shape = _shape
	_stroke_q.collision_mask = STROKES_LAYER
	_stroke_q.collide_with_areas = false


func _apply() -> void:
	_shape.size = Vector2(maxf(props.width - 4.0, 4.0), H * 2.0)
	var m := 0
	if props.press_hero:
		m |= PLAYER_LAYER
	if props.press_enemies:
		m |= ENEMY_LAYER
	if props.press_bodies:
		m |= WORLD_LAYER
	_area.collision_mask = m


func _physics_process(delta: float) -> void:
	super(delta)
	var pressed := false
	for b in _area.get_overlapping_bodies():
		if b.is_in_group("level_geometry"):
			continue
		if b.get("dead") == true:
			continue
		pressed = true
		break
	if not pressed and props.press_strokes:
		_stroke_q.transform = global_transform * Transform2D(0.0, Vector2(0, -H * 0.5))
		pressed = not get_world_2d().direct_space_state.intersect_shape(_stroke_q, 1).is_empty()
	if pressed:
		_release_t = props.release_delay
		if not active:
			set_active(true)
	elif active:
		_release_t -= delta
		if _release_t <= 0.0:
			set_active(false)


func _active_event(on: bool) -> void:
	emit_event("pressed" if on else "released")
	if on:
		links_pulse()
	links_state(on)


func _on_active(_on: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var w: float = props.width
	var depth: float = Params.get_res("objects").plate_depth if active else 0.0
	draw_rect(Rect2(-w * 0.5 - 4, 0, w + 8, 6), Color(0.3, 0.3, 0.33))
	var top := Rect2(-w * 0.5, -6 + depth, w, 6 - depth * 0.5)
	draw_rect(top, Color(0.95, 0.75, 0.3) if active else Color(0.7, 0.6, 0.45))
	draw_rect(top, Color(0, 0, 0, 0.5), false, 1.5)
	_draw_debug()
