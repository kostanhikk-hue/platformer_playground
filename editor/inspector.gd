extends VBoxContainer
## Инспектор: свойства выделенного (контур, фон, объект) или уровня, если ничего не выделено.
## Поля строит core/param_panel.gd по маленькому ресурсу-прокси (editor/props/*.gd или props_script объекта).
## Правка поля → команда (отменяется Ctrl+Z); серия правок одного поля склеивается в один шаг.
## Свойства, переопределённые относительно каталога, подсвечены; «Вернуть к каталогу» сбрасывает их.

const ParamPanel := preload("res://core/param_panel.gd")
const Commands := preload("res://editor/commands.gd")
const Geometry := preload("res://core/geometry.gd")
const Catalog := preload("res://game/level/catalog.gd")
const ShapeProps := preload("res://editor/props/shape_props.gd")
const BgProps := preload("res://editor/props/bg_props.gd")
const ObjectProps := preload("res://editor/props/object_props.gd")
const ArtObjectProps := preload("res://editor/props/art_object_props.gd")
const LevelProps := preload("res://editor/props/level_props.gd")
const RoleShapeProps := preload("res://editor/props/role_shape_props.gd")
const PathProps := preload("res://editor/props/path_props.gd")
const LitProps := preload("res://game/components/lit_props.gd")
const CardsDB := preload("res://game/components/cards_db.gd")
const Dev := preload("res://core/dev.gd")
const LevelFiles := preload("res://game/level/level_files.gd")
const LINK_KINDS_NO_LIT := ["", "start", "note", "dummy", "kit", "zone", "marker"]

const OVERRIDE_COLOR := Color(1.0, 0.7, 0.3)

var ed
var head: VBoxContainer
var actions: HFlowContainer
var panel
var _sig := "-"
var _mode := ""
var _entries: Array = []
var _items: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = "ИНСПЕКТОР"
	t.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	add_child(t)
	head = VBoxContainer.new()
	add_child(head)
	actions = HFlowContainer.new()
	add_child(actions)


func _signature() -> String:
	var parts: Array = []
	for r in ed.selection:
		parts.append(str(r.get_instance_id()))
	return ",".join(parts) + "|" + ed.level.resource_path + str(ed.level.get_instance_id())


## Вызывается после любого изменения: при смене выделения — перестроить, иначе — обновить значения.
func sync() -> void:
	if ed == null or ed.level == null or head == null:
		return
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		_rebuild()
	else:
		_refresh_values()


func _clear(c: Control) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _rebuild() -> void:
	_clear(head)
	_clear(actions)
	if panel != null:
		panel.queue_free()
		panel = null
	_items = ed.selection.duplicate()
	_entries.clear()
	_mode = _detect_mode()
	_build_head()
	_build_actions()
	match _mode:
		"level":
			_entries.append(_entry("Уровень", LevelProps.new(), "level"))
		"shapes":
			_entries.append(_entry("Контур", ShapeProps.new(), "shape"))
		"role":
			_entries.append(_entry("Форма", RoleShapeProps.new(), "role"))
		"path":
			_entries.append(_entry("Путь", PathProps.new(), "path"))
		"bgs":
			_entries.append(_entry("Фон", BgProps.new(), "bg"))
		"objects":
			var def: ObjectDef = ed.def_of(_items[0])
			if def != null and def.transformable:
				_entries.append(_entry("Объект", ArtObjectProps.new(), "xform"))
			else:
				_entries.append(_entry("Объект", ObjectProps.new(), "pos"))
			if def != null and def.props_script != null:
				_entries.append(_entry("Свойства", def.props_script.new(), "props"))
			if def != null and not LINK_KINDS_NO_LIT.has(def.kind) and def.props_script != null:
				_entries.append(_entry("Освещаемое", LitProps.new(), "lit"))
	var editor_entry: Dictionary = Params.entry("editor")
	_entries.append(editor_entry)
	panel = ParamPanel.new()
	panel.panel_size = Vector2(340, 200)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	_load_all()
	panel.build(_entries)
	_highlight_overrides()


func _entry(title: String, proxy: Resource, kind: String) -> Dictionary:
	var e := {"title": title, "res": proxy, "preset_dir": "", "file_buttons": false, "kind": kind}
	e["on_change"] = func(pname: String, value: Variant) -> void: _on_change(e, pname, value)
	e["custom"] = _custom_field
	return e


func _detect_mode() -> String:
	if _items.is_empty():
		return "level"
	if _items.size() == 1 and _items[0] is GeoShape and _items[0].role != "":
		return "role"
	if _items.size() == 1 and _items[0] is GeoShape and _items[0].kind == GeoShape.Kind.PATH:
		return "path"
	if _items.all(func(r): return r is GeoShape and r.role == "" and r.kind != GeoShape.Kind.PATH):
		return "shapes"
	if _items.all(func(r): return r is BackgroundLayer):
		return "bgs"
	if _items.all(func(r): return r is PlacedObject and r.def_id == _items[0].def_id):
		return "objects"
	return "mixed"


# ------------------------------------------------------------ шапка

func _build_head() -> void:
	var kind := Label.new()
	kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kind.custom_minimum_size = Vector2(100, 0)
	head.add_child(kind)
	match _mode:
		"level":
			kind.text = "Уровень «%s» · %s" % [ed.level.id, ed.level_path if ed.level_path != "" else "не сохранён"]
		"shapes":
			kind.text = "Контур: %s%s" % [GeoShape.KIND_TITLES[_items[0].kind], "" if _items.size() == 1 else "  (выделено %d)" % _items.size()]
			if _items.size() == 1 and _items[0].parent_uid != "":
				kind.text += "  · привязан к " + _items[0].parent_uid
		"role":
			var s: GeoShape = _items[0]
			kind.text = "Форма «%s» объекта %s · %s, точек %d\nТяни точки, клик по ребру — новая точка, ПКМ — удалить. Esc — к объекту." % [GeoShape.ROLE_TITLES.get(s.role, s.role), s.parent_uid, "замкнутая" if s.is_closed() else "открытая", s.points.size()]
		"path":
			var s: GeoShape = _items[0]
			kind.text = "Путь · точек %d · %s\nТяни точки; объекты выбирают путь пипеткой ⌖." % [s.points.size(), "по кругу" if s.closed else "открытый"]
		"bgs":
			kind.text = "Фон: %s%s" % [_items[0].path.get_file(), "" if _items.size() == 1 else "  (выделено %d)" % _items.size()]
		"objects":
			var def: ObjectDef = ed.def_of(_items[0])
			kind.text = "Объект: %s%s" % [def.title if def != null else "? " + _items[0].def_id, "" if _items.size() == 1 else "  (выделено %d)" % _items.size()]
			if def != null and def.description != "":
				var dl := Label.new()
				dl.text = def.description
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.custom_minimum_size = Vector2(100, 0)
				dl.add_theme_font_size_override("font_size", 11)
				dl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
				head.add_child.call_deferred(dl)
			var kit_id := String(_items[0].props.get("_kit", ""))
			if _items.size() == 1 and kit_id != "":
				var kd := Catalog.get_def(kit_id)
				kind.text += "  · из набора «%s»" % (kd.title if kd != null else kit_id)
		"mixed":
			kind.text = "Выделено разное: %d. Общие свойства — только у одного вида." % _items.size()
	if _items.size() == 1:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "uid"
		row.add_child(l)
		var le := LineEdit.new()
		le.text = _items[0].uid
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_submitted.connect(func(t: String) -> void:
			_rename(_items[0], t.strip_edges())
			le.release_focus.call_deferred())
		row.add_child(le)
		head.add_child(row)
	if _mode == "objects" or _mode == "bgs":
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "Слой"
		row.add_child(l)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for t in LevelData.LAYER_TITLES:
			ob.add_item(t)
		ob.select(clampi(_items[0].layer, 0, LevelData.LAYER_TITLES.size() - 1))
		ob.item_selected.connect(func(i: int) -> void:
			var cmds: Array = []
			for r in _items:
				cmds.append(Commands.PropsCmd.new(r, {"layer": r.layer}, {"layer": i}, "Слой"))
			ed.exec(Commands.Batch.new(cmds, "Слой")))
		row.add_child(ob)
		head.add_child(row)


func _rename(r: Resource, new_uid: String) -> void:
	if new_uid == r.uid:
		return
	if new_uid == "" or ed.level.all_uids().has(new_uid):
		ed.say("uid «%s» пустой или уже занят" % new_uid)
		_sig = "-"
		sync()
		return
	var cmds: Array = [Commands.PropsCmd.new(r, {"uid": r.uid}, {"uid": new_uid}, "Переименовать")]
	if r is PlacedObject:
		for s in ed.level.shapes_of(r.uid):
			cmds.append(Commands.PropsCmd.new(s, {"parent_uid": r.uid}, {"parent_uid": new_uid}))
	ed.exec(Commands.Batch.new(cmds, "Переименовать"))
	ed.say("uid: " + new_uid)


# ------------------------------------------------------------ кнопки

func _btn(text: String, cb: Callable, tip: String = "") -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	actions.add_child(b)


func _build_actions() -> void:
	match _mode:
		"level":
			_btn("Проверить уровень", ed.validate)
			var sp: String = ed.script_path()
			var has := FileAccess.file_exists(sp)
			var l := Label.new()
			l.text = ("Сценарий уровня: %s" % sp.get_file()) if has else "Сценария уровня нет — уровень работает без него. Сценарий пишет агент по зонам, меткам и заметкам."
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(300, 0)
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if has else Color(1, 1, 1, 0.55))
			actions.add_child(l)
			_btn("Скопировать задание для агента", ed.copy_script_brief, "В буфер обмена: уровень, файл сценария, все зоны и метки с заметками — вставь в сообщение агенту и допиши, что должно происходить.")
			if has:
				_btn("Открыть сценарий", func() -> void: OS.shell_open(ProjectSettings.globalize_path(sp)), "Открыть файл сценария в программе по умолчанию.")
			else:
				_btn("Создать заготовку сценария", ed.create_script_stub, "Файл content/levels/<эпоха>/<id>.gd с пустыми событиями и списком зон и меток в комментарии.")
		"shapes":
			_btn("Упростить", _simplify, "Убрать лишние точки с допуском «Допуск „Упростить“» (вкладка «Редактор»).")
			if _items.size() == 1:
				var s: GeoShape = _items[0]
				_btn("Замкнуть" if not s.is_closed() else "Разомкнуть", _toggle_closed, "Тело ↔ стена: замкнутый контур становится открытой ломаной и обратно.")
				if s.parent_uid != "":
					_btn("Отвязать", func() -> void: ed.exec(ed.unbind_cmd(s)))
				else:
					_btn("Привязать к объекту", _bind, "Привязать к арт-объекту под центром контура: будет двигаться вместе с ним.")
		"role":
			var s: GeoShape = _items[0]
			var o: PlacedObject = ed.level.find_object(s.parent_uid)
			if o != null:
				_btn("← К объекту (Esc)", func() -> void: ed.set_selection([o]))
				_btn("Нарисовать заново", func() -> void: ed.begin_form_draw(o, s.role, s), "Обвести форму заново теми же инструментами точек (клики, лассо, привязки). Старая форма заменится.")
			_btn("Упростить", _simplify, "Убрать лишние точки (допуск — вкладка «Редактор»).")
			if s.role != "area" and s.role != "weak":
				_btn("Замкнуть" if not s.is_closed() else "Разомкнуть", _toggle_role_closed, "Замкнутый контур ↔ открытая линия (мост, платформа).")
			if s.role == "weak" and o != null:
				_btn("Удалить уязвимое место", func() -> void:
					ed.exec(Commands.ListCmd.new(ed.level, "shapes", [s], false, "Удалить уязвимое место"))
					ed.set_selection([o]))
		"path":
			_btn("Упростить", _simplify, "Убрать лишние точки (допуск — вкладка «Редактор»).")
			_btn("Кто едет по пути", _who_uses_path, "Выделить объекты, которые ссылаются на этот путь.")
		"bgs":
			_btn("По высоте границ", _fit_bg, "Масштаб фона — по высоте границ уровня, верх — по верху границ.")
		"objects":
			var o: PlacedObject = _items[0]
			var def: ObjectDef = ed.def_of(o)
			if _items.size() == 1 and def != null and def.transformable:
				_btn("Обвести по контуру картинки", func() -> void: ed.autotrace(o, false), "Тела по непрозрачным пикселям (порог и точность — вкладка «Редактор»).")
				_btn("Только верхняя кромка", func() -> void: ed.autotrace(o, true), "Платформа по верхнему краю силуэта: «по этому камню можно ходить».")
				_btn("Сохранить в палитру", func() -> void: ed.save_art_to_palette(o), "Картинка + привязанные контуры → catalog/<эпоха>/<id>.tres")
				if def.image != "":
					_btn("Обновить из палитры", func() -> void: ed.update_from_palette(o), "Картинка и контуры — как сейчас в палитре.")
			if _items.size() == 1 and def != null and not def.transformable:
				var roles: Array = ed.level.role_shapes(o.uid)
				var main_role := _main_role(def)
				if not roles.is_empty():
					_btn("Править форму", func() -> void: ed.enter_form_edit(o, o.position), "То же, что двойной клик по объекту: ручки точек формы.")
				if main_role != "":
					var old: GeoShape = null
					for r in roles:
						if r.role == main_role:
							old = r
							break
					_btn("Нарисовать форму заново", func() -> void: ed.begin_form_draw(o, main_role, old), "Обвести «%s» по точкам (по картинке на фоне, по рельефу)." % GeoShape.ROLE_TITLES.get(main_role, main_role))
				if def.kind == "zone":
					_btn("Прямоугольником", func() -> void:
						ed.set_tool("zone")
						ed.tools["zone"].target = o
						ed.say("Тяни новый прямоугольник зоны %s" % o.uid), "Новая форма зоны — тянуть мышью прямоугольник.")
				if def.kind == "coverage":
					_btn("Добавить уязвимое место", func() -> void: ed.begin_form_draw(o, "weak", null), "Если уязвимые места есть — процент считается только по ним.")
				var art_prop: String = {"paintable": "result_art", "living_painting": "image"}.get(def.kind, "")
				if art_prop != "" and String(ed.prop(o, art_prop, "")) != "":
					_btn("Обвести форму по картинке", func() -> void: _trace_from_art(o, def, main_role, art_prop), "Форма — по непрозрачному силуэту картинки (порог и точность — вкладка «Редактор»).")
				if Dev.enabled():
					_btn("Сохранить как значения каталога", func() -> void: ed.save_to_catalog(o), "Свойства и форма этого объекта станут значениями по умолчанию: новые из палитры придут уже настроенными.")
			_btn("Вернуть к каталогу", _revert_props, "Сбросить свойства, отличные от каталога.")


func _main_role(def: ObjectDef) -> String:
	match def.kind:
		"paintable": return "outline"
		"coverage": return "area"
		"crumble", "breakable", "moving_platform", "living_painting": return "form"
		"zone": return "zone"
	return ""


func _trace_from_art(o: PlacedObject, def: ObjectDef, role: String, art_prop: String) -> void:
	var path := String(ed.prop(o, art_prop, ""))
	if def.kind == "paintable":
		ed.trace_form(o, role, path, float(ed.prop(o, "art_scale", 1.0)), Vector2(ed.prop(o, "art_x", 0.0), ed.prop(o, "art_y", 0.0)))
	else:
		ed.trace_form(o, role, path, float(ed.prop(o, "image_scale", 1.0)), Vector2.ZERO)


func _toggle_role_closed() -> void:
	var s: GeoShape = _items[0]
	if not s.is_closed() and s.points.size() < 3:
		ed.say("Чтобы замкнуть, нужно хотя бы 3 точки")
		return
	var b := Commands.snap(s, ["kind", "closed"])
	var to_closed := not s.is_closed()
	s.kind = GeoShape.Kind.BODY if to_closed else GeoShape.Kind.WALL
	s.closed = to_closed
	ed.push_done(Commands.props_from(s, b, "Замкнуть / разомкнуть форму"))
	_sig = "-"
	sync()


func _who_uses_path() -> void:
	var s: GeoShape = _items[0]
	var users: Array = ed.level.objects.filter(func(o): return ed.links_of(o).any(func(l): return l["to"] == s.uid))
	if users.is_empty():
		ed.say("На путь %s никто не ссылается" % s.uid)
		return
	ed.set_selection(users)


func _simplify() -> void:
	var cmds: Array = []
	for s in _items:
		var b := Commands.snap(s, ["points"])
		var res := Geometry.simplify(s.points, ed.ep.simplify_tolerance, s.is_closed())
		if res.size() >= s.min_points() and res.size() < s.points.size():
			s.points = res
			cmds.append(Commands.props_from(s, b, "Упростить"))
	cmds = cmds.filter(func(c): return c != null)
	if cmds.is_empty():
		ed.say("Упрощать нечего (допуск %.1f px)" % ed.ep.simplify_tolerance)
		return
	ed.push_done(Commands.Batch.new(cmds, "Упростить"))
	ed.say("Упрощено контуров: %d" % cmds.size())


func _toggle_closed() -> void:
	var s: GeoShape = _items[0]
	var b := Commands.snap(s, ["kind", "closed", "color"])
	var to_kind: int
	if s.is_closed():
		to_kind = GeoShape.Kind.WALL
	else:
		if s.points.size() < 3:
			ed.say("Чтобы замкнуть, нужно хотя бы 3 точки")
			return
		to_kind = GeoShape.Kind.BODY
	_apply_kind(s, to_kind)
	ed.push_done(Commands.props_from(s, b, "Разомкнуть / замкнуть"))
	_sig = "-"
	sync()


func _apply_kind(s: GeoShape, k: int) -> void:
	if s.color == ed.kind_color(s.kind):
		s.color = ed.kind_color(k)
	s.kind = k
	s.closed = GeoShape.kind_is_closed(k)


func _bind() -> void:
	var s: GeoShape = _items[0]
	var c := Geometry.bbox(ed.level.shape_world_points(s)).get_center()
	var o: PlacedObject = ed.art_at(c)
	if o == null:
		ed.say("Под центром контура нет арт-объекта")
		return
	ed.exec(ed.bind_cmd(s, o))
	ed.say("%s привязан к %s" % [s.uid, o.uid])
	_sig = "-"
	sync()


func _fit_bg() -> void:
	var cmds: Array = []
	for b in _items:
		var before := Commands.snap(b, ["scale", "position"])
		var full: Vector2 = ed.bg_size(b) / b.scale
		var k: float = ed.level.bounds.size.y / maxf(full.y, 1.0)
		b.scale = Vector2(k, k)
		b.position.y = ed.level.bounds.position.y
		cmds.append(Commands.props_from(b, before, "По высоте границ"))
	cmds = cmds.filter(func(c): return c != null)
	if not cmds.is_empty():
		ed.push_done(Commands.Batch.new(cmds, "По высоте границ"))


func _revert_props() -> void:
	var cmds: Array = []
	for o in _items:
		var def: ObjectDef = ed.def_of(o)
		var keep := {}
		if o.props.has("image") and (def == null or def.image == ""):
			keep["image"] = o.props["image"]   # у картинки из файла картинка — это и есть объект
		for k in o.props:
			if String(k).begins_with("_"):
				keep[k] = o.props[k]   # служебное: из какого набора объект
		if keep.size() != o.props.size():
			cmds.append(Commands.PropsCmd.new(o, {"props": o.props.duplicate(true)}, {"props": keep}, "Вернуть к каталогу"))
	if not cmds.is_empty():
		ed.exec(Commands.Batch.new(cmds, "Вернуть к каталогу"))


# ------------------------------------------------------------ данные ↔ прокси

func _load_all() -> void:
	for e in _entries:
		if e.has("kind"):
			_load_proxy(e)


func _refresh_values() -> void:
	if panel == null:
		return
	_load_all()
	panel.refresh_all()
	_highlight_overrides()


func _load_proxy(e: Dictionary) -> void:
	var p: Resource = e["res"]
	match e["kind"]:
		"level":
			var lv: LevelData = ed.level
			p.id = lv.id
			p.title = lv.title
			p.epoch = maxi(LevelData.EPOCHS.find(lv.epoch), 0)
			p.kill_y = lv.kill_y
			p.bg_color = lv.bg_color
			p.bounds_x = lv.bounds.position.x
			p.bounds_y = lv.bounds.position.y
			p.bounds_w = lv.bounds.size.x
			p.bounds_h = lv.bounds.size.y
			p.darkness_enabled = lv.darkness_enabled
			p.darkness_color = lv.darkness_color
			p.brush_preset = lv.brush_preset
		"shape":
			var s: GeoShape = _items[0]
			p.kind = s.kind
			p.material = s.material
			p.thickness = s.thickness
			p.one_way = s.one_way
			p.solid_angle_deg = s.solid_angle_deg
			p.visible_in_game = s.visible_in_game
			p.color = s.color
			p.pos_x = s.position.x
			p.pos_y = s.position.y
		"bg":
			var b: BackgroundLayer = _items[0]
			p.pos_x = b.position.x
			p.pos_y = b.position.y
			p.scale_x = b.scale.x
			p.scale_y = b.scale.y
			p.parallax_x = b.parallax.x
			p.parallax_y = b.parallax.y
			p.region_x = b.region.position.x
			p.region_y = b.region.position.y
			p.region_w = b.region.size.x
			p.region_h = b.region.size.y
			p.modulate = b.modulate
			p.z = b.z
			p.locked = b.locked
		"role":
			var s: GeoShape = _items[0]
			p.pos_x = s.position.x
			p.pos_y = s.position.y
		"path":
			var s: GeoShape = _items[0]
			p.closed = s.closed
			p.pos_x = s.position.x
			p.pos_y = s.position.y
		"lit":
			var o: PlacedObject = _items[0]
			var def: ObjectDef = ed.def_of(o)
			var fresh := LitProps.new()
			for src in [def.default_props if def != null else {}, o.props]:
				for k in src:
					if String(k).begins_with("lit_") and k in fresh:
						fresh.set(k, PackedStringArray(src[k]) if fresh.get(k) is PackedStringArray else src[k])
			for pr in fresh.get_property_list():
				if pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
					p.set(pr["name"], fresh.get(pr["name"]))
		"pos", "xform":
			var o: PlacedObject = _items[0]
			p.pos_x = o.position.x
			p.pos_y = o.position.y
			if e["kind"] == "xform":
				p.scale_x = o.scale.x
				p.scale_y = o.scale.y
				p.rotation_deg = o.rotation_deg
				p.flip_h = o.flip_h
		"props":
			var o: PlacedObject = _items[0]
			var fresh: Resource = Catalog.make_props(ed.def_of(o), o)
			if fresh != null:
				for pr in fresh.get_property_list():
					if pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
						p.set(pr["name"], fresh.get(pr["name"]))


func _highlight_overrides() -> void:
	if panel == null:
		return
	for e in _entries:
		if not (e.get("kind", "") in ["props", "lit"]) or not e.has("controls"):
			continue
		var o: PlacedObject = _items[0]
		for pname in e["controls"]:
			var c: Dictionary = e["controls"][pname]
			if c.has("label"):
				var overridden := o.props.has(pname)
				(c["label"] as Label).add_theme_color_override("font_color", OVERRIDE_COLOR if overridden else Color(1, 1, 1, 0.9))


func _on_change(e: Dictionary, pname: String, value: Variant) -> void:
	var kind: String = e["kind"]
	var cmds: Array = []
	match kind:
		"level":
			cmds.append(_level_cmd(pname, value))
		"shape":
			for s in _items:
				var c = _shape_cmd(s, pname, value)
				if c != null:
					cmds.append(c)
		"bg":
			for b in _items:
				cmds.append(_bg_cmd(b, pname, value))
		"pos", "xform":
			for o in _items:
				cmds.append(_xform_cmd(o, pname, value))
		"props", "lit":
			for o in _items:
				var before: Dictionary = o.props.duplicate(true)
				var after: Dictionary = o.props.duplicate(true)
				after[pname] = Commands.Cmd.copy_value(value)
				cmds.append(Commands.PropsCmd.new(o, {"props": before}, {"props": after}, "Свойство"))
			if pname == "result" or pname == "lit_enabled":
				_sig = "-"
		"role":
			var s: GeoShape = _items[0]
			var np := Vector2(value, s.position.y) if pname == "pos_x" else Vector2(s.position.x, value)
			cmds.append(Commands.PropsCmd.new(s, {"position": s.position}, {"position": np}, "Сдвиг формы"))
		"path":
			var s: GeoShape = _items[0]
			if pname == "closed":
				if value and s.points.size() < 3:
					ed.say("Чтобы замкнуть путь, нужно хотя бы 3 точки")
				else:
					cmds.append(Commands.PropsCmd.new(s, {"closed": s.closed}, {"closed": value}, "Путь: замкнутый"))
			else:
				var np := Vector2(value, s.position.y) if pname == "pos_x" else Vector2(s.position.x, value)
				cmds.append(Commands.PropsCmd.new(s, {"position": s.position}, {"position": np}, "Сдвиг пути"))
	cmds = cmds.filter(func(c): return c != null)
	if cmds.is_empty():
		_refresh_values()
		return
	var bt := Commands.Batch.new(cmds, "Инспектор: " + pname)
	bt.merge_key = "insp:%s:%s:%s" % [kind, pname, _sig]
	ed.exec(bt)
	if kind == "level" and (pname == "epoch" or pname == "id"):
		ed.palette.rebuild()
		ed._update_title()


## Batch склеивается целиком: последняя версия заменяет «после», «до» остаётся первым.
func _level_cmd(pname: String, v: Variant) -> Commands.PropsCmd:
	var lv: LevelData = ed.level
	var field := pname
	var val: Variant = v
	match pname:
		"id":
			if not ed.valid_id(str(v)):
				ed.say("id: только латиница в нижнем регистре, цифры и «_»")
				return null
		"epoch":
			field = "epoch"
			val = LevelData.EPOCHS[clampi(int(v), 0, LevelData.EPOCHS.size() - 1)]
		"bounds_x", "bounds_y", "bounds_w", "bounds_h":
			field = "bounds"
			var b := lv.bounds
			match pname:
				"bounds_x": b.position.x = v
				"bounds_y": b.position.y = v
				"bounds_w": b.size.x = maxf(v, 1.0)
				"bounds_h": b.size.y = maxf(v, 1.0)
			val = b
	if lv.get(field) == val:
		return null
	return Commands.PropsCmd.new(lv, {field: lv.get(field)}, {field: val}, "Уровень")


func _shape_cmd(s: GeoShape, pname: String, v: Variant) -> Commands.PropsCmd:
	var before := Commands.snap(s, ["kind", "closed", "color", "material", "thickness", "one_way", "solid_angle_deg", "visible_in_game", "position"])
	match pname:
		"kind":
			var k := int(v)
			if k == s.kind:
				return null
			if k == GeoShape.Kind.RECT and s.kind != GeoShape.Kind.RECT:
				ed.say("Блок рисуется инструментом B — другой контур в блок не превращается")
				return null
			if GeoShape.kind_is_closed(k) and s.points.size() < 3:
				ed.say("Для замкнутого контура нужно хотя бы 3 точки")
				return null
			var after := before.duplicate()
			after["kind"] = k
			after["closed"] = GeoShape.kind_is_closed(k)
			if s.color == ed.kind_color(s.kind):
				after["color"] = ed.kind_color(k)
			_sig = "-"   # заголовок и кнопки зависят от вида — перестроить
			return Commands.PropsCmd.new(s, before, after, "Вид контура")
		"material":
			return Commands.PropsCmd.new(s, {"material": s.material}, {"material": int(v)})
		"pos_x":
			return Commands.PropsCmd.new(s, {"position": s.position}, {"position": Vector2(v, s.position.y)})
		"pos_y":
			return Commands.PropsCmd.new(s, {"position": s.position}, {"position": Vector2(s.position.x, v)})
	return Commands.PropsCmd.new(s, {pname: s.get(pname)}, {pname: v})


func _bg_cmd(b: BackgroundLayer, pname: String, v: Variant) -> Commands.PropsCmd:
	match pname:
		"pos_x": return Commands.PropsCmd.new(b, {"position": b.position}, {"position": Vector2(v, b.position.y)})
		"pos_y": return Commands.PropsCmd.new(b, {"position": b.position}, {"position": Vector2(b.position.x, v)})
		"scale_x": return Commands.PropsCmd.new(b, {"scale": b.scale}, {"scale": Vector2(maxf(v, 0.001), b.scale.y)})
		"scale_y": return Commands.PropsCmd.new(b, {"scale": b.scale}, {"scale": Vector2(b.scale.x, maxf(v, 0.001))})
		"parallax_x": return Commands.PropsCmd.new(b, {"parallax": b.parallax}, {"parallax": Vector2(v, b.parallax.y)})
		"parallax_y": return Commands.PropsCmd.new(b, {"parallax": b.parallax}, {"parallax": Vector2(b.parallax.x, v)})
		"region_x", "region_y", "region_w", "region_h":
			var r := b.region
			match pname:
				"region_x": r.position.x = v
				"region_y": r.position.y = v
				"region_w": r.size.x = maxf(v, 0.0)
				"region_h": r.size.y = maxf(v, 0.0)
			return Commands.PropsCmd.new(b, {"region": b.region}, {"region": r})
	return Commands.PropsCmd.new(b, {pname: b.get(pname)}, {pname: v})


func _xform_cmd(o: PlacedObject, pname: String, v: Variant) -> Commands.PropsCmd:
	match pname:
		"pos_x": return Commands.PropsCmd.new(o, {"position": o.position}, {"position": Vector2(v, o.position.y)})
		"pos_y": return Commands.PropsCmd.new(o, {"position": o.position}, {"position": Vector2(o.position.x, v)})
		"scale_x": return Commands.PropsCmd.new(o, {"scale": o.scale}, {"scale": Vector2(maxf(v, 0.001), o.scale.y)})
		"scale_y": return Commands.PropsCmd.new(o, {"scale": o.scale}, {"scale": Vector2(o.scale.x, maxf(v, 0.001))})
	return Commands.PropsCmd.new(o, {pname: o.get(pname)}, {pname: v})


# ------------------------------------------------------------ свои поля: связи и выбор из списка

## Поля, которые стандартная панель не умеет: списки uid (цели связей) и ссылки из PICKS
## (путь / объект — пипеткой на холсте, объект каталога, картинка, пресет кисти, карточка).
func _custom_field(box: VBoxContainer, e: Dictionary, pr: Dictionary, label_text: String, _unit: String, hint_text: String) -> bool:
	var pname: String = pr["name"]
	var res: Resource = e["res"]
	var picks: Dictionary = res.get_script().get_script_constant_map().get("PICKS", {})
	if pr["type"] == TYPE_PACKED_STRING_ARRAY:
		_targets_field(box, e, pname, label_text, hint_text)
		return true
	if pr["type"] == TYPE_STRING and picks.has(pname):
		_pick_field(box, e, pname, label_text, hint_text, picks[pname])
		return true
	return false


func _field_label(text: String, hint_text: String) -> Label:
	var l := Label.new()
	l.text = text + ("  ⓘ" if hint_text != "" else "")
	l.tooltip_text = hint_text
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	return l


func _small_btn(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Можно ли объект r сделать целью связи (у него есть активация).
func _activatable(r: Resource) -> bool:
	if not (r is PlacedObject):
		return false
	var d: ObjectDef = ed.def_of(r)
	return d != null and d.has_tag("activatable")


func _targets_field(box: VBoxContainer, e: Dictionary, pname: String, label_text: String, hint_text: String) -> void:
	var head := HBoxContainer.new()
	var l := _field_label(label_text, hint_text)
	head.add_child(l)
	var src: Resource = _items[0] if _items.size() == 1 else null
	var add_uid := func(u: String) -> void:
		var cur: PackedStringArray = PackedStringArray(e["res"].get(pname))
		if cur.has(u):
			ed.say("%s уже в списке" % u)
			return
		if src != null and u == src.uid and pname == "targets":
			ed.say("Объект не может быть целью самого себя")
			return
		cur.append(u)
		panel._set_value(e, pname, cur)
	head.add_child(_small_btn("⌖ Выбрать на холсте", "Клик по объекту на холсте добавит его в цели (Shift — несколько). Подходят объекты, которые умеют включаться: двери, выходы, платформы, свет, контуры…", func() -> void:
		ed.begin_pick(_activatable, add_uid, "цель связи (дверь, выход, платформа, свет…)", src, false)))
	box.add_child(head)
	var chips := HFlowContainer.new()
	box.add_child(chips)
	var row := HBoxContainer.new()
	var le := LineEdit.new()
	le.placeholder_text = "uid + Enter"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t: String) -> void:
		var u := t.strip_edges()
		le.text = ""
		le.release_focus.call_deferred()
		if u != "":
			add_uid.call(u))
	row.add_child(le)
	box.add_child(row)
	var refresh := func(v: Variant) -> void:
		for ch in chips.get_children():
			ch.queue_free()
		var arr := PackedStringArray(v) if v != null else PackedStringArray()
		if arr.is_empty():
			var none := Label.new()
			none.text = "— нет целей —"
			none.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
			chips.add_child(none)
		for u in arr:
			var ok: bool = ed.level.find_any(u) != null
			var b := Button.new()
			b.text = u + "  ×"
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "Убрать из целей" if ok else "Такого объекта нет на уровне — убрать"
			if not ok:
				b.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
			b.pressed.connect(func() -> void:
				var cur := PackedStringArray(e["res"].get(pname))
				var i := cur.find(u)
				if i >= 0:
					cur.remove_at(i)
					panel._set_value(e, pname, cur))
			b.mouse_entered.connect(func() -> void: ed.canvas.invalidate())
			chips.add_child(b)
	e["controls"][pname] = {"kind": "custom", "refresh": refresh, "label": l}


func _pick_field(box: VBoxContainer, e: Dictionary, pname: String, label_text: String, hint_text: String, kind: String) -> void:
	var head := HBoxContainer.new()
	var l := _field_label(label_text, hint_text)
	head.add_child(l)
	box.add_child(head)
	var src: Resource = _items[0] if _items.size() == 1 else null
	var setv := func(v: String) -> void: panel._set_value(e, pname, v)
	var refresh: Callable
	match kind:
		"path", "object":
			var le := LineEdit.new()
			le.custom_minimum_size = Vector2(110, 0)
			le.placeholder_text = "uid"
			le.text_submitted.connect(func(t: String) -> void:
				setv.call(t.strip_edges())
				le.release_focus.call_deferred())
			head.add_child(le)
			var accept := (func(r: Resource) -> bool: return r is GeoShape and r.kind == GeoShape.Kind.PATH) if kind == "path" else (func(r: Resource) -> bool: return r is PlacedObject and r != src)
			head.add_child(_small_btn("⌖", "Выбрать на холсте", func() -> void:
				ed.begin_pick(accept, setv, "путь" if kind == "path" else "объект", src)))
			head.add_child(_small_btn("×", "Очистить", func() -> void: setv.call("")))
			refresh = func(v: Variant) -> void:
				if not le.has_focus():
					le.text = str(v)
				var bad: bool = str(v) != "" and ed.level.find_any(str(v)) == null
				le.add_theme_color_override("font_color", Color(1, 0.45, 0.45) if bad else Color(1, 1, 1))
		"image":
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = true
			b.custom_minimum_size = Vector2(130, 0)
			b.pressed.connect(func() -> void:
				var path: String = await ed.pick_image()
				if path != "":
					setv.call(path))
			head.add_child(b)
			head.add_child(_small_btn("×", "Без картинки", func() -> void: setv.call("")))
			refresh = func(v: Variant) -> void:
				b.text = str(v).get_file() if str(v) != "" else "выбрать…"
				b.tooltip_text = str(v)
		_:
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			ob.custom_minimum_size = Vector2(150, 0)
			ob.fit_to_longest_item = false
			var values: Array = [""]
			var titles: Array = ["—"]
			match kind:
				"def":
					var defs: Array = Catalog.all().values().filter(func(d): return not d.hidden and d.kit.is_empty() and d.scene != null)
					defs.sort_custom(func(a, b2): return a.title < b2.title)
					for d in defs:
						values.append(d.id)
						titles.append("%s (%s)" % [d.title, d.id])
				"brush":
					titles[0] = "— кисть уровня —"
					for f in LevelFiles.resources_in("res://data/presets/brush"):
						values.append(f)
						titles.append(f.get_file().get_basename())
				"card":
					for id in CardsDB.ids():
						values.append(id)
						titles.append("%s — %s" % [id, CardsDB.get_card(id).get("title", "")])
			for t in titles:
				ob.add_item(t)
			ob.item_selected.connect(func(i: int) -> void: setv.call(values[i]))
			head.add_child(ob)
			refresh = func(v: Variant) -> void:
				var i := values.find(str(v))
				if i < 0 and str(v) != "":
					values.append(str(v))
					ob.add_item(str(v) + " (нет в списке)")
					i = values.size() - 1
				ob.select(maxi(i, 0))
	e["controls"][pname] = {"kind": "custom", "refresh": refresh, "label": l}
