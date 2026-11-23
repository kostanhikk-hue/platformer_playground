extends PanelContainer
## loc: dev-file — инструмент разработчика, текст не локализуется
## Универсальная панель настроек. По любому Resource со скриптом и @export-переменными
## сама строит элементы управления, пресеты и кнопки сохранения:
##   @export_range(...) float/int → ползунок + поле точного ввода (можно вписать число руками);
##   @export bool                 → переключатель;
##   @export_enum(...) int        → выпадающий список;
##   @export Color                → выбор цвета;
##   @export_group("...")         → заголовок раздела.
## Подписи берутся из LABELS, единицы — из UNITS, всплывающие подсказки — из HINTS (константы в скрипте ресурса).
## В поле можно вписать ЛЮБОЕ число — пределы @export_range задают только удобный ход ползунка.
## Если вписанное число за пределами, ползунок расширяется до него.
## Enter / Esc / клик мимо панели — выход из поля (пока курсор в поле, герой не слушает клавиши).
##   @export String               → строка ввода (применяется по Enter или при уходе из поля).
##
## Необязательные ключи записи (для инспектора конструктора и подобного):
##   "on_change": Callable(имя, значение) — вызывается после каждого изменения значения;
##   "file_buttons": false               — не показывать раздел «Файл» (ресурс не живёт в своём файле);
##   "custom": Callable(box, запись, свойство, подпись, единица, подсказка) -> bool — своё поле вместо стандартного
##             (true — поле построено; оно само кладёт в запись["controls"][имя] {"kind": "custom", "refresh": Callable(значение)}).

const PANEL_SIZE := Vector2(400, 704)

## Размер панели. Можно поменять до build().
var panel_size := PANEL_SIZE

var tabs: TabContainer
var status_label: Label
var footer: HFlowContainer
var _entries: Array = []


## entries: [{ "title": "Удар", "res": Resource, "preset_dir": "res://data/presets/attack" }, ...]
func build(entries: Array) -> void:
	_entries = entries
	custom_minimum_size = panel_size
	size = panel_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.add_theme_font_size_override("font_size", 12)
	root.add_child(tabs)
	for e in entries:
		tabs.add_child(_build_tab(e))

	footer = HFlowContainer.new()
	root.add_child(footer)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	status_label.custom_minimum_size = Vector2(0, 36)
	root.add_child(status_label)


## Кнопка в нижней строке панели (под вкладками).
func add_footer_button(text: String, cb: Callable) -> void:
	_button(footer, text, cb)


func say(text: String) -> void:
	if status_label:
		status_label.text = text


## Перечитать значения всех вкладок из ресурсов (если их поменял код).
func refresh_all() -> void:
	for e in _entries:
		refresh_entry(e)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text.to_upper()
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	l.add_theme_font_size_override("font_size", 13)
	return l


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


# ------------------------------------------------------------ вкладка

func _build_tab(e: Dictionary) -> Control:
	e["controls"] = {}
	var scroll := ScrollContainer.new()
	scroll.name = e["title"]
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)

	var res: Resource = e["res"]
	var consts: Dictionary = res.get_script().get_script_constant_map()
	var labels: Dictionary = consts.get("LABELS", {})
	var units: Dictionary = consts.get("UNITS", {})
	var hints: Dictionary = consts.get("HINTS", {})

	if e.get("preset_dir", "") != "":
		box.add_child(_section("Пресеты"))
		var flow := HFlowContainer.new()
		box.add_child(flow)
		e["preset_flow"] = flow
		_rebuild_presets(e)

	var pending_group := ""
	for pr in res.get_property_list():
		var usage: int = pr["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			pending_group = pr["name"]   # заголовок покажем, только если в группе есть наши параметры
			continue
		if not ((usage & PROPERTY_USAGE_EDITOR) and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE)):
			continue
		if pending_group != "":
			box.add_child(_section(pending_group))
			pending_group = ""
		var pname: String = pr["name"]
		_add_control(box, e, pr, labels.get(pname, pname), units.get(pname, ""), hints.get(pname, ""))
	refresh_entry(e)

	if e.get("file_buttons", true):
		box.add_child(_section("Файл"))
		var actions := HFlowContainer.new()
		box.add_child(actions)
		_button(actions, "Сохранить в файл", _on_save.bind(e))
		_button(actions, "Откатить к файлу", _on_revert.bind(e))
		_button(actions, "К значениям скрипта", _on_defaults.bind(e))

	if e.get("preset_dir", "") != "":
		var row := HBoxContainer.new()
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "имя нового пресета"
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_edit)
		_button(row, "Сохранить пресет", _on_save_preset.bind(e, name_edit))
		box.add_child(row)
	return scroll


## Записать значение в ресурс записи и сообщить подписчику (если есть).
func _set_value(e: Dictionary, pname: String, v: Variant) -> void:
	e["res"].set(pname, v)
	var cb: Callable = e.get("on_change", Callable())
	if cb.is_valid():
		cb.call(pname, v)


func _add_control(box: VBoxContainer, e: Dictionary, pr: Dictionary, label_text: String, unit: String, hint_text: String) -> void:
	var custom: Callable = e.get("custom", Callable())
	if custom.is_valid() and custom.call(box, e, pr, label_text, unit, hint_text):
		return
	var pname: String = pr["name"]
	var t: int = pr["type"]
	var hint: int = pr["hint"]
	var hint_string: String = pr["hint_string"]
	var head := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = label_text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 13)
	if hint_text != "":
		name_l.tooltip_text = hint_text
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		name_l.text += "  ⓘ"
	head.add_child(name_l)

	if t == TYPE_BOOL:
		var cb := CheckButton.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on: bool) -> void: _set_value(e, pname, on))
		head.add_child(cb)
		box.add_child(head)
		e["controls"][pname] = {"kind": "bool", "ctrl": cb, "label": name_l}
	elif t == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for item in hint_string.split(","):
			ob.add_item(item.get_slice(":", 0))
		ob.item_selected.connect(func(idx: int) -> void: _set_value(e, pname, idx))
		head.add_child(ob)
		box.add_child(head)
		e["controls"][pname] = {"kind": "enum", "ctrl": ob, "label": name_l}
	elif t == TYPE_COLOR:
		var cp := ColorPickerButton.new()
		cp.custom_minimum_size = Vector2(64, 24)
		cp.focus_mode = Control.FOCUS_NONE
		cp.color_changed.connect(func(c: Color) -> void: _set_value(e, pname, c))
		head.add_child(cp)
		box.add_child(head)
		e["controls"][pname] = {"kind": "color", "ctrl": cp, "label": name_l}
	elif (t == TYPE_INT or t == TYPE_FLOAT) and hint == PROPERTY_HINT_RANGE:
		var parts := hint_string.split(",")
		var is_int := t == TYPE_INT
		var step := float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else (1.0 if is_int else 0.01)
		var s := HSlider.new()
		s.min_value = float(parts[0])
		s.max_value = float(parts[1])
		s.step = step
		s.focus_mode = Control.FOCUS_NONE
		s.scrollable = false
		s.custom_minimum_size = Vector2(0, 18)
		var sp := SpinBox.new()
		sp.min_value = s.min_value
		sp.max_value = s.max_value
		sp.allow_greater = true
		sp.allow_lesser = true
		# поле точнее ползунка: шаг ввода в 10 раз мельче шага ползунка
		sp.step = 1.0 if is_int else step / 10.0
		sp.custom_arrow_step = step
		sp.suffix = unit
		sp.select_all_on_focus = true
		sp.custom_minimum_size = Vector2(118, 0)
		head.add_child(sp)
		box.add_child(head)
		box.add_child(s)
		var c := {"kind": "slider", "ctrl": s, "spin": sp, "label": name_l}
		e["controls"][pname] = c
		s.value_changed.connect(func(v: float) -> void:
			sp.set_value_no_signal(v)
			_set_value(e, pname, int(v) if is_int else v))
		sp.value_changed.connect(func(v: float) -> void:
			_fit_slider(s, v)
			_set_value(e, pname, int(roundf(v)) if is_int else v))
		var le := sp.get_line_edit()
		le.text_submitted.connect(func(_t: String) -> void: le.release_focus.call_deferred())
		le.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				le.release_focus()
				le.accept_event())
	elif t == TYPE_STRING and hint == PROPERTY_HINT_MULTILINE_TEXT:
		var te := TextEdit.new()
		te.custom_minimum_size = Vector2(0, 76)
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.focus_exited.connect(func() -> void:
			if str(e["res"].get(pname)) != te.text:
				_set_value(e, pname, te.text))
		te.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				te.release_focus()
				te.accept_event())
		box.add_child(head)
		box.add_child(te)
		e["controls"][pname] = {"kind": "text", "ctrl": te, "label": name_l}
	elif t == TYPE_STRING:
		var le := LineEdit.new()
		le.custom_minimum_size = Vector2(150, 0)
		le.select_all_on_focus = true
		var apply := func(_x = null) -> void:
			if str(e["res"].get(pname)) != le.text:
				_set_value(e, pname, le.text)
		le.text_submitted.connect(func(_t: String) -> void:
			apply.call()
			le.release_focus.call_deferred())
		le.focus_exited.connect(apply)
		le.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				le.release_focus()
				le.accept_event())
		head.add_child(le)
		box.add_child(head)
		e["controls"][pname] = {"kind": "string", "ctrl": le, "label": name_l}
	else:
		push_warning("ParamPanel: тип параметра «%s» не поддерживается, пропускаю" % pname)


func refresh_entry(e: Dictionary) -> void:
	var res: Resource = e["res"]
	for pname in e["controls"]:
		var c: Dictionary = e["controls"][pname]
		var v = res.get(pname)
		match c["kind"]:
			"bool":
				c["ctrl"].set_pressed_no_signal(bool(v))
			"enum":
				c["ctrl"].select(int(v))
			"color":
				c["ctrl"].color = v
			"string":
				if not c["ctrl"].has_focus():
					c["ctrl"].text = str(v)
			"custom":
				(c["refresh"] as Callable).call(v)
			"text":
				if not c["ctrl"].has_focus():
					c["ctrl"].text = str(v)
			"slider":
				_fit_slider(c["ctrl"], float(v))
				c["spin"].set_value_no_signal(float(v))


## Ставит ползунок на значение; если оно за пределами — расширяет ход ползунка.
func _fit_slider(s: HSlider, v: float) -> void:
	if v < s.min_value:
		s.min_value = v
	if v > s.max_value:
		s.max_value = v
	s.set_value_no_signal(v)


# ------------------------------------------------------------ сохранение

func _copy_values(from: Resource, to: Resource, names: Array) -> void:
	for n in names:
		to.set(n, from.get(n))


func _on_save(e: Dictionary) -> void:
	var res: Resource = e["res"]
	var err := ResourceSaver.save(res, res.resource_path)
	if err == OK:
		say("Сохранено: " + res.resource_path)
	else:
		say("Не удалось сохранить (код %d). Запусти проект из редактора." % err)


func _on_revert(e: Dictionary) -> void:
	var res: Resource = e["res"]
	var disk := ResourceLoader.load(res.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if disk == null:
		say("Файл не найден")
		return
	_copy_values(disk, res, e["controls"].keys())
	refresh_entry(e)
	say("Значения возвращены из файла")


func _on_defaults(e: Dictionary) -> void:
	var res: Resource = e["res"]
	var fresh: Resource = res.get_script().new()
	_copy_values(fresh, res, e["controls"].keys())
	refresh_entry(e)
	say("Сброшено к значениям из скрипта (файл не изменён)")


# ------------------------------------------------------------ пресеты

func _preset_title(file_name: String) -> String:
	var n := file_name.get_basename()
	var rx := RegEx.create_from_string("^\\d+_")
	return rx.sub(n, "").replace("_", " ")


func _rebuild_presets(e: Dictionary) -> void:
	var flow: HFlowContainer = e["preset_flow"]
	for c in flow.get_children():
		c.queue_free()
	var dir: String = e.get("preset_dir", "")
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f in files:
		if f.ends_with(".tres"):
			_button(flow, _preset_title(f), _on_preset.bind(e, dir + "/" + f))


func _on_preset(e: Dictionary, path: String) -> void:
	var pr := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if pr == null:
		say("Не удалось загрузить пресет")
		return
	_copy_values(pr, e["res"], e["controls"].keys())
	refresh_entry(e)
	say("Пресет: " + _preset_title(path.get_file()) + "  (не забудь «Сохранить в файл», если он нужен в игре)")


func _on_save_preset(e: Dictionary, name_edit: LineEdit) -> void:
	var n := name_edit.text.strip_edges().replace(" ", "_")
	var dir: String = e.get("preset_dir", "")
	if n == "" or dir == "":
		say("Введи имя пресета")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var copy: Resource = (e["res"] as Resource).duplicate()
	var err := ResourceSaver.save(copy, dir + "/" + n + ".tres")
	if err == OK:
		say("Пресет сохранён: " + dir + "/" + n + ".tres")
		name_edit.text = ""
		_rebuild_presets(e)
	else:
		say("Не удалось сохранить пресет (код %d)" % err)
