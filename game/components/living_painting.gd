extends "res://game/components/component_base.gd"
## Ожившая картина: нарисованное существо оживает по условию (свет факела / связь / дорисован контур) —
## едет по пути (на нём можно ехать, как на движущейся платформе) или становится манекеном.
## Условие пропало — замирает, возвращается или доезжает до конца. События awakened, froze.

const GeometryBuilder := preload("res://game/level/geometry_builder.gd")
const PathFollow := preload("res://game/components/path_follow.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const DummyScript := preload("res://game/enemy/enemy_dummy.gd")

enum Cond { LIT, LINK, PAINTED }
enum Lost { FREEZE, RETURN, FINISH }

var body: AnimatableBody2D
var follow := PathFollow.new()
var awake := false
var lp: Resource
var _form := PackedVector2Array()
var _closed := true
var _origin := Vector2.ZERO
var _frames: Array = []
var _frame := 0
var _frame_t := 0.0
var _flash := 0.0
var _shake := 0.0
var _painted := false
var _cond := false
var _cond_t := 0.0
var _check_t := 0.0
var _finishing := false
var _dummy: CharacterBody2D
var _paths: Dictionary = {}


func _setup(ctx: Dictionary) -> void:
	lp = Params.get_res("light")
	_paths = ctx.get("paths", {})
	var list: Array = shapes.get("form", [])
	if not list.is_empty():
		_form = list[0]["points"]
		_closed = list[0]["closed"]
	else:
		_form = PackedVector2Array([Vector2(-60, -20), Vector2(60, -20), Vector2(60, 20), Vector2(-60, 20)])
	body = AnimatableBody2D.new()
	body.sync_to_physics = true
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.add_to_group("crusher")
	add_child(body)
	Events.event.connect(_on_event)


func _exit_tree() -> void:
	if Events.event.is_connected(_on_event):
		Events.event.disconnect(_on_event)


func _apply() -> void:
	for c in body.get_children():
		c.queue_free()
	if not (_closed and GeometryBuilder.fill_polygon(body, _form)):
		GeometryBuilder.fill_chain(body, _form, 14.0, true, 60.0)
	_frames.clear()
	for path in [props.image, props.image2, props.image3]:
		if path != "" and ArtLoader.exists(path):
			var tex := ArtLoader.load_texture(path)
			if tex != null:
				_frames.append(tex)
	var path: Dictionary = _paths.get(props.path_uid, {})
	if follow.pts.is_empty() and not path.is_empty():
		follow.setup(path["points"], path["closed"], props.mode)
		_origin = (path["points"] as PackedVector2Array)[0]
	_update_solid()


func _update_solid() -> void:
	var on: bool = awake or props.rest_platform
	if awake and int(props.awake) == 1:
		on = props.rest_platform and false
	for c in body.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", not on)


func _on_event(src: String, ev: String, _d: Dictionary) -> void:
	if int(props.condition) != Cond.PAINTED or src != props.paintable_uid:
		return
	if ev == "painted":
		_painted = true
	elif ev == "paint_faded":
		_painted = false


func _physics_process(delta: float) -> void:
	super(delta)
	var want := false
	match int(props.condition):
		Cond.LIT:
			_check_t -= delta
			if _check_t <= 0.0:
				_check_t = 1.0 / maxf(lp.lit_check_hz, 1.0)
				_cond = LightQuery.is_lit(self, global_position + body.position, props.lit_radius)
			want = _cond
		Cond.LINK:
			want = active
		Cond.PAINTED:
			want = _painted
	if want != awake:
		_cond_t += delta
		if _cond_t >= 0.12 or int(props.condition) != Cond.LIT:
			_cond_t = 0.0
			if want:
				_awaken()
			else:
				_freeze()
	else:
		_cond_t = 0.0
	_flash = maxf(_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	if awake or _finishing:
		_frame_t += delta
		if _frames.size() > 1 and _frame_t >= 1.0 / maxf(props.frame_hz, 0.1):
			_frame_t = 0.0
			_frame = (_frame + 1) % _frames.size()
		if int(props.awake) == 0 and active_path():
			for e in follow.step(delta, props.speed, props.pause, props.ease):
				if e[0] == "end" and _finishing:
					_finishing = false
					_frame = 0
					emit_event("froze")
			body.position = follow.pos(props.ease) - _origin
	queue_redraw()


func active_path() -> bool:
	return follow.pts.size() >= 2


func _awaken() -> void:
	awake = true
	_finishing = false
	_fx()
	if int(props.awake) == 1:
		_spawn_dummy()
	_update_solid()
	emit_event("awakened")


func _freeze() -> void:
	awake = false
	match int(props.lost):
		Lost.RETURN:
			follow.setup(follow.pts, follow.closed, props.mode)
			body.position = Vector2.ZERO
			body.reset_physics_interpolation()
		Lost.FINISH:
			if int(props.awake) == 0 and active_path() and not follow.finished:
				_finishing = true
	if _dummy != null:
		if int(props.lost) == Lost.FREEZE:
			body.position = to_local(_dummy.global_position)
		elif int(props.lost) == Lost.FINISH:
			return   # манекен продолжает жить
		_dummy.queue_free()
		_dummy = null
	_fx()
	_update_solid()
	if not _finishing:
		_frame = 0
		emit_event("froze")


func _fx() -> void:
	if props.fx_flash:
		_flash = lp.awaken_flash_time
	if props.fx_shake:
		_shake = lp.awaken_shake_time


func _spawn_dummy() -> void:
	if _dummy != null:
		return
	_dummy = DummyScript.new()
	_dummy.behavior_override = 1
	_dummy.contact_override = props.contact_damage
	_dummy.set("skin_node", self)
	get_parent().add_child(_dummy)
	_dummy.global_position = global_position + body.position
	if runtime != null:
		_dummy.kill_y = runtime.level.kill_y


func _snap() -> Dictionary:
	return {"awake": awake, "i": follow.i, "dirn": follow.dirn, "u": follow.u, "fin": follow.finished, "bp": body.position, "painted": _painted}


func _restore(d: Dictionary) -> void:
	if _dummy != null:
		_dummy.queue_free()
		_dummy = null
	awake = d.get("awake", false)
	follow.i = d.get("i", 0)
	follow.dirn = d.get("dirn", 1)
	follow.u = d.get("u", 0.0)
	follow.finished = d.get("fin", false)
	body.position = d.get("bp", Vector2.ZERO)
	body.reset_physics_interpolation()
	_painted = d.get("painted", false)
	_finishing = false
	if awake and int(props.awake) == 1:
		_spawn_dummy()
	_update_solid()


func _draw() -> void:
	if _dummy != null and is_instance_valid(_dummy):
		draw_set_transform(to_local(_dummy.global_position))
	else:
		var off := Vector2.ZERO
		if _shake > 0.0:
			off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * lp.awaken_shake
		draw_set_transform(body.position + off)
	var tint := Color.WHITE
	if props.fx_tint:
		tint = lp.awaken_tint if (awake or _finishing) else lp.frozen_tint
	if not _frames.is_empty():
		var tex: Texture2D = _frames[clampi(_frame, 0, _frames.size() - 1)]
		var sz: Vector2 = tex.get_size() * props.image_scale
		draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, tint)
	else:
		var col: Color = props.color * tint
		if _closed and _form.size() >= 3:
			# «многоногость»: при оживании контур чуть дрожит по кадрам
			var pts := _form
			if (awake or _finishing) and _frame % 2 == 1:
				pts = Transform2D(0.0, Vector2(1.02, 0.98), 0.0, Vector2.ZERO) * _form
			draw_colored_polygon(pts, Color(col, 0.85))
			var o := pts.duplicate()
			o.append(pts[0])
			draw_polyline(o, Color(0.15, 0.08, 0.05, 0.9), 3.0)
		else:
			draw_polyline(_form, col, 6.0)
	if _flash > 0.0 and lp.awaken_flash_time > 0.0:
		var k: float = _flash / lp.awaken_flash_time
		var o2 := _form.duplicate()
		if _closed and o2.size() > 0:
			o2.append(_form[0])
		draw_polyline(o2, Color(1, 0.95, 0.8, k), 4.0 + 14.0 * (1.0 - k))
	draw_set_transform(Vector2.ZERO)
	_draw_debug()


func _debug() -> String:
	return ("ожила" if awake else "замерла") + (" (свет есть)" if _cond else "")
