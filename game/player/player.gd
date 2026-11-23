extends CharacterBody2D
## Герой: движение + ближняя атака + линия-охра + волна + здоровье + камера.
## Все числа берутся из наборов параметров (Params.get_res(...)), поэтому их можно менять на лету.
## Чтобы создать героя в игре:  var pl := PlayerScript.new(); pl.spawn_pos = ...; add_child(pl)

signal hit_landed(target: Node)
signal died
## После любого возврата на точку возрождения (смерть, падение, R). Уровень восстанавливает снимки объектов.
signal respawned
## Смерть без урона: падение ниже kill_y, смертельная зона (уровень вызывает fall_death), зажатие.
signal fell

const MovementParams := preload("res://data/movement_params.gd")
const AttackParams := preload("res://data/attack_params.gd")
const InkParams := preload("res://data/ink_params.gd")
const WaveParams := preload("res://data/wave_params.gd")
const BrushParams := preload("res://data/brush_params.gd")
const CameraParams := preload("res://data/camera_params.gd")
const Aim := preload("res://core/aim.gd")
const Charge := preload("res://core/charge.gd")
const StrokeScript := preload("res://game/ink/ink_stroke.gd")
const WaveScript := preload("res://game/ink/wave_stroke.gd")

const Layers := preload("res://core/layers.gd")
const WORLD_LAYER := Layers.WORLD
const ENEMY_LAYER := Layers.ENEMY
const PLAYER_LAYER := Layers.PLAYER
const SOLID_MASK := Layers.SOLID   ## мир + штрихи: тело, зажатие, прижатие волны к земле

enum Atk { NONE, WINDUP, ACTIVE, RECOVERY }
enum Wv { NONE, WINDUP, RECOVERY, CHARGE }
enum Ink { NONE, CHARGE }

var m: MovementParams
var a: AttackParams
var ink: InkParams
var w: WaveParams
var br: BrushParams
var cp: CameraParams
var spawn_pos := Vector2(100, 580)
## Пока true, герой не реагирует на клавиши (например, когда печатаешь число в панели).
var input_locked := false
## Уровень (game/level/level_runtime.gd) задаёт свою высоту смерти и границы камеры.
## NAN / пустой прямоугольник — как раньше: world.kill_y и camera.limit_bottom.
var kill_y := NAN
var camera_bounds := Rect2()
## Внешний множитель скорости бега (удержание у рисуемого контура, факел в руках). 1 — как обычно.
var move_mult_ext := 1.0
## Пока true — удар, линия и волна недоступны (например, герой несёт факел).
var skills_locked := false
## Отключённые сценарием приёмы: {"attack": true, "ink": true, "wave": true} (level_script.set_ability).
var skills_off := {}
## Камера из сценария (level_script, фаза 4): множитель масштаба, добавочное смещение, точка показа и её вес
## (0 — камера на герое, 1 — на точке), прямоугольник-замок (пустой — границы уровня).
var cam_zoom_mult := 1.0
var cam_extra_offset := Vector2.ZERO
var cam_focus := Vector2.ZERO
var cam_focus_w := 0.0
var cam_lock := Rect2()
## Сколько физических кадров подряд героя зажимает движущийся объект (см. _check_crush).
var _crush_frames := 0
var _crush_query := PhysicsShapeQueryParameters2D.new()
var _crush_shape := RectangleShape2D.new()

# движение
var facing := 1
var coyote := 0.0
var buffer := 0.0
var air_jumps_left := 0
var wall_lock := 0.0
var lock_dir := 0.0
var on_ice := false
var state := "idle"
var in_jump := false
var jump_start := Vector2.ZERO
var jump_top := 0.0
var jump_time := 0.0
var last_jump_text := "—"
var max_speed_seen := 0.0

# бой
var hp := 100.0
var dead := false
var dead_timer := 0.0
var invuln := 0.0
var stun := 0.0
var atk_phase := Atk.NONE
var atk_t := 0.0
var atk_cd := 0.0
var atk_buffer := 0.0
var atk_facing := 1
var atk_hit: Array = []
var swings := 0
var hits_landed := 0
var last_hit_text := "—"

# линия
var ink_amount := 0.0
var ink_cd := 0.0
var ink_idle := 0.0
var ink_buffer := 0.0
var ink_phase := Ink.NONE
var ink_hold := 0.0
var ink_stalled := false
var strokes: Array = []

# волна
var wave_phase := Wv.NONE
var wave_t := 0.0
var wave_cd := 0.0
var wave_buffer := 0.0
var wave_side := 1
var waves: Array = []
var wave_hold := 0.0
var wave_dir := Vector2.RIGHT
var wave_size: Dictionary = {}
var wave_cost := 0.0
var wave_stalled := false

var trail: Line2D
var cam: Camera2D
var _tick := 0
var _shake_end := 0
var _shake_total := 0.1
var _shake_amount := 0.0
var _look := 1.0
var _wave_preview: Dictionary = {}   # считается в физике (лучи нельзя пускать из _draw)

var _body_shape := RectangleShape2D.new()
var _atk_shape := RectangleShape2D.new()
var _atk_query := PhysicsShapeQueryParameters2D.new()
var _body_query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	m = Params.get_res("movement")
	a = Params.get_res("attack")
	ink = Params.get_res("ink")
	w = Params.get_res("wave")
	br = Params.get_res("brush")
	cp = Params.get_res("camera")
	add_to_group("player")
	collision_layer = PLAYER_LAYER
	collision_mask = SOLID_MASK

	_body_shape.size = _safe_size(m.body_width, m.body_height)
	var cs := CollisionShape2D.new()
	cs.shape = _body_shape
	add_child(cs)

	_atk_query.shape = _atk_shape
	_atk_query.collision_mask = ENEMY_LAYER
	_atk_query.collide_with_areas = false
	_body_query.shape = _body_shape
	_body_query.collision_mask = ENEMY_LAYER
	_body_query.collide_with_areas = false

	cam = Camera2D.new()
	add_child(cam)
	_apply_camera()

	trail = Line2D.new()
	trail.top_level = true
	trail.width = 3.0
	trail.default_color = Color(1.0, 0.8, 0.25, 0.75)
	add_child(trail)
	trail.global_position = Vector2.ZERO

	Fx.shake_requested.connect(_on_shake)
	hp = a.max_hp
	ink_amount = ink.max_ink


## Размер коллизии не может быть нулевым или отрицательным — иначе движок ругается и физика ломается.
static func _safe_size(x: float, y: float) -> Vector2:
	return Vector2(maxf(x, 1.0), maxf(y, 1.0))


# ------------------------------------------------------------ ввод

func _pressed(action: String) -> bool:
	return not input_locked and Input.is_action_pressed(action)

func _just(action: String) -> bool:
	return not input_locked and Input.is_action_just_pressed(action)


# Ввод линии и волны идёт через _unhandled_input: клики по панели настроек их не вызывают.
func _unhandled_input(event: InputEvent) -> void:
	if input_locked or event.is_echo():
		return
	if event.is_action_pressed("wave"):
		wave_buffer = maxf(w.input_buffer, 0.02)
	if event.is_action_pressed("ink"):
		ink_buffer = maxf(ink.input_buffer, 0.02)


# ------------------------------------------------------------ камера

func _on_shake(amount: float, seconds: float) -> void:
	_shake_amount = amount * cp.shake_mult
	_shake_total = seconds
	_shake_end = Time.get_ticks_msec() + int(seconds * 1000.0)


func _apply_camera() -> void:
	cam.position_smoothing_enabled = cp.smoothing
	cam.position_smoothing_speed = cp.smoothing_speed
	var lim := cam_lock if cam_lock.has_area() else camera_bounds
	if lim.has_area():
		cam.limit_left = int(lim.position.x)
		cam.limit_top = int(lim.position.y)
		cam.limit_right = int(lim.end.x)
		cam.limit_bottom = int(lim.end.y)
	else:
		cam.limit_bottom = int(cp.limit_bottom)
	cam.zoom = Vector2.ONE * maxf(cp.zoom * cam_zoom_mult, 0.01)


func _process(delta: float) -> void:
	_apply_camera()
	var look_target := float(facing) if cp.follow_facing else 1.0
	_look = move_toward(_look, look_target, cp.look_speed * delta)
	var base := Vector2(cp.offset_x * _look, -cp.offset_y) + cam_extra_offset
	if cam_focus_w > 0.0:
		base = base.lerp(cam_focus - global_position, clampf(cam_focus_w, 0.0, 1.0))
	var now := Time.get_ticks_msec()
	if now < _shake_end:
		var k := float(_shake_end - now) / maxf(_shake_total * 1000.0, 1.0)
		cam.offset = base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount * k
	else:
		cam.offset = base


func reset(full: bool = true) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	coyote = 0.0
	buffer = 0.0
	wall_lock = 0.0
	in_jump = false
	atk_phase = Atk.NONE
	wave_phase = Wv.NONE
	ink_phase = Ink.NONE
	stun = 0.0
	invuln = 0.0
	max_speed_seen = 0.0
	if full:
		dead = false
		hp = a.max_hp
		ink_amount = ink.max_ink
		for s in strokes + waves:
			if is_instance_valid(s):
				s.queue_free()
		strokes.clear()
		waves.clear()
	trail.clear_points()
	cam.reset_smoothing()
	_crush_frames = 0
	respawned.emit()


# ------------------------------------------------------------ для объектов уровня (фаза 2)

func add_ink(amount: float) -> void:
	ink_amount = clampf(ink_amount + amount, 0.0, ink.max_ink)


func get_ink() -> float:
	return ink_amount


func get_max_ink() -> float:
	return ink.max_ink


## Списать охру. false — не хватает (ничего не списано).
func spend_ink(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if ink_amount < amount:
		return false
	ink_amount -= amount
	ink_idle = 0.0
	return true


func set_respawn_point(pos: Vector2) -> void:
	spawn_pos = pos


## Лечение. amount < 0 — полностью.
func heal(amount: float = -1.0) -> void:
	hp = a.max_hp if amount < 0.0 else minf(hp + amount, a.max_hp)


func get_hp() -> float:
	return hp


## Стоит ли герой на теле body (сверху).
func standing_on(body: Object) -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() == body and c.get_normal().y < -0.6:
			return true
	return false


## Зажат движущимся объектом (группа "crusher": платформы, двери)? Тогда вытолкнуть или погибнуть (вкладка «Объекты»).
func _check_crush() -> void:
	var op: Resource = Params.get_res("objects")
	_crush_shape.size = _safe_size(m.body_width - 4.0, m.body_height - 4.0)
	_crush_query.shape = _crush_shape
	_crush_query.collision_mask = SOLID_MASK
	_crush_query.transform = Transform2D(0.0, global_position)
	var crushed := false
	for r in get_world_2d().direct_space_state.intersect_shape(_crush_query, 8):
		var c: Object = r["collider"]
		if c is CollisionObject2D and (c as Node).is_in_group("crusher"):
			var owner_id: int = c.shape_find_owner(r["shape"])
			var sh = c.shape_owner_get_owner(owner_id)
			if sh is CollisionShape2D and sh.one_way_collision:
				continue
			if sh is CollisionPolygon2D and sh.one_way_collision:
				continue
			crushed = true
			break
	_crush_frames = _crush_frames + 1 if crushed else 0
	if _crush_frames < maxi(op.crush_frames, 1):
		return
	_crush_frames = 0
	if op.crush_mode == 1:
		fell.emit()
		reset(false)
		return
	var step := 4.0
	var d := step
	while d <= op.crush_push:
		for dir in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
			var at: Vector2 = global_position + dir * d
			_crush_query.transform = Transform2D(0.0, at)
			if get_world_2d().direct_space_state.intersect_shape(_crush_query, 1).is_empty():
				global_position = at
				velocity = Vector2.ZERO
				return
		d += step
	fell.emit()
	reset(false)


# ------------------------------------------------------------ физика

func _physics_process(delta: float) -> void:
	if dead:
		dead_timer -= delta
		if dead_timer <= 0.0:
			reset(true)
		queue_redraw()
		return
	if global_position.y > (Params.world.kill_y if is_nan(kill_y) else kill_y):
		fell.emit()
		reset(false)
		return

	_body_shape.size = _safe_size(m.body_width, m.body_height)
	invuln = maxf(invuln - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	floor_max_angle = deg_to_rad(m.max_slope_deg)
	var can_act := stun <= 0.0

	var dir := 0.0 if input_locked else Input.get_axis("left", "right")
	if wall_lock > 0.0:
		wall_lock -= delta
		dir = lock_dir
	if not can_act:
		dir = 0.0
	if dir != 0.0 and atk_phase == Atk.NONE:
		facing = 1 if dir > 0.0 else -1

	var on_floor := is_on_floor()
	var holding := _pressed("jump")

	var can_skill := can_act and not skills_locked
	_update_attack(delta, can_skill and not skills_off.get("attack", false), on_floor)
	_update_ink(delta, can_skill and not skills_off.get("ink", false))
	_update_wave(delta, can_skill and not skills_off.get("wave", false))
	var move_mult := maxf(move_mult_ext, 0.0)
	if atk_phase != Atk.NONE:
		move_mult = minf(move_mult, a.move_mult)
	if ink_phase == Ink.CHARGE:
		move_mult = minf(move_mult, ink.charge_move_mult)
	if wave_phase == Wv.CHARGE:
		move_mult = minf(move_mult, w.charge_move_mult)
	elif wave_phase != Wv.NONE:
		move_mult = minf(move_mult, w.cast_move_mult)

	# --- таймеры прыжка ---
	if on_floor:
		coyote = m.coyote_time
		air_jumps_left = m.air_jumps
	else:
		coyote -= delta
	if _just("jump"):
		buffer = maxf(m.jump_buffer, delta)
	else:
		buffer -= delta

	# --- стены ---
	var wall_dir := 0
	if m.wall_enabled and is_on_wall_only():
		wall_dir = -int(signf(get_wall_normal().x))
	var wall_sliding := wall_dir != 0 and absf(dir) > 0.1 and int(signf(dir)) == wall_dir and velocity.y > 0.0

	# --- гравитация: g = 2h/t², v0 = 2h/t ---
	var h: float = m.jump_height
	var t: float = maxf(m.time_to_apex, 0.01)
	var g := 2.0 * h / (t * t)
	var jump_v := 2.0 * h / t
	var grav := g
	if velocity.y > 0.0:
		grav *= m.fall_mult
	elif not holding:
		grav *= m.cut_mult
	if not on_floor and holding and absf(velocity.y) < m.apex_threshold:
		grav *= m.apex_mult
	velocity.y += grav * delta
	velocity.y = minf(velocity.y, m.max_fall)
	if wall_sliding:
		velocity.y = minf(velocity.y, m.wall_slide_speed)

	# --- прыжок ---
	var jump_ok := can_act and (atk_phase == Atk.NONE or (atk_phase == Atk.RECOVERY and a.jump_cancel))
	if buffer > 0.0 and jump_ok:
		var jumped := false
		if on_floor or coyote > 0.0:
			velocity.y = -jump_v
			coyote = 0.0
			jumped = true
		elif wall_dir != 0:
			velocity.y = -jump_v
			velocity.x = -wall_dir * m.wall_jump_x
			lock_dir = -float(wall_dir)
			wall_lock = m.wall_jump_lock
			facing = -wall_dir
			jumped = true
		elif air_jumps_left > 0:
			air_jumps_left -= 1
			velocity.y = -jump_v
			jumped = true
		if jumped:
			buffer = 0.0
			if atk_phase == Atk.RECOVERY:
				atk_phase = Atk.NONE
				atk_cd = 0.0
			in_jump = true
			jump_start = global_position
			jump_top = global_position.y
			jump_time = 0.0

	# --- горизонталь ---
	var target := dir * m.run_speed * move_mult
	var turning := dir != 0.0 and velocity.x != 0.0 and signf(dir) != signf(velocity.x)
	var braking := dir == 0.0 or target == 0.0
	var accel: float
	if on_floor:
		accel = m.ground_decel if braking else m.ground_accel
		if on_ice:
			accel *= m.ice_friction
	else:
		accel = m.air_decel if braking else m.air_accel
	if turning and not braking:
		accel *= m.turn_mult
	velocity.x = move_toward(velocity.x, target, accel * delta)

	move_and_slide()

	# --- лёд под ногами (блоки с meta "ice") ---
	on_ice = false
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var col := c.get_collider()
			if c.get_normal().y < -0.7 and col != null and col.has_meta("ice"):
				on_ice = true

	# --- бой после перемещения ---
	if atk_phase == Atk.ACTIVE:
		_attack_hits()
	_check_contact()
	_check_crush()

	# --- измерения прыжка ---
	max_speed_seen = maxf(max_speed_seen, absf(velocity.x))
	if in_jump:
		jump_time += delta
		jump_top = minf(jump_top, global_position.y)
		if is_on_floor() and jump_time > 0.06:
			in_jump = false
			var hh := maxf(jump_start.y - jump_top, 0.0)
			var dd := absf(global_position.x - jump_start.x)
			last_jump_text = "высота %d px (%.1f T) | дальность %d px (%.1f T) | в воздухе %.2f с" % [int(hh), hh / 32.0, int(dd), dd / 32.0, jump_time]  # loc: dev — HUD плейграунда

	# --- состояние ---
	if atk_phase != Atk.NONE:
		state = "attack"
	elif wave_phase == Wv.CHARGE or ink_phase == Ink.CHARGE:
		state = "charge"
	elif wave_phase != Wv.NONE:
		state = "wave"
	elif wall_sliding:
		state = "wall"
	elif is_on_floor():
		state = "ice" if on_ice else ("run" if absf(velocity.x) > 10.0 else "idle")
	else:
		state = "rise" if velocity.y < 0.0 else "fall"

	_update_wave_preview()
	_tick += 1
	var show_trail: bool = Params.world.show_trail
	trail.visible = show_trail
	if show_trail and _tick % 2 == 0:
		trail.add_point(global_position)
		while trail.get_point_count() > maxi(Params.world.trail_points, 0):
			trail.remove_point(0)
	queue_redraw()


# ------------------------------------------------------------ атака

func _update_attack(delta: float, can_act: bool, on_floor: bool) -> void:
	atk_cd = maxf(atk_cd - delta, 0.0)
	if _just("attack"):
		atk_buffer = maxf(a.buffer, delta)
	else:
		atk_buffer -= delta

	if atk_phase == Atk.NONE and wave_phase == Wv.NONE and can_act and atk_buffer > 0.0 and atk_cd <= 0.0 and (on_floor or a.allow_air):
		atk_phase = Atk.WINDUP
		atk_t = a.windup
		atk_buffer = 0.0
		atk_facing = facing
		atk_hit.clear()
		swings += 1

	if atk_phase != Atk.NONE:
		atk_t -= delta
		if atk_t <= 0.0:
			match atk_phase:
				Atk.WINDUP:
					atk_phase = Atk.ACTIVE
					atk_t = a.active
					if a.lunge_speed > 0.0:
						velocity.x = atk_facing * a.lunge_speed
				Atk.ACTIVE:
					atk_phase = Atk.RECOVERY
					atk_t = a.recovery
				Atk.RECOVERY:
					atk_phase = Atk.NONE
					atk_cd = a.cooldown


func _attack_rect() -> Rect2:
	var size := Vector2(a.reach_x, a.reach_y)
	var center := Vector2(atk_facing * (a.offset_x + a.reach_x * 0.5), a.offset_y)
	return Rect2(center - size * 0.5, size)


func _attack_hits() -> void:
	var r := _attack_rect()
	_atk_shape.size = _safe_size(absf(r.size.x), absf(r.size.y))
	_atk_query.transform = Transform2D(0.0, global_position + r.get_center())
	Events.hit_area.emit(Rect2(global_position + r.position, r.size).abs(), "melee", self)
	for hit in get_world_2d().direct_space_state.intersect_shape(_atk_query, 16):
		var target: Object = hit["collider"]
		if target == null or atk_hit.has(target) or not target.has_method("take_hit"):
			continue
		atk_hit.append(target)
		var info := {
			"damage": a.damage,
			"knockback": Vector2(atk_facing * a.knockback_x, -a.knockback_y),
			"kind": "melee",
		}
		if target.take_hit(info):
			hits_landed += 1
			last_hit_text = "урон %d по «%s»" % [int(a.damage), target.name]  # loc: dev — HUD плейграунда
			velocity.x -= atk_facing * a.self_recoil
			Fx.hitstop(a.hitstop)
			Fx.shake(a.hit_shake, a.hit_shake_time)
			hit_landed.emit(target)


# ------------------------------------------------------------ получение урона

func _check_contact() -> void:
	if invuln > 0.0:
		return
	_body_query.transform = Transform2D(0.0, global_position)
	for r in get_world_2d().direct_space_state.intersect_shape(_body_query, 8):
		var c: Object = r["collider"]
		if c != null and c.has_method("contact_damage_amount"):
			var dmg: float = c.contact_damage_amount()
			if dmg > 0.0:
				take_damage(dmg, c.global_position.x)
				return


func take_damage(amount: float, from_x: float) -> void:
	if invuln > 0.0 or dead:
		return
	hp = maxf(hp - amount, 0.0)
	invuln = a.invuln_time
	stun = a.hurt_stun
	var sgn := signf(global_position.x - from_x)
	if sgn == 0.0:
		sgn = -float(facing)
	velocity = Vector2(sgn * a.hurt_knockback_x, -a.hurt_knockback_y)
	atk_phase = Atk.NONE
	wave_phase = Wv.NONE
	ink_phase = Ink.NONE
	Fx.hitstop(a.hurt_hitstop)
	Fx.shake(a.hurt_shake, a.hurt_shake_time)
	if hp <= 0.0:
		dead = true
		dead_timer = a.respawn_delay
		velocity = Vector2.ZERO
		died.emit()


# ------------------------------------------------------------ линия-охра

func _update_ink(delta: float, can_act: bool) -> void:
	ink_cd = maxf(ink_cd - delta, 0.0)
	ink_idle += delta
	ink_buffer -= delta
	strokes = strokes.filter(func(s): return is_instance_valid(s))
	var charging := ink_phase == Ink.CHARGE or wave_phase == Wv.CHARGE
	var regen_ok := not charging or ink.regen_while_charging
	if regen_ok and ink_idle >= ink.regen_delay and ink_amount < ink.max_ink:
		ink_amount = minf(ink_amount + ink.regen_rate * delta, ink.max_ink)
	match ink_phase:
		Ink.NONE:
			if can_act and ink_buffer > 0.0 and ink_cd <= 0.0 and ink_amount >= ink.cost and wave_phase != Wv.CHARGE:
				ink_buffer = 0.0
				if ink.charge_enabled:
					ink_phase = Ink.CHARGE
					ink_hold = 0.0
					ink_stalled = false
				else:
					_draw_stroke(0.0)
		Ink.CHARGE:
			var t := Charge.tick(ink, ink_hold, ink_amount, ink.cost, delta)
			ink_hold = t["hold"]
			ink_stalled = t["stalled"]
			if t["ink"] < ink_amount:
				ink_amount = t["ink"]
				ink_idle = 0.0
			facing = Aim.resolve(ink, self, facing)["side"]
			var full := Charge.raw(ink, ink_hold) >= 1.0 or ink_stalled
			if not can_act:
				ink_phase = Ink.NONE
			elif not _pressed("ink") or (ink.auto_release and full):
				_draw_stroke(Charge.eased(ink, ink_hold))


## Точка старта приёма относительно центра героя: origin_x вперёд (зеркалится), origin_y вверх.
func _origin(p: Resource, side: int) -> Vector2:
	return global_position + Vector2(p.origin_x * side, -p.origin_y)


func _ink_size(c: float) -> Dictionary:
	var sz := StrokeScript.base_size(ink)
	sz["length"] = ink.length * Charge.mult(ink, "length", c)
	sz["thickness"] = ink.thickness * Charge.mult(ink, "thick", c)
	sz["damage"] = ink.damage * Charge.mult(ink, "damage", c)
	sz["knock"] = Charge.mult(ink, "knock", c)
	sz["draw_time"] = ink.draw_time * Charge.mult(ink, "draw", c)
	return sz


func ink_status() -> String:  # loc: dev — HUD плейграунда
	if ink_phase != Ink.CHARGE:
		return "—"
	var c := Charge.eased(ink, ink_hold)
	var sz := _ink_size(c)
	return "заряд %d%%%s: длина %d, урон %d, охра %d" % [
		int(Charge.raw(ink, ink_hold) * 100.0), " (охра кончилась)" if ink_stalled else "",
		int(sz["length"]), int(sz["damage"]), int(Charge.release_cost(ink, ink.cost, Charge.affordable(ink, ink.cost, ink_amount, c)))]


func _draw_stroke(c: float) -> void:
	c = Charge.affordable(ink, ink.cost, ink_amount, c)
	var aim := Aim.resolve(ink, self, facing)
	var dir: Vector2 = aim["dir"]
	facing = aim["side"]
	var start := _origin(ink, aim["side"]) + dir * ink.start_gap
	while strokes.size() >= maxi(ink.max_strokes, 1):
		var old = strokes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var s := StrokeScript.new()
	get_parent().add_child(s)
	s.setup(ink, start, dir, br, _ink_size(c))
	strokes.append(s)
	Events.stroke_spawned.emit(s)
	ink_amount = maxf(ink_amount - Charge.release_cost(ink, ink.cost, c), 0.0)
	ink_cd = ink.cooldown
	ink_idle = 0.0
	ink_phase = Ink.NONE
	ink_hold = 0.0


# ------------------------------------------------------------ волна

func _wave_size(c: float) -> Dictionary:
	var sz := WaveScript.base_size(w)
	sz["reach"] = w.reach * Charge.mult(w, "reach", c)
	sz["height"] = w.height * Charge.mult(w, "height", c)
	sz["extra"] = w.wall_extra * Charge.mult(w, "wall", c)
	sz["thickness"] = w.thickness * Charge.mult(w, "thick", c)
	sz["damage"] = w.damage * Charge.mult(w, "damage", c)
	sz["knock"] = Charge.mult(w, "knock", c)
	return sz


func wave_status() -> String:  # loc: dev — HUD плейграунда
	var aim := Aim.resolve(w, self, facing)
	var line := "угол %d° (база %d°)" % [int(aim["angle"]), int(w.base_angle)]
	if wave_phase == Wv.CHARGE and w.charge_enabled:
		var c := Charge.eased(w, wave_hold)
		var sz := _wave_size(c)
		line += "\nзаряд %d%%%s: длина %d, высота %d, урон %d, охра %d" % [
			int(Charge.raw(w, wave_hold) * 100.0), " (охра кончилась)" if wave_stalled else "",
			int(sz["reach"]), int(sz["height"]), int(sz["damage"]),
			int(Charge.release_cost(w, w.ink_cost, Charge.affordable(w, w.ink_cost, ink_amount, c)))]
	return line


func _update_wave(delta: float, can_act: bool) -> void:
	wave_cd = maxf(wave_cd - delta, 0.0)
	wave_buffer -= delta
	waves = waves.filter(func(s): return is_instance_valid(s))
	match wave_phase:
		Wv.NONE:
			if can_act and wave_buffer > 0.0 and wave_cd <= 0.0 and atk_phase == Atk.NONE and ink_phase == Ink.NONE and ink_amount >= w.ink_cost:
				wave_buffer = 0.0
				if w.charge_enabled:
					wave_phase = Wv.CHARGE
					wave_hold = 0.0
					wave_stalled = false
				else:
					_begin_wave(0.0)
		Wv.CHARGE:
			var t := Charge.tick(w, wave_hold, ink_amount, w.ink_cost, delta)
			wave_hold = t["hold"]
			wave_stalled = t["stalled"]
			if t["ink"] < ink_amount:
				ink_amount = t["ink"]
				ink_idle = 0.0
			facing = Aim.resolve(w, self, facing)["side"]
			var full := Charge.raw(w, wave_hold) >= 1.0 or wave_stalled
			if not can_act:
				wave_phase = Wv.NONE
			elif not _pressed("wave") or (w.auto_release and full):
				_begin_wave(Charge.eased(w, wave_hold))
		Wv.WINDUP:
			wave_t -= delta
			if wave_t <= 0.0:
				_spawn_wave()
				wave_phase = Wv.RECOVERY
				wave_t = w.recovery
		Wv.RECOVERY:
			wave_t -= delta
			if wave_t <= 0.0:
				wave_phase = Wv.NONE
				wave_cd = w.cooldown


## Фиксирует направление и размер волны в момент отпускания и запускает замах.
func _begin_wave(c: float) -> void:
	c = Charge.affordable(w, w.ink_cost, ink_amount, c)
	var aim := Aim.resolve(w, self, facing)
	wave_side = aim["side"]
	wave_dir = aim["dir"]
	wave_size = _wave_size(c)
	wave_cost = Charge.release_cost(w, w.ink_cost, c)
	facing = wave_side
	wave_phase = Wv.WINDUP
	wave_t = w.windup
	wave_hold = 0.0
	if wave_t <= 0.0:
		_spawn_wave()
		wave_phase = Wv.RECOVERY
		wave_t = w.recovery


## Точка основания волны (мировые координаты): старт + отступ, при необходимости прижата к земле.
func _wave_origin(d: Vector2, side: int) -> Vector2:
	var origin := _origin(w, side) + d * w.start_gap
	if w.snap_to_ground:
		var q := PhysicsRayQueryParameters2D.create(origin + Vector2(0, -w.snap_up), origin + Vector2(0, w.snap_down), SOLID_MASK)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			origin.y = hit["position"].y
	return origin


func _spawn_wave() -> void:
	while waves.size() >= maxi(w.max_waves, 1):
		var old = waves.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var sz := wave_size.duplicate()
	if w.shape_random > 0.0:
		sz["reach"] = float(sz["reach"]) * (1.0 + randf_range(-w.shape_random, w.shape_random))
		sz["height"] = float(sz["height"]) * (1.0 + randf_range(-w.shape_random, w.shape_random))
	var s := WaveScript.new()
	get_parent().add_child(s)
	s.setup(w, br, _wave_origin(wave_dir, wave_side), wave_dir, wave_side, sz)
	waves.append(s)
	Events.stroke_spawned.emit(s)
	ink_amount = maxf(ink_amount - wave_cost, 0.0)
	ink_idle = 0.0
	Fx.shake(w.spawn_shake * clampf(float(sz["damage"]) / maxf(w.damage, 0.01), 1.0, 3.0), w.spawn_shake_time)


func _update_wave_preview() -> void:
	_wave_preview = {}
	if skills_off.get("wave", false) or skills_locked:
		return
	if not w.show_preview or not (wave_phase == Wv.NONE or wave_phase == Wv.CHARGE):
		return
	if wave_phase == Wv.NONE and (ink_amount < w.ink_cost or wave_cd > 0.0):
		return
	var aim := Aim.resolve(w, self, facing)
	var chg := Charge.eased(w, wave_hold) if wave_phase == Wv.CHARGE else 0.0
	var d: Vector2 = aim["dir"]
	var side: int = aim["side"]
	var pv := WaveScript.make_points(w, d, side, _wave_size(chg))
	var off := _wave_origin(d, side) - global_position
	for i in range(pv.size()):
		pv[i] += off
	_wave_preview = {"points": pv, "charge": chg}


# ------------------------------------------------------------ отрисовка

func _draw() -> void:
	if dead:
		return
	if invuln > 0.0 and _tick % 6 < 3:
		return
	var c := Color(0.49, 0.88, 0.5)
	match state:
		"wall":
			c = Color(0.4, 0.8, 1.0)
		"ice":
			c = Color(0.7, 0.95, 1.0)
		"rise", "fall":
			c = Color(1.0, 0.72, 0.3)
		"attack":
			c = Color(1.0, 0.55, 0.55)
		"wave":
			c = Color(1.0, 0.5, 0.4)
		"charge":
			c = Color(1.0, 0.65, 0.3)
	var body := Rect2(-m.body_width * 0.5, -m.body_height * 0.5, m.body_width, m.body_height)
	draw_rect(body, c)
	draw_rect(body, Color(0, 0, 0, 0.6), false, 2.0)
	var eye_x := body.end.x - 10.0 if facing > 0 else body.position.x + 2.0
	draw_rect(Rect2(eye_x, body.position.y + 8.0, 8, 8), Color.WHITE)
	if Params.world.show_velocity:
		draw_line(Vector2.ZERO, velocity * 0.12, Color(1, 0.3, 0.3), 2.0)

	# хитбокс атаки
	if atk_phase != Atk.NONE:
		var rect := _attack_rect()
		if atk_phase == Atk.ACTIVE:
			draw_rect(rect, Color(1.0, 0.3, 0.2, 0.45))
			var p0 := rect.position if atk_facing > 0 else rect.position + Vector2(rect.size.x, 0)
			var p1 := rect.end if atk_facing > 0 else rect.position + Vector2(0, rect.size.y)
			draw_line(p0, p1, Color(1, 1, 1, 0.9), 3.0)
			if Fx.debug_hitboxes:
				draw_rect(rect, Color(1, 0.2, 0.2, 0.9), false, 2.0)
		elif Fx.debug_hitboxes:
			var col := Color(1.0, 0.9, 0.3, 0.7) if atk_phase == Atk.WINDUP else Color(0.7, 0.7, 0.7, 0.5)
			draw_rect(rect, col, false, 2.0)

	# предпросмотр штриха
	var ink_chg := Charge.eased(ink, ink_hold) if ink_phase == Ink.CHARGE else 0.0
	if ink.show_preview and not skills_off.get("ink", false) and not skills_locked and (ink_phase == Ink.CHARGE or (ink_amount >= ink.cost and ink_cd <= 0.0)):
		var ia := Aim.resolve(ink, self, facing)
		var d: Vector2 = ia["dir"]
		var o := _origin(ink, ia["side"]) - global_position + d * ink.start_gap
		var isz := _ink_size(ink_chg)
		draw_line(o, o + d * float(isz["length"]), Color(ink.color, 0.25 + 0.5 * ink_chg), 2.0 + 0.3 * float(isz["thickness"]) * ink_chg)
	if ink_phase == Ink.CHARGE:
		var col := Color(0.6, 0.6, 0.6) if ink_stalled else ink.color.lightened(0.3)
		draw_arc(Vector2(0, -m.body_height * 0.5 - 14.0), 9.0, -PI * 0.5, -PI * 0.5 + TAU * Charge.raw(ink, ink_hold), 24, col, 3.0)

	# предпросмотр волны (бледная линия) и кольцо заряда
	if not _wave_preview.is_empty():
		var chg: float = _wave_preview["charge"]
		draw_polyline(_wave_preview["points"], Color(w.color, 0.2 + 0.5 * chg), 2.0 + 3.0 * chg)
	if wave_phase == Wv.NONE or wave_phase == Wv.CHARGE:
		if wave_phase == Wv.CHARGE:
			var frac := Charge.raw(w, wave_hold)
			draw_arc(Vector2(0, -m.body_height * 0.5 - 14.0), 9.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1.0, 0.6, 0.3), 3.0)
