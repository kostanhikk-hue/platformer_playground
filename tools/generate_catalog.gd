extends SceneTree
## Создаёт и обновляет записи каталога (catalog/common/*.tres) для объектов палитры v1 и фазы 2.
## Запуск:  godot --headless --path . --script tools/generate_catalog.gd
## Существующие записи обновляются (сцена, свойства, описание, метки), но настроенное тобой —
## значения по умолчанию (default_props, кнопка «Сохранить как значения каталога») и формы — сохраняется.
## Сбросить и их:  ... -- --force

const OBJ := "res://game/level/objects/"
const COMP := "res://game/components/"

var force := false


func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://catalog/common")

	# ---- служебное и v1
	_def("start", "Старт героя", "Служебное", "player_start", null, Color(0.4, 0.95, 0.5), Vector2(24, 40), 5,
		{"unique": true, "description": "Точка появления героя (центр героя). Одна на уровень.", "snap_to_floor": true, "kind": "start"})
	_def("checkpoint", "Чекпоинт", "Интерактив", "checkpoint", OBJ + "checkpoint_props", Color(0.95, 0.6, 0.3), Vector2(40, 72), 3,
		{"description": "Точка возрождения: касанием, E или по связи (рисуемая «ладонь»). Лечит и пополняет охру; что сделано до него — не откатывается.",
		"tags": ["interactive", "activatable"], "kind": "checkpoint", "snap_to_floor": true})
	_def("exit", "Выход", "Служебное", "exit", OBJ + "exit_props", Color(0.35, 0.8, 1.0), Vector2(64, 96), 3,
		{"description": "Конец уровня. Можно запереть (locked) — откроет связь: рисуемая дверь, рычаг.", "tags": ["activatable"], "kind": "exit", "snap_to_floor": true})
	_def("dummy", "Манекен", "Враги", "dummy", OBJ + "dummy_props", Color(0.82, 0.3, 0.3), Vector2(40, 52), 3,
		{"description": "Враг-манекен: стоит, патрулирует, таранит или ходит по пути.", "tags": ["enemy", "path_user"], "kind": "dummy", "snap_to_floor": true})
	_def("note", "Подпись", "Служебное", "note", OBJ + "note_props", Color(1, 1, 1, 0.8), Vector2(96, 24), 5,
		{"description": "Текст в мире: заметка для себя или подпись в игре.", "kind": "note"})
	_def("zone", "Триггер-зона", "Служебное", "zone", OBJ + "zone_props", Color(0.45, 1.0, 0.65), Vector2(192, 128), 5,
		{"description": "Место для сценария уровня: вход и выход героя. Дай понятный id (t_…) и заметку, что здесь должно происходить. Быстро — инструмент «Зона» (Z).",
		"tags": ["activatable"], "kind": "zone", "uid_prefix": "t", "shapes": [["zone", PackedVector2Array([Vector2(-96, -64), Vector2(96, -64), Vector2(96, 64), Vector2(-96, 64)]), true]]})
	_def("marker", "Метка", "Служебное", "marker", OBJ + "marker_props", Color(0.6, 0.85, 1.0), Vector2(20, 20), 5,
		{"description": "Точка для сценария: куда смотрит камера, где появляется враг. Дай id (m_…) и заметку. Быстро — клавиша M.",
		"kind": "marker", "uid_prefix": "m"})
	_def("art", "Картинка", "Арт-объекты", "art_object", OBJ + "art_props", Color(0.9, 0.9, 0.9), Vector2(64, 64), 3, {"transformable": true, "hidden": true})

	# ---- рисуемое
	var rect := func(w: float, h: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2), Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2)])
	_def("paintable", "Рисуемый контур", "Рисуемое", "paintable", COMP + "paintable_props", Color(1.0, 0.85, 0.55), Vector2(128, 64), 3,
		{"description": "Пунктирный силуэт: герой дорисовывает его штрихом или удержанием E — появляется тело, платформа, стена, срабатывают связи. Двойной клик — правка формы.",
		"tags": ["paintable", "activatable", "link_source", "interactive"], "kind": "paintable",
		"shapes": [["outline", rect.call(128.0, 64.0), true]]})
	_def("coverage", "Закрашиваемая поверхность", "Рисуемое", "coverage", COMP + "coverage_props", Color(0.95, 0.55, 0.35), Vector2(192, 128), 3,
		{"description": "Область, которую закрашивают штрихи и удары. Пороги — события, 100 % — связи. Можно привязать к объекту.",
		"tags": ["paintable", "activatable", "link_source"], "kind": "coverage", "shapes": [["area", rect.call(192.0, 128.0), true]]})

	# ---- интерактив
	_def("lever", "Рычаг", "Интерактив", "lever", COMP + "lever_props", Color(0.95, 0.45, 0.35), Vector2(40, 32), 3,
		{"description": "E рядом — переключить. Связи: открыть дверь, запустить платформу, зажечь факел…",
		"tags": ["interactive", "activatable", "link_source"], "kind": "lever", "snap_to_floor": true})
	_def("plate", "Нажимная плита", "Интерактив", "plate", COMP + "plate_props", Color(0.95, 0.75, 0.3), Vector2(48, 12), 3,
		{"description": "Нажата, пока на ней то, что отмечено галочками: герой, враги, штрихи (линия через плиту), другие тела. Обычно связь «Следовать» на дверь.",
		"tags": ["link_source"], "kind": "plate", "snap_to_floor": true})
	_def("door", "Дверь", "Интерактив", "door", COMP + "door_props", Color(0.6, 0.45, 0.3), Vector2(32, 96), 3,
		{"description": "Открывается связью: вверх, в стороны или растворяется. Активна = открыта.",
		"tags": ["activatable"], "kind": "door", "snap_to_floor": true})

	# ---- платформы
	_def("crumble", "Ломкая платформа", "Платформы", "crumble", COMP + "crumble_props", Color(0.65, 0.55, 0.45), Vector2(96, 16), 3,
		{"description": "Встал сверху — через миг рушится; через время восстанавливается. Форма — двойной клик.",
		"kind": "crumble", "shapes": [["form", PackedVector2Array([Vector2(-48, 0), Vector2(48, 0)]), false]]})
	_def("breakable", "Разрушаемый блок", "Платформы", "breakable", COMP + "breakable_props", Color(0.55, 0.5, 0.48), Vector2(64, 64), 3,
		{"description": "Твёрдый блок, который ломается ударом, линией или волной. При разрушении срабатывают связи.",
		"tags": ["link_source"], "kind": "breakable", "shapes": [["form", rect.call(64.0, 64.0), true]]})
	_def("moving_platform", "Движущаяся платформа", "Платформы", "moving_platform", COMP + "moving_platform_props", Color(0.55, 0.65, 0.75), Vector2(128, 16), 3,
		{"description": "Едет по пути (инструмент «Путь», L) — туда-обратно, по кругу или один раз. Связь запускает и останавливает.",
		"tags": ["activatable", "path_user"], "kind": "moving_platform", "shapes": [["form", PackedVector2Array([Vector2(-64, 0), Vector2(64, 0)]), false]]})

	# ---- свет
	_def("torch_wall", "Факел настенный", "Свет", "light_source", COMP + "light_source_props", Color(1.0, 0.7, 0.35), Vector2(24, 40), 3,
		{"description": "Источник света: освещает радиус, оживляет картины и «освещаемые» объекты. Связь зажигает и гасит.",
		"tags": ["light_source", "activatable"], "kind": "light", "default_props": {"look": 0, "carryable": false}})
	_def("torch_carry", "Факел переносимый", "Свет", "light_source", COMP + "light_source_props", Color(1.0, 0.8, 0.4), Vector2(24, 40), 3,
		{"description": "Свет, который можно взять E и нести (со светом в руках приёмы недоступны). Ещё раз E — положить.",
		"tags": ["light_source", "activatable", "interactive"], "kind": "light", "snap_to_floor": true,
		"default_props": {"look": 1, "carryable": true, "radius": 220.0}})
	var bison := PackedVector2Array([Vector2(-80, 10), Vector2(-70, -20), Vector2(-40, -38), Vector2(0, -40), Vector2(30, -34),
		Vector2(55, -28), Vector2(70, -12), Vector2(80, 4), Vector2(72, 16), Vector2(60, 14), Vector2(56, 30), Vector2(46, 30),
		Vector2(44, 16), Vector2(-40, 16), Vector2(-44, 30), Vector2(-54, 30), Vector2(-56, 14), Vector2(-74, 18)])
	_def("living_painting", "Ожившая картина", "Свет", "living_painting", COMP + "living_painting_props", Color(0.85, 0.5, 0.25), Vector2(160, 72), 2,
		{"description": "Нарисованный зверь оживает в свете факела (или по связи, или когда дорисован контур): едет по пути — на нём можно ехать — или становится манекеном.",
		"tags": ["activatable", "path_user"], "kind": "living_painting", "shapes": [["form", bison, true]]})

	# ---- враги
	_def("dummy_canvas", "Манекен-холст", "Враги", "dummy_canvas", OBJ + "dummy_canvas_props", Color(0.9, 0.45, 0.4), Vector2(40, 52), 3,
		{"description": "Манекен, которого побеждают закрашиванием: 100 % — исчезает. Отмывается, если перестать закрашивать.",
		"tags": ["enemy", "paintable", "path_user"], "kind": "dummy", "snap_to_floor": true})

	# ---- подборы
	_def("ink_source", "Источник охры", "Подборы", "ink_source", COMP + "ink_source_props", Color(0.86, 0.48, 0.16), Vector2(32, 32), 3,
		{"description": "Охра-камень: пополняет запас чернил касанием или E. Однократный или с перезарядкой.",
		"tags": ["activatable"], "kind": "ink_source", "snap_to_floor": true})
	_def("card", "Карточка", "Подборы", "card", COMP + "card_props", Color(0.96, 0.85, 0.6), Vector2(28, 36), 3,
		{"description": "Карточка-научпоп из content/dialog/cards.csv: подбор касанием, уведомление в углу.", "tags": ["link_source"], "kind": "card"})

	# ---- декор и атмосфера
	_def("anim_decor", "Анимированный декор", "Декор", "anim_decor", COMP + "anim_decor_props", Color(0.75, 0.85, 1.0), Vector2(64, 64), 2,
		{"description": "Картинка-лист с сеткой кадров: огонь, вода, флаг… Частота и петля.", "kind": "anim_decor"})
	_def("atmosphere", "Атмосфера", "Атмосфера", "atmosphere", COMP + "atmosphere_props", Color(0.7, 0.9, 1.0, 0.8), Vector2(512, 256), 4,
		{"description": "Частицы в прямоугольнике: пыль, искры факела, песок, лепестки. Только вид.", "kind": "atmosphere"})

	# ---- готовые наборы (категория «Рисуемое»)
	var arch := PackedVector2Array([Vector2(-32, 48), Vector2(-32, -24), Vector2(-22, -40), Vector2(0, -48), Vector2(22, -40), Vector2(32, -24), Vector2(32, 48)])
	_kit("kit_paint_door", "Рисуемая дверь", "Набор: рисуемый контур двери + запертый выход. Дорисуй дверь — выход откроется.", [
		{"key": "door", "def_id": "paintable", "offset": Vector2.ZERO, "props": {"result": 0, "targets": ["@exit"], "link_mode": 0},
			"shapes": [["outline", arch, true]]},
		{"key": "exit", "def_id": "exit", "offset": Vector2.ZERO, "props": {"locked": true}},
	])
	_kit("kit_paint_bridge", "Рисуемый мост", "Набор: открытый контур над пропастью → платформа. Штрихом или удержанием E.", [
		{"key": "bridge", "def_id": "paintable", "offset": Vector2.ZERO, "props": {"result": 2, "method": 2},
			"shapes": [["outline", PackedVector2Array([Vector2(-128, 0), Vector2(-64, 6), Vector2(0, 8), Vector2(64, 6), Vector2(128, 0)]), false]]},
	])
	_kit("kit_paint_platform", "Рисуемая платформа", "Набор: замкнутый контур → твёрдое тело.", [
		{"key": "plat", "def_id": "paintable", "offset": Vector2.ZERO, "props": {"result": 1},
			"shapes": [["outline", rect.call(128.0, 32.0), true]]},
	])
	_kit("kit_lever_door", "Рычаг и дверь", "Набор: рычаг (связь «Следовать») и дверь.", [
		{"key": "lever", "def_id": "lever", "offset": Vector2(-96, 32), "props": {"targets": ["@door"], "link_mode": 3}},
		{"key": "door", "def_id": "door", "offset": Vector2.ZERO, "props": {}},
	])
	var hand := PackedVector2Array([Vector2(-14, 24), Vector2(-16, 2), Vector2(-26, -12), Vector2(-21, -17), Vector2(-11, -6),
		Vector2(-12, -30), Vector2(-5, -32), Vector2(-2, -10), Vector2(1, -36), Vector2(8, -35), Vector2(7, -9), Vector2(12, -31),
		Vector2(18, -29), Vector2(14, -5), Vector2(22, -19), Vector2(27, -15), Vector2(16, 10), Vector2(14, 24)])
	_kit("kit_palm_checkpoint", "Чекпоинт-ладонь", "Набор: контур ладони → чекпоинт по связи. Дорисуй ладонь — новая точка возрождения.", [
		{"key": "palm", "def_id": "paintable", "offset": Vector2(0, -6), "props": {"result": 0, "targets": ["@cp"], "link_mode": 0, "method": 2},
			"shapes": [["outline", hand, true]]},
		{"key": "cp", "def_id": "checkpoint", "offset": Vector2.ZERO, "props": {"activation": 2, "look": 1}},
	])
	print("Каталог готов")
	quit()


func _def(id: String, title: String, cat: String, scene: String, props, col: Color, sz: Vector2, layer: int, extra: Dictionary) -> void:
	var path := "res://catalog/common/%s.tres" % id
	var d: ObjectDef = null
	var keep_user := false
	if FileAccess.file_exists(path) and not force:
		d = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		keep_user = d != null
	if d == null:
		d = ObjectDef.new()
	d.id = id
	d.title = title
	d.category = cat
	d.epoch = "common"
	d.scene = load(OBJ + scene + ".tscn")
	d.props_script = load(props + ".gd") if props != null else null
	d.editor_color = col
	d.editor_size = sz
	d.default_layer = layer
	d.description = extra.get("description", "")
	d.tags = PackedStringArray(extra.get("tags", []))
	d.kind = extra.get("kind", "")
	d.snap_to_floor = extra.get("snap_to_floor", false)
	d.unique = extra.get("unique", false)
	d.transformable = extra.get("transformable", false)
	d.hidden = extra.get("hidden", false)
	d.uid_prefix = extra.get("uid_prefix", "")
	if not keep_user or d.default_props.is_empty():
		d.default_props = extra.get("default_props", {})
	if not keep_user or d.shapes.is_empty():
		var shs: Array[GeoShape] = []
		for sh in extra.get("shapes", []):
			shs.append(_shape(sh[0], sh[1], sh[2]))
		d.shapes = shs
	var err := ResourceSaver.save(d, path)
	print("%s: %s" % [path, "ok" if err == OK else "ошибка %d" % err])


func _shape(role: String, pts: PackedVector2Array, closed: bool) -> GeoShape:
	var s := GeoShape.new()
	s.role = role
	s.kind = GeoShape.Kind.BODY if closed else GeoShape.Kind.WALL
	s.closed = closed
	s.points = pts
	s.color = Color(1.0, 0.85, 0.55)
	return s


func _kit(id: String, title: String, desc: String, items: Array) -> void:
	var path := "res://catalog/common/%s.tres" % id
	if FileAccess.file_exists(path) and not force:
		return   # набор мог быть настроен кнопкой «Сохранить как значения каталога»
	var d := ObjectDef.new()
	d.id = id
	d.title = title
	d.category = "Рисуемое"
	d.epoch = "common"
	d.description = desc
	d.kind = "kit"
	d.editor_color = Color(1.0, 0.85, 0.55)
	d.editor_size = Vector2(96, 96)
	var kit: Array = []
	for it in items:
		var c: Dictionary = (it as Dictionary).duplicate(true)
		if c.has("shapes"):
			var shs: Array = []
			for sh in c["shapes"]:
				shs.append({"role": sh[0], "points": sh[1], "closed": sh[2]})
			c["shapes"] = shs
		kit.append(c)
	d.kit = kit
	var err := ResourceSaver.save(d, path)
	print("%s: %s" % [path, "ok" if err == OK else "ошибка %d" % err])
