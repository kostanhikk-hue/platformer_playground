extends SceneTree
## Автотесты правила «Штрихи — предметы мира» (ТЗ Ф2, 3.8): слой «Штрихи», платформа перед штрихом,
## плита со штрихами, перенос старого pressed_by, break_stroke / stroke_broken, поведение как раньше.
## Запуск из корня проекта (папка tools/ в демо-сборку не входит):
##   godot --headless --fixed-fps 60 --path . --script tools/tests/test_strokes_world.gd
## Печатает PASS / FAIL по каждой проверке и итог; код выхода 1, если что-то не прошло.

const Layers := preload("res://core/layers.gd")
const Catalog := preload("res://game/level/catalog.gd")
const RUNTIME_SCENE := "res://game/level/level_runtime.tscn"
const G := 600.0

var fails := 0
var passes := 0
var rt: Node2D
## Скрипты штрихов используют автозагрузку Fx — грузим их после старта дерева, а не preload.
var StrokeScript: GDScript
var WaveScript: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	StrokeScript = load("res://game/ink/ink_stroke.gd")
	WaveScript = load("res://game/ink/wave_stroke.gd")
	await t_platform_waits_on_line()
	await t_platform_break()
	await t_platform_turn()
	await t_platform_and_paint_result()
	await t_crush_between_platform_and_line()
	await t_plate_by_line()
	await t_old_level_pressed_by()
	await t_pg_paint_place9()
	await t_stand_on_strokes_and_canvas()
	await t_wave_snap_and_torch()
	print("\n=== ИТОГ: %d прошло, %d не прошло ===" % [passes, fails])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------ проверки

## Автозагрузки в скрипте --script не видны по имени при компиляции — берём узлы из дерева.
func ev() -> Node:
	return root.get_node("Events")


func prm() -> Node:
	return root.get_node("Params")


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("  PASS  ", what)
	else:
		fails += 1
		print("  FAIL  ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


# ------------------------------------------------------------ уровень

func new_level() -> LevelData:
	var lv := LevelData.new()
	lv.id = "_test"
	lv.bounds = Rect2(-600, -600, 4000, 1600)
	lv.kill_y = 1400.0
	var s := GeoShape.new()
	s.uid = "ground"
	s.kind = GeoShape.Kind.RECT
	s.position = Vector2(-600, G)
	s.points = PackedVector2Array([Vector2.ZERO, Vector2(4000, 0), Vector2(4000, 200), Vector2(0, 200)])
	lv.shapes.append(s)
	return lv


func add_obj(lv: LevelData, def_id: String, uid: String, pos: Vector2, props: Dictionary = {}) -> void:
	var o := PlacedObject.new()
	o.def_id = def_id
	o.uid = uid
	o.position = pos
	o.props = props
	lv.objects.append(o)


func add_path(lv: LevelData, uid: String, pts: Array) -> void:
	var s := GeoShape.new()
	s.uid = uid
	s.kind = GeoShape.Kind.PATH
	s.position = pts[0]
	var local := PackedVector2Array()
	for q in pts:
		local.append(q - pts[0])
	s.points = local
	lv.shapes.append(s)


func start(lv: LevelData, hero: Vector2) -> void:
	if rt != null and is_instance_valid(rt):
		rt.queue_free()
		await process_frame
	ev().clear_log()
	rt = load(RUNTIME_SCENE).instantiate()
	rt.level = lv
	rt.test_mode = true
	rt.has_launch = true
	rt.launch_pos = hero
	root.add_child(rt)
	await frames(2)


func comp(uid: String) -> Node:
	return rt.get_component(uid)


## Линия-охра без урона: start — начало, dir — направление; life — время жизни (fade — мигание в конце).
func line(at: Vector2, dir: Vector2, length: float = 240.0, life: float = 1.5, fade: float = 0.5) -> Node2D:
	var p: Resource = prm().get_res("ink").duplicate()
	p.lifetime = life
	p.fade_time = fade
	p.damage = 0.0
	var s = StrokeScript.new()
	rt.add_child(s)
	var sz: Dictionary = StrokeScript.base_size(p)
	sz["length"] = length
	sz["draw_time"] = 0.0
	sz["damage"] = 0.0
	s.setup(p, at, dir, null, sz)
	ev().stroke_spawned.emit(s)
	return s


func wave(origin: Vector2) -> Node2D:
	var p: Resource = prm().get_res("wave").duplicate()
	p.lifetime = 3.0
	p.sweep_time = 0.0
	p.damage = 0.0
	var s = WaveScript.new()
	rt.add_child(s)
	var sz: Dictionary = WaveScript.base_size(p)
	sz["damage"] = 0.0
	s.setup(p, null, origin, Vector2.RIGHT, 1, sz)
	ev().stroke_spawned.emit(s)
	return s


func log_has(name: String, uid: String = "*") -> bool:
	for e in ev().log:
		if e["name"] == name and (uid == "*" or e["uid"] == uid):
			return true
	return false


## Вертикальная платформа: путь (500, 200) → (500, 590), один раз.
func platform_level(on_blocked: int, mode: int = 2, one_way: bool = true) -> LevelData:
	var lv := new_level()
	add_path(lv, "path_v", [Vector2(500, 200), Vector2(500, 590)])
	add_obj(lv, "moving_platform", "mp", Vector2(500, 200), {"path_uid": "path_v", "speed": 150.0, "pause": 0.0, "mode": mode,
		"on_blocked": on_blocked, "one_way": one_way})
	return lv


func plat_y() -> float:
	return comp("mp").body.global_position.y


# ------------------------------------------------------------ тесты

func t_platform_waits_on_line() -> void:
	print("\n[платформа ждёт на линии и едет дальше, когда линия исчезла]")
	await start(platform_level(0), Vector2(500, 150))   # герой падает на платформу и едет на ней
	var ln := line(Vector2(380, 450), Vector2.RIGHT, 240.0, 2.5, 0.5)
	await frames(100)
	var mp := comp("mp")
	var pl = rt.player
	var ys := []
	var rel := []
	for i in 40:
		await physics_frame
		ys.append(plat_y())
		rel.append(pl.global_position.y - plat_y())
	check(ys.max() < 450.0 - 6.0, "остановилась над линией (y=%.2f, линия 444…456)" % ys.max())
	check(ys.max() - ys.min() < 0.001, "стоит без дрожи (размах %.4f px за 40 кадров)" % (ys.max() - ys.min()))
	check(rel.max() - rel.min() < 0.01 and pl.is_on_floor(), "герой на ней стоит спокойно (размах %.4f px)" % (rel.max() - rel.min()))
	check(mp.debug_text().contains("ждёт: путь перекрыт штрихом"), "debug_text: «%s»" % mp.debug_text())
	check(ln.body.collision_layer == Layers.STROKES, "линия в слое «Штрихи» (бит 8)")
	while is_instance_valid(ln):
		await physics_frame
	await frames(90)
	check(plat_y() > 520.0, "линия исчезла — поехала дальше (y=%.1f)" % plat_y())
	check(not log_has("stroke_broken"), "исчезновение по времени не даёт stroke_broken")


func t_platform_break() -> void:
	print("\n[on_blocked = сломать штрих]")
	await start(platform_level(2), Vector2(1500, 560))
	var ln := line(Vector2(380, 450), Vector2.RIGHT, 240.0, 10.0, 0.5)
	var broke_at := -1
	for i in 120:
		await physics_frame
		if broke_at < 0 and ln.broken:
			broke_at = i
	check(broke_at >= 0, "штрих сломан (кадр %d)" % broke_at)
	check(log_has("stroke_broken", "mp"), "в шине stroke_broken от uid платформы")
	var kind := ""
	for e in ev().log:
		if e["name"] == "stroke_broken":
			kind = e["data"].get("kind", "")
	check(kind == "ink", "данные события: kind = «%s»" % kind)
	check(plat_y() > 520.0, "едет дальше, не ждёт (y=%.1f)" % plat_y())
	check(not is_instance_valid(ln), "сломанный штрих доморгал и удалён (fade_time 0.5 с)")


func t_platform_turn() -> void:
	print("\n[on_blocked = развернуться]")
	await start(platform_level(1, 0), Vector2(1500, 560))
	line(Vector2(380, 450), Vector2.RIGHT, 240.0, 10.0, 0.5)
	var ymax := -INF
	for i in 120:
		await physics_frame
		ymax = maxf(ymax, plat_y())
	check(ymax < 444.0, "сквозь линию не проехала (макс. y=%.1f)" % ymax)
	check(plat_y() < ymax - 40.0, "развернулась и едет обратно (y=%.1f)" % plat_y())


func t_platform_and_paint_result() -> void:
	print("\n[результат рисуемого контура: слой и платформа перед ним]")
	for layer in [0, 1]:
		var lv := platform_level(2)
		add_obj(lv, "paintable", "pt", Vector2(500, 460), {"result": 1, "result_layer": layer})
		var s := GeoShape.new()
		s.uid = "pt_shape"
		s.role = "outline"
		s.parent_uid = "pt"
		s.kind = GeoShape.Kind.BODY
		s.closed = true
		s.points = PackedVector2Array([Vector2(-100, -10), Vector2(100, -10), Vector2(100, 10), Vector2(-100, 10)])
		lv.shapes.append(s)
		await start(lv, Vector2(1500, 560))
		var pt := comp("pt")
		pt._complete(false)
		await frames(120)
		var body: StaticBody2D = pt._result_body
		if layer == 0:
			check(body != null and body.collision_layer == Layers.STROKES, "result_layer = штрихи → слой «Штрихи»")
			check(plat_y() < 450.0, "платформа с «сломать штрих» перед результатом ждёт (y=%.1f)" % plat_y())
			check(is_instance_valid(body), "результат контура не сломан")
		else:
			check(body != null and body.collision_layer == Layers.WORLD, "result_layer = мир → слой «Мир»")
			check(plat_y() > 520.0, "на результат со слоем «мир» платформа не реагирует (y=%.1f)" % plat_y())


func t_crush_between_platform_and_line() -> void:
	print("\n[герой между платформой и линией — общее правило зажатия]")
	await start(platform_level(0, 2, false), Vector2(500, 420))   # сплошная платформа (проходимую снизу зажатие не учитывает)
	line(Vector2(380, 450), Vector2.RIGHT, 240.0, 6.0, 0.5)   # герой стоит на линии, платформа опускается на него
	await frames(150)
	var pl = rt.player
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(20, 36)
	q.shape = sh
	q.collision_mask = Layers.SOLID
	q.transform = Transform2D(0.0, pl.global_position)
	check(rt.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty(), "героя не протащило: он не внутри твёрдого (y=%.1f)" % pl.global_position.y)
	check(plat_y() < 444.0, "платформа стоит над линией (y=%.1f)" % plat_y())


func t_plate_by_line() -> void:
	print("\n[плита держится линией и отпускается, когда линия исчезла]")
	var lv := new_level()
	add_obj(lv, "door", "door", Vector2(1100, G - 48))
	add_obj(lv, "plate", "plate", Vector2(800, G - 6), {"press_hero": false, "press_strokes": true, "targets": PackedStringArray(["door"]), "link_mode": 3})
	await start(lv, Vector2(800, 570))   # герой стоит на плите — «герой» не отмечен
	await frames(30)
	check(not comp("plate").active, "герой на плите без галочки «герой» не нажимает")
	var ln := line(Vector2(700, G - 20), Vector2.RIGHT, 220.0, 1.5, 0.5)
	await frames(5)
	check(comp("plate").active and comp("door").active, "линия через плиту: плита нажата, дверь «Следовать» открыта")
	while is_instance_valid(ln):
		await physics_frame
	await frames(5)
	check(not comp("plate").active and not comp("door").active, "линия исчезла: плита отпущена, дверь закрыта")
	ln = line(Vector2(700, G - 20), Vector2.RIGHT, 220.0, 10.0, 0.3)
	await frames(5)
	ln.break_stroke()
	await frames(3)
	check(not comp("plate").active, "сломанная линия плиту не держит (твёрдость пропала сразу)")
	check(log_has("stroke_broken", ""), "break_stroke() без объекта — событие с пустым источником")


func t_old_level_pressed_by() -> void:
	print("\n[старый уровень с pressed_by]")
	var lv := new_level()
	add_obj(lv, "door", "door", Vector2(1100, G - 48))
	add_obj(lv, "plate", "plate", Vector2(800, G - 6), {"pressed_by": 2, "targets": PackedStringArray(["door"]), "link_mode": 3})
	add_obj(lv, "plate", "plate_e", Vector2(1400, G - 6), {"pressed_by": 1})
	add_obj(lv, "plate", "plate_h", Vector2(1700, G - 6), {"pressed_by": 0})
	var path := "user://_old_plate_level.tres"
	ResourceSaver.save(lv, path)
	var old := LevelData.load_level(path)
	var pr: Dictionary = old.find_object("plate").props
	check(not pr.has("pressed_by") and pr.get("press_hero") == true and pr.get("press_enemies") == true and pr.get("press_strokes") == true and pr.get("press_bodies") == true,
		"pressed_by = 2 → все четыре галочки")
	var pe: Dictionary = old.find_object("plate_e").props
	check(pe.get("press_hero") == false and pe.get("press_enemies") == true and pe.get("press_strokes") == false, "pressed_by = 1 → только «враги»")
	var ph: Dictionary = old.find_object("plate_h").props
	check(ph.get("press_hero") == true and ph.get("press_enemies") == false, "pressed_by = 0 → только «герой»")
	await start(old, Vector2(800, 570))
	await frames(10)
	check(comp("plate").active and comp("door").active, "pressed_by = 2: герой нажимает, дверь открыта")
	rt.player.global_position = Vector2(300, 570)
	await frames(10)
	check(not comp("plate").active, "сошёл — отпущена")
	var ln := line(Vector2(700, G - 20), Vector2.RIGHT, 220.0, 1.0, 0.3)
	await frames(5)
	check(comp("plate").active, "pressed_by = 2: линия нажимает (как раньше, когда штрихи были в «Мире»)")
	rt.player.global_position = Vector2(1400, 570)
	await frames(10)
	check(not comp("plate_e").active, "pressed_by = 1: герой не нажимает")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func t_pg_paint_place9() -> void:
	print("\n[плейграунд «Рисуемые объекты», место 9]")
	var lv := LevelData.load_level("res://content/levels/common/pg_paint.tres")
	var plate_uid := ""
	var door_uid := ""
	var mp_uid := ""
	for o in lv.objects:
		if o.def_id == "plate" and o.position.x > 7000.0:
			plate_uid = o.uid
			door_uid = (o.props.get("targets", PackedStringArray()) as PackedStringArray)[0]
		if o.def_id == "moving_platform" and o.position.x > 7000.0:
			mp_uid = o.uid
	check(plate_uid != "" and mp_uid != "", "на месте 9 есть плита (%s → %s) и платформа (%s)" % [plate_uid, door_uid, mp_uid])
	await start(lv, Vector2(7080, G - 20))
	await frames(10)
	var mp := comp(mp_uid)
	# линия под опускающейся платформой — как игрок: стоя слева, вправо от центра героя
	var ln := line(Vector2(7104, G - 20), Vector2.RIGHT, 220.0, 5.0, 1.0)
	await frames(260)
	var y1: float = mp.body.global_position.y
	await frames(20)
	var y2: float = mp.body.global_position.y
	check(y1 < G - 26.0 and absf(y2 - y1) < 0.001, "платформа встала на линию (y=%.1f) и стоит" % y2)
	while is_instance_valid(ln):
		await physics_frame
	await frames(30)
	check(mp.body.global_position.y > y2 + 5.0 or mp.follow.i == 1, "линия исчезла — поехала дальше (y=%.1f)" % mp.body.global_position.y)
	# плита в нише: герой стоит перед нишей и проводит линию внутрь
	rt.player.global_position = Vector2(7520, G - 20)
	await frames(10)
	check(not comp(plate_uid).active, "плита в нише отпущена, пока линии нет")
	var ln2 := line(Vector2(7544, G - 20), Vector2.RIGHT, 220.0, 1.5, 0.5)
	await frames(5)
	check(comp(plate_uid).active and comp(door_uid).active, "линия в нишу: плита нажата, дверь открыта")
	while is_instance_valid(ln2):
		await physics_frame
	await frames(5)
	check(not comp(plate_uid).active and not comp(door_uid).active, "линия исчезла: плита отпущена, дверь закрыта")


func t_stand_on_strokes_and_canvas() -> void:
	print("\n[как раньше: герой и манекен на линии и волне, манекен-холст сквозь штрихи]")
	var lv := new_level()
	add_obj(lv, "dummy", "dm", Vector2(1100, 300), {"behavior": 0})
	add_obj(lv, "dummy_canvas", "dc", Vector2(1200, 300), {"behavior": 0, "accept_ink": false})   # не закрашиваться линией — иначе исчезнет
	await start(lv, Vector2(1000, 300))
	line(Vector2(940, 400), Vector2.RIGHT, 340.0, 20.0, 0.5)
	await frames(90)
	var pl = rt.player
	var dm := comp("dm")
	var dc := comp("dc")
	check(pl.is_on_floor() and pl.global_position.y < 400.0, "герой стоит на линии (y=%.1f)" % pl.global_position.y)
	check(dm.is_on_floor() and dm.global_position.y < 400.0, "манекен стоит на линии (y=%.1f)" % dm.global_position.y)
	check(dc.global_position.y > 500.0, "манекен-холст прошёл сквозь линию до пола (y=%.1f)" % dc.global_position.y)
	check(dc.collision_mask & Layers.STROKES == 0 and dm.collision_mask & Layers.STROKES != 0, "маски: холст без бита 8, манекен с битом 8")
	var lv2 := new_level()
	add_obj(lv2, "dummy", "dm", Vector2(1720, 300), {"behavior": 0})
	await start(lv2, Vector2(1640, 300))
	wave(Vector2(1500, G))
	await frames(90)
	check(rt.player.is_on_floor() and rt.player.global_position.y < G - 30.0, "герой стоит на волне (y=%.1f)" % rt.player.global_position.y)
	check(comp("dm").global_position.y < G - 40.0, "манекен стоит на волне (y=%.1f)" % comp("dm").global_position.y)


func t_wave_snap_and_torch() -> void:
	print("\n[как раньше: прижатие волны к земле и к линии, факел не светит сквозь штрих]")
	var lv := new_level()
	add_obj(lv, "torch_wall", "torch", Vector2(2000, 380), {"radius": 300.0, "line_of_sight": true})
	await start(lv, Vector2(600, 560))
	await frames(30)
	var pl = rt.player
	var w0: Resource = pl.w
	pl.w = w0.duplicate()
	pl.w.origin_y = 0.0     # старт — центр героя: луч прижатия начинается над опорой
	pl.w.snap_to_ground = true
	var o: Vector2 = pl._wave_origin(Vector2.RIGHT, 1)
	check(absf(o.y - G) < 0.5, "на полу: старт волны прижат к полу (y=%.2f)" % o.y)
	var ln := line(Vector2(500, 450), Vector2.RIGHT, 240.0, 20.0, 0.5)
	pl.global_position = Vector2(600, 400)
	await frames(30)
	o = pl._wave_origin(Vector2.RIGHT, 1)
	check(absf(o.y - 444.0) < 1.0, "на линии: старт волны прижат к линии (y=%.2f)" % o.y)
	pl.w = w0
	var torch := comp("torch")
	var target := Vector2(2000, 560)
	check(torch.light_reaches(target, 4.0), "без штриха факел достаёт до точки")
	var ln2 := line(Vector2(1880, 470), Vector2.RIGHT, 240.0, 20.0, 0.5)
	await frames(2)
	check(not torch.light_reaches(target, 4.0), "штрих между факелом и точкой — не светит")
	ln2.queue_free()
	ln.queue_free()
