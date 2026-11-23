extends SceneTree
## Собирает уровень-плейграунд «Рисуемые объекты» (content/levels/common/pg_paint.tres) — из него же
## он открывается в конструкторе для правки. Запуск:  godot --headless --path . --script tools/build_pg_paint.gd
## Если файл уже есть — не трогает (правки из конструктора важнее). Пересобрать:  ... -- --force

const Catalog := preload("res://game/level/catalog.gd")
const PATH := "res://content/levels/common/pg_paint.tres"
const G := 600.0   ## пол
const T := 32.0

var lv: LevelData
var n := 0


func _initialize() -> void:
	if FileAccess.file_exists(PATH) and not ("--force" in OS.get_cmdline_user_args()):
		print("pg_paint уже есть — пропускаю (пересобрать: -- --force)")
		quit()
		return
	lv = LevelData.new()
	lv.id = "pg_paint"
	lv.title = "Плейграунд: рисуемые объекты"
	lv.epoch = "common"
	lv.bounds = Rect2(0, -320, 8400, 1120)
	lv.kill_y = 1000.0
	lv.darkness_enabled = false

	# пол с пропастью под мостом
	ground(0, 1060)
	ground(1380, 8400)
	obj("start", Vector2(96, G - 20))
	note("1. Три замкнутых контура → тела. Обведи линией (ПКМ / K).", Vector2(180, G - 300))

	# 1. три замкнутых контура разного размера
	paint(Vector2(300, G - 60), rect(48, 32), true, {"result": 1})
	paint(Vector2(520, G - 110), rect(96, 48), true, {"result": 1})
	paint(Vector2(800, G - 170), rect(160, 64), true, {"result": 1})

	# 2. открытый контур над пропастью → мост
	note("2. Мост над пропастью: штрихом или держи E у края.", Vector2(1080, G - 160))
	paint(Vector2(1220, G - 4), PackedVector2Array([Vector2(-160, 0), Vector2(-80, 8), Vector2(0, 10), Vector2(80, 8), Vector2(160, 0)]), false, {"result": 2, "method": 2})

	# 3. рисуемая дверь → выход в начало полигона
	note("3. Рисуемая дверь: дорисуй — выход откроется (вернёт в начало).", Vector2(1480, G - 200))
	var exit_uid := obj("exit", Vector2(1640, G - 48), {"locked": true})
	var arch := PackedVector2Array([Vector2(-32, 48), Vector2(-32, -24), Vector2(-22, -40), Vector2(0, -48), Vector2(22, -40), Vector2(32, -24), Vector2(32, 48)])
	paint(Vector2(1640, G - 48), arch, true, {"result": 0, "targets": PackedStringArray([exit_uid]), "link_mode": 0})

	# 4. только удержанием / только штрихом
	note("4. Слева — только удержанием E (тратит охру), справа — только штрихом.", Vector2(1840, G - 220))
	paint(Vector2(1960, G - 90), PackedVector2Array([Vector2(-80, 0), Vector2(80, 0)]), false, {"result": 2, "method": 1})
	paint(Vector2(2240, G - 90), rect(128, 40), true, {"result": 1, "method": 0})
	obj("ink_source", Vector2(2100, G - 16), {"amount": -1.0, "recharge": 4.0})

	# 5. временный контур
	note("5. Временная платформа: живёт 6 с.", Vector2(2460, G - 220))
	paint(Vector2(2560, G - 110), PackedVector2Array([Vector2(-90, 0), Vector2(90, 0)]), false, {"result": 2, "lifetime": 6.0, "method": 2})

	# 6. стена для закрашивания и манекен-холст
	note("6. Закрась стену до 100 % — дверь откроется. Манекен-холст отмывается.", Vector2(2780, G - 300))
	var door_cov := obj("door", Vector2(3060, G - 48), {})
	var cov := obj("coverage", Vector2(2880, G - 110), {"targets": PackedStringArray([door_cov]), "thresholds": "25, 50, 100", "on_full": 2})
	shape_of(cov, "area", rect(140, 200), true, Vector2(2880, G - 110))
	obj("dummy_canvas", Vector2(3260, G - 26), {"behavior": 1, "wash_rate": 5.0})

	# 7. тёмный участок
	note("7. Свет: возьми факел (E), поднеси к бизону — он оживёт и поедет. Рычаг зажигает настенный факел — дверь освещается.", Vector2(3480, G - 330))
	obj("torch_carry", Vector2(3560, G - 20), {})
	var path_b := path([Vector2(3800, G - 60), Vector2(4300, G - 60), Vector2(4300, G - 160)], false)
	obj("living_painting", Vector2(3800, G - 60), {"path_uid": path_b, "condition": 0, "speed": 100.0, "lost": 0})
	var torch := obj("torch_wall", Vector2(4560, G - 110), {"start_active": false})
	obj("lever", Vector2(4480, G - 16), {"targets": PackedStringArray([torch]), "link_mode": 2})
	obj("door", Vector2(4680, G - 48), {"lit_enabled": true, "lit_radius": 24.0, "open_dir": 2})

	# ладонь-чекпоинт
	note("Ладонь: дорисуй — это чекпоинт.", Vector2(4800, G - 200))
	var cp := obj("checkpoint", Vector2(4900, G - 36), {"activation": 2, "look": 1})
	var hand := PackedVector2Array([Vector2(-14, 24), Vector2(-16, 2), Vector2(-26, -12), Vector2(-21, -17), Vector2(-11, -6),
		Vector2(-12, -30), Vector2(-5, -32), Vector2(-2, -10), Vector2(1, -36), Vector2(8, -35), Vector2(7, -9), Vector2(12, -31),
		Vector2(18, -29), Vector2(14, -5), Vector2(22, -19), Vector2(27, -15), Vector2(16, 10), Vector2(14, 24)])
	paint(Vector2(4900, G - 42), hand, true, {"result": 0, "method": 2, "targets": PackedStringArray([cp]), "link_mode": 0})

	# 8. рычаг → платформа, плита → дверь, ломкая, разрушаемый блок
	note("8. Рычаг — платформа по кругу. Плита держит дверь открытой. Ломкая. Блок — бей.", Vector2(5060, G - 330))
	var loop := path([Vector2(5300, G - 120), Vector2(5600, G - 120), Vector2(5600, G - 260), Vector2(5300, G - 260)], true)
	var mp := obj("moving_platform", Vector2(5300, G - 120), {"path_uid": loop, "start_active": false, "mode": 1, "pause": 0.3})
	obj("lever", Vector2(5160, G - 16), {"targets": PackedStringArray([mp]), "link_mode": 3})
	var door_p := obj("door", Vector2(6000, G - 48), {})
	obj("plate", Vector2(5860, G - 6), {"targets": PackedStringArray([door_p]), "link_mode": 3,
		"press_hero": true, "press_enemies": true, "press_strokes": true, "press_bodies": true})
	var cr := obj("crumble", Vector2(6250, G - 120), {})
	shape_of(cr, "form", PackedVector2Array([Vector2(-64, 0), Vector2(64, 0)]), false, Vector2(6250, G - 120))
	var bl := obj("breakable", Vector2(6560, G - 32), {"hits": 3})
	shape_of(bl, "form", rect(64, 64), true, Vector2(6560, G - 32))
	obj("card", Vector2(6800, G - 40), {"card_id": "hand_stencil"})

	# 9. штрихи — предметы мира (ТЗ Ф2, 3.8)
	note("9. Штрихи — предметы мира. Проведи линию под опускающейся платформой — она встанет на линию; линия исчезла — поедет дальше. Плита в нише нажимается только штрихом: проведи линию в нишу над плитой — дверь откроется, пока линия есть.", Vector2(7000, G - 360))
	var drop := path([Vector2(7250, G - 280), Vector2(7250, G - 8)], false)
	obj("moving_platform", Vector2(7250, G - 280), {"path_uid": drop, "speed": 90.0, "pause": 0.6})
	# ниша: низкий потолок (герой ростом 40 px под ним не пролезает) и задняя стенка; на крышу можно запрыгнуть
	block(7560, G - 110, 7760, G - 30)
	block(7760, G - 110, 7790, G)
	var door_s := obj("door", Vector2(7950, G - 48), {})
	obj("plate", Vector2(7680, G - 6), {"targets": PackedStringArray([door_s]), "link_mode": 3,
		"press_hero": false, "press_strokes": true})

	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var err := ResourceSaver.save(lv, PATH)
	print("pg_paint: %s (объектов %d, контуров %d)" % ["ok" if err == OK else "ошибка %d" % err, lv.objects.size(), lv.shapes.size()])
	quit()


func uid(prefix: String) -> String:
	return lv.next_uid(prefix)


func rect(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2), Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2)])


func ground(x0: float, x1: float) -> void:
	var s := GeoShape.new()
	s.uid = uid("shape")
	s.kind = GeoShape.Kind.RECT
	s.position = Vector2(x0, G)
	s.points = PackedVector2Array([Vector2.ZERO, Vector2(x1 - x0, 0), Vector2(x1 - x0, 200), Vector2(0, 200)])
	s.visible_in_game = true
	s.color = Color(0.3, 0.33, 0.4)
	lv.shapes.append(s)


func block(x0: float, y0: float, x1: float, y1: float) -> void:
	var s := GeoShape.new()
	s.uid = uid("shape")
	s.kind = GeoShape.Kind.RECT
	s.position = Vector2(x0, y0)
	s.points = PackedVector2Array([Vector2.ZERO, Vector2(x1 - x0, 0), Vector2(x1 - x0, y1 - y0), Vector2(0, y1 - y0)])
	s.visible_in_game = true
	s.color = Color(0.3, 0.33, 0.4)
	lv.shapes.append(s)


func obj(def_id: String, pos: Vector2, props: Dictionary = {}) -> String:
	var d := Catalog.get_def(def_id)
	var o := PlacedObject.new()
	o.def_id = def_id
	o.uid = uid(def_id)
	o.position = pos
	o.layer = d.default_layer if d != null else 3
	o.props = props
	lv.objects.append(o)
	return o.uid


func shape_of(owner_uid: String, role: String, pts: PackedVector2Array, closed: bool, _owner_pos: Vector2) -> void:
	var s := GeoShape.new()
	s.uid = uid("shape")
	s.role = role
	s.parent_uid = owner_uid
	s.kind = GeoShape.Kind.BODY if closed else GeoShape.Kind.WALL
	s.closed = closed
	s.points = pts
	s.color = Color(1.0, 0.85, 0.55)
	lv.shapes.append(s)


func paint(pos: Vector2, pts: PackedVector2Array, closed: bool, props: Dictionary) -> String:
	var u := obj("paintable", pos, props)
	shape_of(u, "outline", pts, closed, pos)
	return u


func path(pts: Array, closed: bool) -> String:
	var s := GeoShape.new()
	s.uid = uid("path")
	s.kind = GeoShape.Kind.PATH
	s.closed = closed
	s.position = pts[0]
	var local := PackedVector2Array()
	for q in pts:
		local.append(q - pts[0])
	s.points = local
	lv.shapes.append(s)
	return s.uid


func note(text: String, pos: Vector2) -> void:
	obj("note", pos, {"text": text, "show_in_game": true, "font_size": 14})
