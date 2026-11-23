extends "res://game/components/component_base.gd"
## Рисуемый контур (Paintable) — главная механика: пунктирный силуэт, который герой дорисовывает,
## и он становится настоящим объектом (тело, платформа, стена, декор, срабатывают связи, появляется объект).
##
## Форма — контур объекта с ролью "outline" (замкнутый или открытый). Контур разбивается на образцы через
## sample_step px (вкладка «Контур»). Образец покрыт, если до него от штриха ≤ tolerance + толщина/2,
## или его нарисовала кисть при удержании E. Прогресс = покрытые / все. ≥ required_fill — дорисован
## (или если все непокрытые участки короче auto_close_gap — они дорисовываются сами).
## Состояния: скрыт → пунктир → частично → готово → (мигает и исчезает, если lifetime > 0).
## События: paint_started · painted_percent {value: 25/50/75} · painted · paint_faded · activated / deactivated.

const Brush := preload("res://game/ink/brush.gd")
const GeometryBuilder := preload("res://game/level/geometry_builder.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const Geometry := preload("res://core/geometry.gd")

enum M { STROKE, HOLD, BOTH }
enum R { DECOR, BODY, PLATFORM, WALL }

var pp: Resource                     ## общие параметры (вкладка «Контур»)
var outline := PackedVector2Array()  ## точки контура (локально)
var closed := true
var samples := PackedVector2Array()
var spacing := 8.0                   ## фактическое расстояние между образцами, px
var covered := PackedByteArray()
var count_covered := 0
var done := false
var started := false
var _marks := 0                      ## сколько четвертей (25/50/75) уже сообщено
var _strokes: Array = []
var _vis_dirty := true
var _groups: Array = []              ## [{pts, brush}] — нарисованные участки
var _cache := {}
var _holding := false
var _hold_t := 0.0
var _fronts := [-1, -1]
var _budget := [0.0, 0.0]
var _stalled := false
var _released_t := 0.0
var _life_t := 0.0
var _flash_t := 0.0
var _reveal_t := 0.0
var _fade_acc := 0.0
var _result_body: StaticBody2D
var _spawned: Node
var _art: Node2D
var _art_path := ""
var _ink_spent := 0.0
var _paint_time := 0.0
var _t := 0.0
var _near := false


func _setup(_ctx: Dictionary) -> void:
	pp = Params.get_res("paintable")
	var list: Array = shapes.get("outline", [])
	if not list.is_empty():
		outline = list[0]["points"]
		closed = list[0]["closed"]
	_resample()
	Events.stroke_spawned.connect(_on_stroke)


func _exit_tree() -> void:
	if Events.stroke_spawned.is_connected(_on_stroke):
		Events.stroke_spawned.disconnect(_on_stroke)
	_set_player_mult(1.0)


func _apply() -> void:
	if int(props.method) != M.STROKE:
		add_to_group("interactive")
	elif is_in_group("interactive"):
		remove_from_group("interactive")
	if done:
		_build_result()
	_update_art()
	_vis_dirty = true


func _on_active(_on: bool) -> void:
	visible = active or done
	_vis_dirty = true


func _resample() -> void:
	samples = PackedVector2Array()
	var n := outline.size()
	if n < 2:
		covered = PackedByteArray()
		return
	var pts := outline.duplicate()
	if closed:
		pts.append(outline[0])
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var step := maxf(pp.sample_step, 1.0)
	var count: int = maxi(int(ceil(total / step)), 3) if closed else maxi(int(ceil(total / step)) + 1, 2)
	count = mini(count, 4000)   # защита: огромный контур с мелким шагом
	spacing = total / float(count if closed else maxi(count - 1, 1))
	var seg := 0
	var seg_start := 0.0
	for k in range(count):
		var d := spacing * k
		while seg < pts.size() - 2 and seg_start + pts[seg].distance_to(pts[seg + 1]) < d:
			seg_start += pts[seg].distance_to(pts[seg + 1])
			seg += 1
		var l := pts[seg].distance_to(pts[seg + 1])
		samples.append(pts[seg].lerp(pts[seg + 1], clampf((d - seg_start) / maxf(l, 0.001), 0.0, 1.0)))
	covered = PackedByteArray()
	covered.resize(samples.size())
	covered.fill(0)
	count_covered = 0


func progress() -> float:
	return 0.0 if samples.is_empty() else float(count_covered) / samples.size()


# ------------------------------------------------------------ штрихи

func _on_stroke(s: Node) -> void:
	_strokes.append(weakref(s))


func _accepts(kind: String) -> bool:
	match kind:
		"ink":
			return props.accept_ink
		"wave":
			return props.accept_wave
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
	if done:
		_tick_done(delta)
		queue_redraw()
		return
	_near = _player_near(pp.highlight_radius)
	if not active or samples.is_empty():
		_strokes.clear()
		return
	var changed := false
	if int(props.method) != M.HOLD:
		changed = _check_strokes()
	else:
		_strokes.clear()
	if started and not _holding:
		if pp.fade_progress > 0.0:
			_fade_acc += pp.fade_progress / 100.0 * samples.size() * delta
			while _fade_acc >= 1.0 and count_covered > 0:
				_fade_acc -= 1.0
				_uncover_edge()
				changed = true
		if pp.hold_forget_time > 0.0 and count_covered > 0:
			_released_t += delta
			if _released_t >= pp.hold_forget_time:
				_reset_progress()
				changed = true
	if started:
		_paint_time += delta
	if changed:
		_after_change()
	queue_redraw()


func _check_strokes() -> bool:
	var changed := false
	var inv := global_transform.affine_inverse()
	var alive: Array = []
	for w in _strokes:
		var s = w.get_ref()
		if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
			continue
		alive.append(w)
		var poly: Dictionary = s.get_world_polyline()
		if not _accepts(poly["kind"]):
			continue
		var pts: PackedVector2Array = inv * (poly["points"] as PackedVector2Array)
		if pts.size() < 2:
			continue
		var r: float = props.tolerance + float(poly["thickness"]) * 0.5
		var box := Geometry.bbox(pts).grow(r)
		for i in range(samples.size()):
			if covered[i] == 1 or not box.has_point(samples[i]):
				continue
			var q := samples[i]
			for j in range(pts.size() - 1):
				if Geometry.dist_to_segment(q, pts[j], pts[j + 1]) <= r:
					covered[i] = 1
					count_covered += 1
					changed = true
					_released_t = 0.0
					break
	_strokes = alive
	return changed


func _after_change() -> void:
	_vis_dirty = true
	if count_covered > 0 and not started:
		started = true
		emit_event("paint_started")
	var pct := progress()
	while _marks < 3 and pct >= (_marks + 1) * 0.25:
		_marks += 1
		emit_event("painted_percent", {"value": _marks * 25})
	if count_covered > 0 and (pct >= props.required_fill - 0.0001 or _gaps_small()):
		_complete(true)


## Все непокрытые участки короче auto_close_gap?
func _gaps_small() -> bool:
	if pp.auto_close_gap <= 0.0:
		return false
	var n := samples.size()
	var run := 0
	var longest := 0
	var first_run := -1
	for i in range(n):
		if covered[i] == 0:
			run += 1
		else:
			if first_run < 0:
				first_run = run
			longest = maxi(longest, run)
			run = 0
	if closed and first_run >= 0:
		run += first_run   # участок, проходящий через начало контура
	longest = maxi(longest, run)
	return float(longest) * spacing < pp.auto_close_gap


func _uncover_edge() -> void:
	var n := samples.size()
	var edges: Array = []
	for i in range(n):
		if covered[i] == 0:
			continue
		var a := (i - 1 + n) % n if closed else i - 1
		var b := (i + 1) % n if closed else i + 1
		if (a < 0 or covered[a] == 0) or (b >= n or covered[b] == 0):
			edges.append(i)
	if edges.is_empty():
		for i in range(n):
			if covered[i] == 1:
				edges.append(i)
	if edges.is_empty():
		return
	var k: int = edges[randi() % edges.size()]
	covered[k] = 0
	count_covered -= 1


func _reset_progress() -> void:
	covered.fill(0)
	count_covered = 0
	started = false
	_marks = 0
	_released_t = 0.0
	_paint_time = 0.0
	_vis_dirty = true


# ------------------------------------------------------------ удержание

func _hold_cost() -> float:
	var c: float = props.hold_ink_per_px
	return pp.hold_ink_per_px if c < 0.0 else c


func can_interact(_player: Node) -> bool:
	return active and not done and int(props.method) != M.STROKE and not samples.is_empty()


func interact_point(from: Vector2) -> Vector2:
	return to_global(samples[_nearest(to_local(from))]) if not samples.is_empty() else global_position


func interact_ready(player: Node) -> bool:
	return not _stalled and player.get_ink() >= _hold_cost() * spacing


func _nearest(local: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in range(samples.size()):
		var d := samples[i].distance_squared_to(local)
		if d < bd:
			bd = d
			best = i
	return best


func on_interact_pressed(player: Node) -> void:
	_holding = true
	_hold_t = 0.0
	_stalled = false
	var seed_i := _nearest(to_local(player.global_position))
	_fronts = [seed_i, seed_i]
	_budget = [0.0, 0.0]
	_set_player_mult(pp.hold_move_mult)


func on_interact_held(player: Node, delta: float) -> void:
	if done or not _holding:
		return
	_hold_t += delta
	var k := 1.0 if pp.hold_accel_time <= 0.0 else pow(clampf(_hold_t / pp.hold_accel_time, 0.0, 1.0), maxf(pp.hold_accel_curve, 0.01))
	var speed: float = pp.hold_speed * lerpf(pp.hold_start_mult, 1.0, k)
	var n := samples.size()
	var changed := false
	_stalled = false
	# начальный образец
	var seed_i: int = _fronts[0]
	if covered[seed_i] == 0 and _fronts[0] == _fronts[1]:
		if _pay(player):
			covered[seed_i] = 1
			count_covered += 1
			changed = true
		else:
			_stalled = true
	for side in range(2):
		_budget[side] = minf(_budget[side] + speed * delta, spacing * 4.0)
		var guard := 0
		while _budget[side] >= spacing and guard < n:
			guard += 1
			var nxt: int = _fronts[side] + (1 if side == 1 else -1)
			if closed:
				nxt = (nxt + n) % n
			elif nxt < 0 or nxt >= n:
				_budget[side] = 0.0
				break
			if covered[nxt] == 1:
				_fronts[side] = nxt
				continue
			if not _pay(player):
				_stalled = true
				_budget[side] = 0.0
				break
			covered[nxt] = 1
			count_covered += 1
			_fronts[side] = nxt
			_budget[side] -= spacing
			changed = true
	if changed:
		_released_t = 0.0
		_after_change()


func _pay(player: Node) -> bool:
	var cost := _hold_cost() * spacing
	if player.spend_ink(cost):
		_ink_spent += cost
		return true
	return false


func on_interact_released(_player: Node) -> void:
	_holding = false
	_stalled = false
	_released_t = 0.0
	_set_player_mult(1.0)


func _set_player_mult(m: float) -> void:
	if runtime != null and runtime.get("player") != null and is_instance_valid(runtime.player):
		runtime.player.move_mult_ext = m


func _player_near(r: float) -> bool:
	if runtime == null or runtime.get("player") == null or samples.is_empty():
		return false
	var pl: Node2D = runtime.player
	if not is_instance_valid(pl):
		return false
	var lp := to_local(pl.global_position)
	return samples[_nearest(lp)].distance_to(lp) <= r


# ------------------------------------------------------------ готово и результат

func _complete(with_fx: bool) -> void:
	done = true
	covered.fill(1)
	count_covered = samples.size()
	_vis_dirty = true
	if _holding:
		on_interact_released(null)
	_life_t = props.lifetime
	_build_result()
	_spawn_result()
	if with_fx:
		_flash_t = pp.flash_time
		_reveal_t = 0.0
		Fx.hitstop(pp.done_hitstop)
		Fx.shake(pp.done_shake, pp.done_shake_time)
		emit_event("painted", {"time": snappedf(_paint_time, 0.01), "ink": snappedf(_ink_spent, 0.1)})
		links_pulse()
		links_state(true)
	else:
		_reveal_t = pp.reveal_time
	_update_art()


func _tick_done(delta: float) -> void:
	_reveal_t += delta
	if _art != null:
		_art.modulate.a = 1.0 if pp.reveal_time <= 0.0 else clampf(_reveal_t / pp.reveal_time, 0.0, 1.0)
	if props.lifetime <= 0.0:
		modulate.a = 1.0
		return
	_life_t -= delta
	if _life_t <= pp.fade_time:
		var on := int(_life_t * pp.fade_blink_hz * 2.0) % 2 == 0
		modulate.a = 1.0 if on else pp.fade_min_alpha
	if _life_t <= 0.0:
		_fade_out(true)


func _fade_out(with_events: bool) -> void:
	done = false
	modulate.a = 1.0
	_clear_result()
	_reset_progress()
	_update_art()
	visible = active
	if with_events:
		emit_event("paint_faded")
		links_state(false)


func _build_result() -> void:
	_clear_body()
	if outline.size() < 2:
		return
	var res := int(props.result)
	if res == R.DECOR:
		return
	_result_body = StaticBody2D.new()
	_result_body.collision_layer = WORLD_LAYER if int(props.result_layer) == 1 else STROKES_LAYER
	_result_body.collision_mask = 0
	add_child(_result_body)
	var ok := false
	if res == R.BODY and closed:
		ok = GeometryBuilder.fill_polygon(_result_body, outline)
	if not ok:
		var pts := outline.duplicate()
		if closed:
			pts.append(outline[0])
		var ow: bool = props.one_way and res == R.PLATFORM
		GeometryBuilder.fill_chain(_result_body, pts, props.thickness, ow, props.solid_angle_deg)


func _spawn_result() -> void:
	if props.spawn_def == "" or runtime == null or not runtime.has_method("spawn_object"):
		return
	var at: Vector2
	if int(props.spawn_at) == 0:
		at = to_global(Geometry.bbox(outline).get_center())
	else:
		at = global_position + Vector2(props.spawn_x, props.spawn_y)
	_spawned = runtime.spawn_object(props.spawn_def, at)


func _clear_body() -> void:
	if _result_body != null and is_instance_valid(_result_body):
		_result_body.queue_free()
	_result_body = null


func _clear_result() -> void:
	_clear_body()
	if _spawned != null and is_instance_valid(_spawned):
		if runtime != null and runtime.has_method("despawn"):
			runtime.despawn(_spawned)
		else:
			_spawned.queue_free()
	_spawned = null


func _update_art() -> void:
	var path: String = props.result_art if props != null else ""
	if path != _art_path:
		if _art != null and is_instance_valid(_art):
			_art.queue_free()
		_art = null
		_art_path = path
		if path != "" and ArtLoader.exists(path):
			_art = ArtLoader.make_node(path, Rect2(), true)
			_art.show_behind_parent = true
			add_child(_art)
	if _art != null:
		_art.position = Vector2(props.art_x, props.art_y)
		_art.scale = Vector2.ONE * props.art_scale
		_art.visible = done
		if done and pp.reveal_time > 0.0:
			_art.modulate.a = clampf(_reveal_t / pp.reveal_time, 0.0, 1.0)


# ------------------------------------------------------------ снимки

func _snap() -> Dictionary:
	return {"covered": covered.duplicate(), "done": done, "life": _life_t, "started": started, "marks": _marks}


func _restore(d: Dictionary) -> void:
	var was_done := done
	if was_done:
		_clear_result()
	_strokes.clear()
	if _holding:
		on_interact_released(null)
	var c: PackedByteArray = d.get("covered", PackedByteArray())
	if c.size() == samples.size():
		covered = c.duplicate()
	else:
		covered.fill(0)
	count_covered = 0
	for v in covered:
		count_covered += v
	started = d.get("started", false)
	_marks = d.get("marks", 0)
	done = false
	modulate.a = 1.0
	if d.get("done", false):
		_complete(false)
		_life_t = d.get("life", props.lifetime)
	_update_art()
	visible = active or done
	_vis_dirty = true


func _debug() -> String:
	var state := "готово" if done else ("частично" if count_covered > 0 else "пунктир")
	if not active and not done:
		state = "скрыт"
	var s := "%s %d%% (%d/%d), допуск %d px" % [state, roundi(progress() * 100.0), count_covered, samples.size(), int(props.tolerance)]
	if _ink_spent > 0.0:
		s += ", охра %.1f" % _ink_spent
	if _paint_time > 0.0:
		s += ", %.1f с" % _paint_time
	if done and props.lifetime > 0.0:
		s += ", исчезнет через %.1f с" % maxf(_life_t, 0.0)
	if _stalled:
		s += ", нет охры"
	return s


# ------------------------------------------------------------ вид

func _brush_res() -> Resource:
	if runtime != null and runtime.has_method("brush_for"):
		return runtime.brush_for(props.brush_preset)
	return Params.get_res("brush")


func _paint_color() -> Color:
	return Params.get_res("ink").color if pp.use_ink_color else pp.paint_color


func _rebuild_groups() -> void:
	_vis_dirty = false
	_groups.clear()
	var n := samples.size()
	if n < 2:
		return
	var keep := {}
	var runs: Array = []   # [start, len] покрытых образцов подряд
	if done:
		runs.append([0, n])
	else:
		var i := 0
		while i < n:
			if covered[i] == 1:
				var j := i
				while j + 1 < n and covered[j + 1] == 1:
					j += 1
				runs.append([i, j - i + 1])
				i = j + 1
			else:
				i += 1
		# замкнутый: участок через начало склеиваем
		if closed and runs.size() >= 2 and runs[0][0] == 0 and runs[runs.size() - 1][0] + runs[runs.size() - 1][1] == n:
			var last: Array = runs.pop_back()
			runs[0] = [last[0], last[1] + runs[0][1]]
	for r in runs:
		var start: int = r[0]
		var length: int = r[1]
		var pts := PackedVector2Array()
		var full := done or length >= n
		var cnt := length + (1 if (closed and full) else 0)
		for k in range(cnt):
			pts.append(samples[(start + k) % n])
		if pts.size() < 2:
			# одиночный образец — короткий мазок вдоль контура
			var a := samples[start]
			var b := samples[(start + 1) % n] if (closed or start + 1 < n) else samples[maxi(start - 1, 0)]
			pts = PackedVector2Array([a, a.lerp(b, 0.5)])
		var key := "%d:%d:%d" % [start, length, int(done)]
		var data: Dictionary = _cache.get(key, {})
		if data.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(uid + key)
			data = Brush.build(pts, pp.paint_thickness, _brush_res(), rng)
		keep[key] = data
		_groups.append(data)
	_cache = keep


func _draw() -> void:
	if samples.size() < 2:
		return
	if _vis_dirty:
		_rebuild_groups()
	var col := _paint_color()
	for g in _groups:
		Brush.draw(self, g, 1.0e9, col)
	if not done and active:
		_draw_dashes()
		if _holding:
			for f in _fronts:
				if f >= 0 and f < samples.size():
					draw_circle(samples[f], pp.paint_thickness * 0.7, col.lightened(0.35))
	if _flash_t > 0.0 and pp.flash_time > 0.0:
		var k: float = 1.0 - _flash_t / pp.flash_time
		var pts := outline.duplicate()
		if closed and pts.size() > 0:
			pts.append(outline[0])
		draw_polyline(pts, Color(pp.flash_color, 1.0 - k), maxf(pp.flash_width * (0.3 + k), 1.0))
	_draw_debug()


func _draw_dashes() -> void:
	var n := samples.size()
	var a: float = pp.dash_alpha
	if _near and pp.pulse_amount > 0.0:
		a *= 1.0 - pp.pulse_amount * 0.5 + pp.pulse_amount * 0.5 * sin(_t * TAU * pp.pulse_hz)
	if highlighted:
		a = minf(a * 1.3, 1.0)
	var col := Color(pp.dash_color, a)
	var dash: float = maxf(pp.dash_length, 1.0)
	var gap: float = maxf(pp.dash_gap, 1.0)
	var period := dash + gap
	var edges := n if closed else n - 1
	for i in range(edges):
		var j := (i + 1) % n
		if covered[i] == 1 and covered[j] == 1:
			continue
		var p0 := samples[i]
		var p1 := samples[j]
		var l := p0.distance_to(p1)
		if l < 0.01:
			continue
		var d0 := i * spacing
		var k := int(floor(d0 / period))
		var guard := 0
		while guard < 64:
			guard += 1
			var s0 := k * period - d0
			if s0 >= l:
				break
			var s1 := minf(s0 + dash, l)
			s0 = maxf(s0, 0.0)
			if s1 > s0:
				draw_line(p0.lerp(p1, s0 / l), p0.lerp(p1, s1 / l), col, pp.dash_width)
			k += 1
