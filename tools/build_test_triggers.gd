extends SceneTree
## Тестовый уровень фазы 4: content/levels/common/test_triggers.tres (сценарий — test_triggers.gd рядом).
## Запуск:  godot --headless --path . --script tools/build_test_triggers.gd   (пересобрать: -- --force)

const Catalog := preload("res://game/level/catalog.gd")
const PATH := "res://content/levels/common/test_triggers.tres"
const G := 600.0

var lv: LevelData


func _initialize() -> void:
	if FileAccess.file_exists(PATH) and not ("--force" in OS.get_cmdline_user_args()):
		print("test_triggers уже есть — пропускаю")
		quit()
		return
	lv = LevelData.new()
	lv.id = "test_triggers"
	lv.title = "Тест: триггеры и реплики"
	lv.bounds = Rect2(0, -200, 3200, 1000)
	lv.kill_y = 900.0
	ground(0, 1900)
	ground(2000, 2450)
	ground(2550, 3200)
	kill(1900, 2000)
	kill(2450, 2550)
	obj("start_1", "start", Vector2(100, G - 20))
	zone("t_wide", Rect2(400, 280, 500, 320), "Широкий зал: вход — камера плавно отдаляется до 0.7, выход — возвращается.")
	# рисуемая дверь (контур) у стены; дорисовал — открывается выход вдали и камера показывает его
	var arch := PackedVector2Array([Vector2(-32, 48), Vector2(-32, -24), Vector2(-22, -40), Vector2(0, -48), Vector2(22, -40), Vector2(32, -24), Vector2(32, 48)])
	obj("p_door", "paintable", Vector2(1100, G - 48), {"result": 0, "targets": PackedStringArray(["exit_1"]), "link_mode": 0})
	role("p_door", "outline", arch)
	zone("t_hint", Rect2(1000, 380, 300, 220), "Подсказка: стоишь 15 с — богиня подсказывает про дверь, ещё 15 с — вторая подсказка.")
	obj("cp_1", "checkpoint", Vector2(1750, G - 36), {})
	zone("t_take_wave", Rect2(2100, 300, 300, 300), "Богиня забирает волну и укорачивает линию (пресет short thick). Смерть до следующего чекпоинта — всё возвращается.")
	obj("exit_1", "exit", Vector2(2900, G - 48), {"locked": true})
	obj("m_exit", "marker", Vector2(2900, G - 60), {"note": "Сюда смотрит камера, когда дверь дорисована."})
	obj("note_1", "note", Vector2(1880, G - 160), {"text": "Пропасти — для проверки барков на смерть (с 3-й)", "show_in_game": true, "font_size": 13})
	var err := ResourceSaver.save(lv, PATH)
	print("test_triggers: %s" % ("ok" if err == OK else "ошибка %d" % err))
	quit()


func ground(x0: float, x1: float) -> void:
	var s := GeoShape.new()
	s.uid = lv.next_uid("shape")
	s.kind = GeoShape.Kind.RECT
	s.position = Vector2(x0, G)
	s.points = PackedVector2Array([Vector2.ZERO, Vector2(x1 - x0, 0), Vector2(x1 - x0, 200), Vector2(0, 200)])
	s.visible_in_game = true
	s.color = Color(0.3, 0.33, 0.4)
	lv.shapes.append(s)


func kill(x0: float, x1: float) -> void:
	var s := GeoShape.new()
	s.uid = lv.next_uid("shape")
	s.kind = GeoShape.Kind.KILL
	s.position = Vector2(x0, G + 120)
	s.points = PackedVector2Array([Vector2.ZERO, Vector2(x1 - x0, 0), Vector2(x1 - x0, 60), Vector2(0, 60)])
	lv.shapes.append(s)


func obj(uid: String, def_id: String, pos: Vector2, props: Dictionary = {}) -> void:
	var d := Catalog.get_def(def_id)
	var o := PlacedObject.new()
	o.uid = uid
	o.def_id = def_id
	o.position = pos
	o.layer = d.default_layer if d != null else 3
	o.props = props
	lv.objects.append(o)


func role(owner_uid: String, r: String, pts: PackedVector2Array) -> void:
	var s := GeoShape.new()
	s.uid = lv.next_uid("shape")
	s.role = r
	s.parent_uid = owner_uid
	s.kind = GeoShape.Kind.BODY
	s.closed = true
	s.points = pts
	s.color = Color(0.45, 1.0, 0.65)
	lv.shapes.append(s)


func zone(uid: String, r: Rect2, note: String) -> void:
	obj(uid, "zone", r.get_center(), {"note": note})
	var c := r.get_center()
	role(uid, "zone", PackedVector2Array([r.position - c, Vector2(r.end.x, r.position.y) - c, r.end - c, Vector2(r.position.x, r.end.y) - c]))
