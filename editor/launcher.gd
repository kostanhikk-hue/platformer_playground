extends Node
## Меню разработки: плейграунды и конструктор уровней. Открывается из главного меню (пункт «Разработка»,
## только в dev-сборке). Новый пункт — одна запись в ITEMS. Esc — назад в главное меню.

const MAIN_MENU := "res://game/ui/main_menu.tscn"

const ITEMS := [
	{
		"title": "Конструктор уровней",
		"desc": "Фоны и арт-объекты из картинок, обводка коллизии по точкам, объекты, «Играть отсюда» (F5).",
		"scene": "res://editor/level_editor.tscn",
	},
	{
		"title": "Рисуемые объекты",
		"desc": "Рисуемые контуры (тела, мост, дверь, удержание, временный), закрашивание и манекен-холст, свет и ожившая картина, рычаг, плита, платформы, блок. Уровень pg_paint — его можно править в конструкторе.",
		"scene": "res://playgrounds/paint/paint_playground.tscn",
	},
	{
		"title": "Движение",
		"desc": "Бег, прыжок, инерция, лёд, стены. Столбы и пропасти для замеров.",
		"scene": "res://playgrounds/movement/movement_playground.tscn",
	},
	{
		"title": "Бой, линия и волна",
		"desc": "Удар (замах / активная фаза / восстановление), урон и неуязвимость, штрих-платформа, волна-пандус с вертикальной стеной, манекены и таран.",
		"scene": "res://playgrounds/combat/combat_playground.tscn",
	},
	{
		"title": "Проверка локализации",
		"desc": "Таблицы content/i18n и реплики: повторы ключей, пустой ru, процент перевода, подстановки, max_len, ключи из кода без строк, захардкоженный текст. F9 в игре — перечитать таблицы, F10 — псевдолокализация.",
		"scene": "res://editor/check_loc_view.tscn",
	},
]


func _ready() -> void:
	Fx.set_base_scale(1.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "РАЗРАБОТКА"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Настройки сохраняются в data/*.tres и используются игрой напрямую."
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(sub)

	for item in ITEMS:
		var b := Button.new()
		b.text = item["title"]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(get_tree().change_scene_to_file.bind(item["scene"]))
		box.add_child(b)
		var d := Label.new()
		d.text = item["desc"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		box.add_child(d)

	var back := Button.new()
	back.text = "← Главное меню (Esc)"
	back.pressed.connect(_to_main)
	box.add_child(back)


func _to_main() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_to_main()
