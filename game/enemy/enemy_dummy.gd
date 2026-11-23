extends CharacterBody2D
## Манекен: стоит / патрулирует / таранит с телеграфом и окном уязвимости.
## Параметры: data/dummy_params.gd (общие для всех манекенов).
## Интерфейс цели, который понимают все атаки героя:
##   take_hit(info: {"damage", "knockback", "kind"}) -> bool   — получить удар (true = попадание засчитано)
##   contact_damage_amount() -> float                           — урон при касании героя

enum { B_STAND, B_PATROL, B_CHARGE, B_PATH }
enum { S_IDLE, S_TELE, S_CHARGE, S_RECOVER }

const DummyParams := preload("res://data/dummy_params.gd")
const Layers := preload("res://core/layers.gd")
const WORLD_LAYER := Layers.WORLD
const ENEMY_LAYER := Layers.ENEMY
const SOLID_MASK := Layers.SOLID   ## мир + штрихи: тело и проверка края

var p: DummyParams
var behavior_override := -1
var contact_override := -1.0
var kill_y := NAN   ## уровень задаёт свою высоту смерти; NAN — world.kill_y

var hp := 0.0
var dead := false
var respawn_t := 0.0
var flash := 0.0
var stun := 0.0
var state := S_IDLE
var state_t := 0.0
var dir := 1
var charge_dir := 1
var spawn_pos := Vector2.ZERO
## Патруль по пути (поведение «По пути»): мировые точки пути, замкнут ли.
var path_points := PackedVector2Array()
var path_closed := false
var _path_i := 0
var _path_step := 1
## Уничтожен насовсем (например, закрашен до 100 %) — не возрождается до отката снимка.
var gone := false
## Если задан — манекена рисует этот узел (ожившая картина в режиме «манекен»), сам он рисует только полоску здоровья.
var skin_node: Node = null
var _armor_flash := 0.0
var _shape := RectangleShape2D.new()


func _ready() -> void:
	if p == null:
		p = Params.get_res("dummy")
	collision_layer = ENEMY_LAYER
	collision_mask = SOLID_MASK
	add_to_group("enemy")
	var cs := CollisionShape2D.new()
	_shape.size = Vector2(maxf(p.body_width, 1.0), maxf(p.body_height, 1.0))
	cs.shape = _shape
	add_child(cs)
	spawn_pos = global_position
	hp = p.max_hp


func behavior() -> int:
	return behavior_override if behavior_override >= 0 else p.behavior


func _respawn() -> void:
	dead = false
	hp = p.max_hp
	global_position = spawn_pos
	velocity = Vector2.ZERO
	state = S_IDLE
	collision_layer = ENEMY_LAYER


func _physics_process(delta: float) -> void:
	_shape.size = Vector2(maxf(p.body_width, 1.0), maxf(p.body_height, 1.0))
	if gone:
		return
	if dead:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_respawn()
		queue_redraw()
		return
	if global_position.y > (Params.world.kill_y if is_nan(kill_y) else kill_y):
		_respawn()
		return
	flash = maxf(flash - delta, 0.0)
	_armor_flash = maxf(_armor_flash - delta, 0.0)
	velocity.y = minf(velocity.y + p.gravity * delta, p.max_fall)
	if stun > 0.0:
		stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, p.kb_friction * delta)
	else:
		_ai(delta)
	move_and_slide()
	queue_redraw()


func _ai(delta: float) -> void:
	match behavior():
		B_STAND:
			velocity.x = move_toward(velocity.x, 0.0, p.kb_friction * delta)
		B_PATROL:
			var off := global_position.x - spawn_pos.x
			if absf(off) > p.patrol_range and signf(off) == float(dir):
				dir = -dir
			if is_on_wall() or _ledge_ahead(dir):
				dir = -dir
			velocity.x = dir * p.move_speed
		B_CHARGE:
			_charge_ai(delta)
		B_PATH:
			_path_ai()


## Ходит по точкам пути (по X, как патруль; гравитация остаётся). Открытый путь — туда-обратно, замкнутый — по кругу.
func _path_ai() -> void:
	if path_points.size() < 2:
		velocity.x = 0.0
		return
	_path_i = clampi(_path_i, 0, path_points.size() - 1)
	var target := path_points[_path_i]
	var dx := target.x - global_position.x
	if absf(dx) <= maxf(p.move_speed * 0.05, 4.0) or (is_on_wall() and signf(dx) == float(dir)):
		_path_next()
		target = path_points[_path_i]
		dx = target.x - global_position.x
	dir = 1 if dx > 0.0 else -1
	velocity.x = dir * p.move_speed


func _path_next() -> void:
	var n := path_points.size()
	if path_closed:
		_path_i = (_path_i + 1) % n
		return
	if _path_i + _path_step >= n or _path_i + _path_step < 0:
		_path_step = -_path_step
	_path_i += _path_step


## Убрать насовсем (до отката снимка): закрашен до 100 % и т. п.
func vanish() -> void:
	gone = true
	dead = true
	visible = false
	collision_layer = 0
	velocity = Vector2.ZERO


# ------------------------------------------------------------ снимки (откат при смерти героя)

func resets_on_death() -> bool:
	return true


func snapshot() -> Dictionary:
	return {"hp": hp, "dead": dead, "gone": gone, "pos": global_position, "dir": dir, "path_i": _path_i, "path_step": _path_step}


func restore(d: Dictionary) -> void:
	hp = d.get("hp", p.max_hp)
	dead = d.get("dead", false)
	gone = d.get("gone", false)
	global_position = d.get("pos", spawn_pos)
	dir = d.get("dir", dir)
	_path_i = d.get("path_i", 0)
	_path_step = d.get("path_step", 1)
	velocity = Vector2.ZERO
	state = S_IDLE
	stun = 0.0
	visible = not gone
	collision_layer = 0 if (dead or gone) else ENEMY_LAYER
	if dead and not gone:
		respawn_t = p.respawn_time
	queue_redraw()


func debug_text() -> String:
	return "%s: hp %d%s" % [name, int(hp), " (нет)" if gone else (" (мёртв)" if dead else "")]


func _ledge_ahead(d: int) -> bool:
	if not p.avoid_ledges or not is_on_floor():
		return false
	var from := global_position + Vector2(d * p.ledge_probe_x, p.body_height * 0.5 - 6.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, p.ledge_probe_down), SOLID_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _player() -> Node2D:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and not pl.dead:
		return pl
	return null


func _charge_ai(delta: float) -> void:
	state_t -= delta
	match state:
		S_IDLE:
			velocity.x = move_toward(velocity.x, 0.0, p.kb_friction * delta)
			var pl := _player()
			if pl != null and absf(pl.global_position.x - global_position.x) < p.sight_range and absf(pl.global_position.y - global_position.y) < p.sight_height:
				charge_dir = 1 if pl.global_position.x > global_position.x else -1
				state = S_TELE
				state_t = p.charge_windup
		S_TELE:
			velocity.x = 0.0
			if state_t <= 0.0:
				state = S_CHARGE
				state_t = p.charge_time
		S_CHARGE:
			velocity.x = charge_dir * p.charge_speed
			if state_t <= 0.0 or is_on_wall() or _ledge_ahead(charge_dir):
				state = S_RECOVER
				state_t = p.charge_recover
		S_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, p.charge_speed * p.recover_brake * delta)
			if state_t <= 0.0:
				state = S_IDLE


func take_hit(info: Dictionary) -> bool:
	if dead:
		return false
	var dmg: float = info["damage"]
	var kb: Vector2 = info["knockback"]
	var punished := behavior() == B_CHARGE and state == S_RECOVER
	if punished:
		dmg *= p.punish_mult
	hp -= dmg
	flash = p.flash_time
	var armored := (state == S_CHARGE or state == S_TELE) and not p.hit_interrupts
	if armored:
		_armor_flash = 0.15
	else:
		stun = p.stun_time
		state = S_IDLE
		velocity = kb * (1.0 - p.kb_resist)
	_float_text(("%d" % int(dmg)) + ("!!" if punished else ""), Color(1, 0.9, 0.3) if punished else Color.WHITE)
	if hp <= 0.0:
		dead = true
		respawn_t = p.respawn_time
		collision_layer = 0
	return true


func contact_damage_amount() -> float:
	if dead or stun > 0.0:
		return 0.0
	return contact_override if contact_override >= 0.0 else p.contact_damage


func _float_text(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.z_index = 50
	get_parent().add_child(l)
	l.global_position = global_position + Vector2(-10, -p.body_height * 0.5 - 34.0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(l.queue_free)


func _draw() -> void:
	if dead:
		return
	var col := Color(0.82, 0.3, 0.3)
	match state:
		S_TELE:
			col = Color(1.0, 0.85, 0.2)
		S_RECOVER:
			col = Color(0.4, 0.6, 1.0)
	if flash > 0.0:
		col = Color.WHITE
	var hw := p.body_width * 0.5
	var hh := p.body_height * 0.5
	var body := Rect2(-hw, -hh, p.body_width, p.body_height)
	if skin_node != null and is_instance_valid(skin_node):
		var fr := clampf(hp / maxf(p.max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(-hw, -hh - 14.0, p.body_width * fr, 4), Color(0.4, 0.9, 0.4, 0.8))
		return
	draw_rect(body, col)
	draw_rect(body, Color(0, 0, 0, 0.6), false, 2.0)
	var face := charge_dir if state != S_IDLE else dir
	draw_rect(Rect2(hw - 16.0 if face > 0 else -hw + 6.0, -hh + 10.0, 10, 10), Color.WHITE)
	# полоска здоровья
	var frac := clampf(hp / maxf(p.max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(-hw, -hh - 14.0, p.body_width, 6), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-hw, -hh - 14.0, p.body_width * frac, 6), Color(0.4, 0.9, 0.4))
	if state == S_TELE:
		draw_string(ThemeDB.fallback_font, Vector2(-5, -hh - 22.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.2))
	if _armor_flash > 0.0:
		draw_rect(body.grow(4.0), Color(0.8, 0.8, 0.8, 0.8), false, 3.0)
