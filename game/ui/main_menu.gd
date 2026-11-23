extends Node
## Главное меню игры: «Играть уровень» (список уровней из content/levels/, временно — до кампании),
## «Настройки» (язык текста и озвучки), «Разработка» (только в dev-сборке), «Выход».
## Все надписи — ключи из content/i18n/ui.csv: Label и Button переводятся сами при смене языка.

const LevelFiles := preload("res://game/level/level_files.gd")
const LevelRuntime := preload("res://game/level/level_runtime.gd")
const Dev := preload("res://core/dev.gd")
const DEV_MENU := "res://editor/launcher.tscn"

var _box: VBoxContainer


func _ready() -> void:
	Fx.set_base_scale(1.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(420, 0)
	_box.add_theme_constant_override("separation", 10)
	center.add_child(_box)
	_show_main()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _title(key: String) -> void:
	var t := Label.new()
	t.text = key
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	_box.add_child(t)


func _button(key: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = key
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	(parent if parent != null else _box).add_child(b)
	return b


func _show_main() -> void:
	_clear()
	_title("ui.main_menu.title")
	_button("ui.main_menu.play", _show_levels).grab_focus.call_deferred()
	_button("ui.main_menu.settings", _show_settings)
	if Dev.enabled():
		_button("ui.main_menu.dev", func() -> void: get_tree().change_scene_to_file(DEV_MENU))
	_button("ui.main_menu.quit", func() -> void: get_tree().quit())


func _show_levels() -> void:
	_clear()
	_title("ui.levels.title")
	var levels := LevelFiles.all_levels()
	if levels.is_empty():
		var l := Label.new()
		l.text = "ui.levels.empty"
		_box.add_child(l)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, mini(levels.size(), 8) * 48)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for lv in levels:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Loc.bind(b, "ui.levels.item", {"id": lv["id"], "epoch": Loc.ref("ui.epoch." + str(lv["epoch"]))})
		b.pressed.connect(_play.bind(lv["path"]))
		list.add_child(b)
	_button("ui.common.back", _show_main).grab_focus.call_deferred()


# ------------------------------------------------------------ настройки

func _show_settings() -> void:
	_clear()
	_title("ui.settings.title")
	var sec := Label.new()
	sec.text = "ui.settings.language"
	sec.add_theme_font_size_override("font_size", 20)
	sec.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_box.add_child(sec)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	_box.add_child(grid)
	var text_opt := _option_row(grid, "ui.settings.text_language")
	var langs := Loc.available_locales(Dev.enabled())
	for i in range(langs.size()):
		var l: Dictionary = langs[i]
		var item: String = l["name"] if l["ready"] else Loc.t("ui.settings.unready", {"name": l["name"], "percent": l["percent"]})
		text_opt.add_item(item, i)
		text_opt.set_item_metadata(i, l["code"])
		if l["code"] == Loc.get_locale():
			text_opt.select(i)
	text_opt.item_selected.connect(func(i: int) -> void: Loc.set_locale(text_opt.get_item_metadata(i)))
	var voice_opt := _option_row(grid, "ui.settings.voice_language")
	var voices := Loc.voice_locales()
	for i in range(voices.size()):
		voice_opt.add_item(voices[i]["name"], i)
		voice_opt.set_item_metadata(i, voices[i]["code"])
		if voices[i]["code"] == Loc.get_voice_locale():
			voice_opt.select(i)
	voice_opt.item_selected.connect(func(i: int) -> void: Loc.set_voice_locale(voice_opt.get_item_metadata(i)))
	_button("ui.common.back", _show_main)
	text_opt.grab_focus.call_deferred()


func _option_row(grid: GridContainer, key: String) -> OptionButton:
	var l := Label.new()
	l.text = key
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(200, 40)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# самоназвания языков («English», «Deutsch») не переводятся
	o.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(o)
	return o


func _play(path: String) -> void:
	LevelRuntime.requested_path = path
	get_tree().change_scene_to_file(LevelRuntime.SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_show_main()
