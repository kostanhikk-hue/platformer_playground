extends Node2D
## Конструктор уровней (v1). Корень сцены editor/level_editor.tscn.
## Здесь: состояние (уровень, выделение, слои, привязки), интерфейс, файлы, «Играть отсюда», буфер обмена.
## Рисование холста — editor_canvas.gd, инструменты — editor/tools/*.gd, инспектор — inspector.gd,
## палитра — palette.gd, отмена — commands.gd, проверка — validator.gd.
## Подробно — заметка «Конструктор — техника» в папке «Технология».

const Commands := preload("res://editor/commands.gd")
const EdInput := preload("res://editor/editor_input.gd")
const Validator := preload("res://editor/validator.gd")
const Autotrace := preload("res://editor/autotrace.gd")
const CanvasScript := preload("res://editor/editor_canvas.gd")
const InspectorScript := preload("res://editor/inspector.gd")
const PaletteScript := preload("res://editor/palette.gd")
const SelectTool := preload("res://editor/tools/select_tool.gd")
const ShapeTool := preload("res://editor/tools/shape_tool.gd")
const RectTool := preload("res://editor/tools/rect_tool.gd")
const PlaceTool := preload("res://editor/tools/place_tool.gd")
const PickTool := preload("res://editor/tools/pick_tool.gd")
const ZoneTool := preload("res://editor/tools/zone_tool.gd")
const ObjectDraw := preload("res://editor/object_draw.gd")
const Geometry := preload("res://core/geometry.gd")
const Catalog := preload("res://game/level/catalog.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const LevelFiles := preload("res://game/level/level_files.gd")
const LevelRuntime := preload("res://game/level/level_runtime.gd")
const BgParallax := preload("res://game/level/parallax_layer.gd")

const DEV_MENU := "res://editor/launcher.tscn"
const AUTOSAVE_DIR := "res://content/levels/_autosave"
const ART_DEF := "art"
const START_DEF := "start"
const T := 32.0
const UI_FONT_SIZE := 13   ## шрифт интерфейса конструктора (не влияет на игру)
const CHECK_TINT := Color(2.2, 2.2, 2.2)   ## пустые галочки темы почти не видны на тёмной панели

## Буфер обмена живёт между уровнями (вставка в другой уровень).
static var clipboard: Array = []
static var clipboard_center := Vector2.ZERO
## Последний открытый уровень — при следующем входе в конструктор откроется он.
static var last_path := ""

var level: LevelData
var level_path := ""
var dirty := false
var ep: Resource
var undo := Commands.UndoStack.new()

var selection: Array = []
var sel_points: Array = []          ## индексы выделенных точек единственного выделенного контура
var layers: Array = []               ## [{visible, locked, alpha}] × 6
var show_collision := true
var show_grid := true
var grid_snap := false
var magnet := true
var player_view := false
## Линии связей на холсте всегда (T), иначе — только у выделенного источника.
var show_links := false
## Инспектор поверх игры во время «Играть отсюда» (F2).
var play_inspector := true
var _play_mark := 0
var _play_last = null
var _darkness: CanvasModulate

var cam: Camera2D
var world: Node2D
var sprites_root: Node2D
var canvas: Node2D
var bg_color_layer: CanvasLayer
var bg_color_rect: ColorRect
var tool
var tools := {}
var tool_name := "select"

var ui: CanvasLayer
var ui_root: Control
var catcher: Control
var inspector
var palette
var status_label: Label
var problems_list: ItemList
var bg_list: ItemList
var tool_buttons := {}
var toggle_buttons := {}
var layer_rows: Array = []
var _problems: Array = []
var _sprites := {}
var _last_mouse_world := Vector2.ZERO
var _panning := false
var _pan_from := Vector2.ZERO
var _cam_from := Vector2.ZERO
var _autosave_t := 0.0
var _dialog_open := false
var _hint := ""
var _message := ""
var _message_t := 0.0

var runtime: Node = null
var _top_bar: Control
var _bottom: Control
var _status_bar: Control


# ============================================================ запуск

func _ready() -> void:
	EdInput.register()
	ep = Params.get_res("editor")
	undo.depth = ep.undo_depth
	undo.merge_time = ep.undo_merge_time
	undo.on_change = _on_undo_change
	magnet = ep.magnet_default
	for i in range(LevelData.LAYER_TITLES.size()):
		layers.append({"visible": true, "locked": false, "alpha": 1.0})
	Catalog.reload()
	get_tree().set_auto_accept_quit(false)

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	sprites_root = Node2D.new()
	world.add_child(sprites_root)
	canvas = CanvasScript.new()
	canvas.ed = self
	canvas.z_index = 4000
	canvas.z_as_relative = false
	world.add_child(canvas)
	cam = Camera2D.new()
	world.add_child(cam)
	cam.make_current()
	# цвет за всеми фонами — как в игре
	bg_color_layer = CanvasLayer.new()
	bg_color_layer.layer = -100
	bg_color_rect = ColorRect.new()
	bg_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_color_layer.add_child(bg_color_rect)
	world.add_child(bg_color_layer)

	tools = {
		"select": SelectTool.new(self),
		"body": ShapeTool.new(self, GeoShape.Kind.BODY),
		"platform": ShapeTool.new(self, GeoShape.Kind.PLATFORM),
		"wall": ShapeTool.new(self, GeoShape.Kind.WALL),
		"kill": ShapeTool.new(self, GeoShape.Kind.KILL),
		"block": RectTool.new(self),
		"place": PlaceTool.new(self),
		"path": ShapeTool.new(self, GeoShape.Kind.PATH),
		"form": ShapeTool.new(self, GeoShape.Kind.BODY),
		"pick": PickTool.new(self),
		"zone": ZoneTool.new(self),
	}
	_build_ui()
	get_window().files_dropped.connect(_on_files_dropped)

	if last_path != "" and FileAccess.file_exists(last_path):
		await open_level(last_path)
	else:
		_set_level(_make_new_level("new_level", "Новый уровень", "common"), "")
	set_tool("select")


func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)
	get_window().title = ProjectSettings.get_setting("application/config/name", "Godot")
	if get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_requested()


func _quit_requested() -> void:
	if await _confirm_discard():
		get_tree().quit()


# ============================================================ уровень

func _make_new_level(id: String, title: String, epoch: String) -> LevelData:
	var lv := LevelData.new()
	lv.id = id
	lv.title = title
	lv.epoch = epoch
	lv.bounds = Rect2(0, 0, ep.new_level_w * T, ep.new_level_h * T)
	lv.kill_y = lv.bounds.end.y + ep.new_kill_margin
	return lv


func _set_level(lv: LevelData, path: String) -> void:
	level = lv
	level_path = path
	if path != "":
		last_path = path
	undo.clear()
	selection.clear()
	sel_points.clear()
	_problems.clear()
	_restore_editor_state()
	for k in _sprites.keys():
		_sprites[k]["node"].queue_free()
	_sprites.clear()
	dirty = false
	if tool != null:
		tool.deactivate()
		tool.activate()
	_full_refresh()
	_refresh_problems()
	if palette != null:
		palette.rebuild()


func _restore_editor_state() -> void:
	var st: Dictionary = level.editor_state
	cam.position = st.get("cam", level.bounds.get_center())
	var z: float = st.get("zoom", 0.0)
	if z <= 0.0:
		_fit_rect(level.bounds)
	else:
		cam.zoom = Vector2.ONE * z
	var ls: Array = st.get("layers", [])
	for i in range(mini(ls.size(), layers.size())):
		layers[i] = (ls[i] as Dictionary).duplicate()
	show_collision = st.get("show_collision", true)
	grid_snap = st.get("grid_snap", false)
	magnet = st.get("magnet", ep.magnet_default)
	show_grid = st.get("show_grid", true)
	show_links = st.get("show_links", false)


func _store_editor_state() -> void:
	level.editor_state = {
		"cam": cam.position, "zoom": cam.zoom.x, "layers": layers.duplicate(true),
		"show_collision": show_collision, "grid_snap": grid_snap, "magnet": magnet, "show_grid": show_grid,
		"show_links": show_links,
	}


## Глубокая копия уровня (для автосохранения — сам уровень не трогаем).
func clone_level(src: LevelData) -> LevelData:
	var c: LevelData = src.duplicate(false)
	var bgs: Array[BackgroundLayer] = []
	for b in src.backgrounds:
		bgs.append(b.duplicate())
	var shs: Array[GeoShape] = []
	for s in src.shapes:
		shs.append(s.duplicate())
	var objs: Array[PlacedObject] = []
	for o in src.objects:
		var d: PlacedObject = o.duplicate()
		d.props = o.props.duplicate(true)
		objs.append(d)
	c.backgrounds = bgs
	c.shapes = shs
	c.objects = objs
	c.editor_state = src.editor_state.duplicate(true)
	return c


func level_file_path() -> String:
	return LevelData.path_for(level.epoch, level.id)


func autosave_path() -> String:
	return AUTOSAVE_DIR.path_join(level.id + ".tres")


# ============================================================ файлы

func new_level_dialog() -> void:
	if not await _confirm_discard():
		return
	var r := await form("Новый уровень", level_form_fields("new_level", "Новый уровень", "common"))
	if r.is_empty():
		return
	var lv := _make_new_level(r["id"], r["title"], r["epoch"])
	_set_level(lv, "")
	dirty = true
	_update_title()
	say("Новый уровень %s (%s). Сохраните — Ctrl+S." % [lv.id, lv.epoch])


func open_dialog() -> void:
	if not await _confirm_discard():
		return
	var path := await pick_level()
	if path != "":
		await open_level(path)


func open_level(path: String) -> void:
	var lv := LevelData.load_level(path)
	if lv == null:
		say("Не удалось открыть %s" % path)
		return
	var dirty_after := false
	var auto := AUTOSAVE_DIR.path_join(lv.id + ".tres")
	if FileAccess.file_exists(auto):
		var t_auto := FileAccess.get_modified_time(ProjectSettings.globalize_path(auto))
		var t_file := FileAccess.get_modified_time(ProjectSettings.globalize_path(path))
		if t_auto > t_file:
			var c := await ask("Черновик", "Есть автосохранение уровня «%s» новее файла. Восстановить черновик?" % lv.id, ["Восстановить", "Открыть файл"])
			if c == 0:
				var a := LevelData.load_level(auto)
				if a != null:
					lv = a
					dirty_after = true
	_set_level(lv, path)
	dirty = dirty_after
	_update_title()
	say("Открыт: " + path)


func level_form_fields(id: String, title: String, epoch: String) -> Array:
	return [
		{"name": "id", "label": "id (латиница, цифры, _)", "value": id},
		{"name": "title", "label": "Название", "value": title},
		{"name": "epoch", "label": "Эпоха", "options": LevelData.EPOCH_TITLES, "values": LevelData.EPOCHS, "value": epoch},
	]


static func valid_id(s: String) -> bool:
	var rx := RegEx.create_from_string("^[a-z0-9_]+$")
	return s != "" and rx.search(s) != null


func save_level(as_new: bool = false) -> bool:
	if as_new:
		var r := await form("Сохранить как", level_form_fields(level.id, level.title, level.epoch))
		if r.is_empty():
			return false
		var target := LevelData.path_for(r["epoch"], r["id"])
		if target != level_path and FileAccess.file_exists(target):
			if await ask("Файл есть", "Уровень %s уже есть. Перезаписать?" % target, ["Перезаписать", "Отмена"]) != 0:
				return false
		level.id = r["id"]
		level.title = r["title"]
		level.epoch = r["epoch"]
	var path := level_file_path()
	_store_editor_state()
	_refresh_problems()
	var errs := PackedStringArray()
	for p in _problems:
		if p["error"]:
			errs.append(p["text"])
	level.known_errors = errs
	level.format_version = LevelData.FORMAT_VERSION
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(level, path)
	if err != OK:
		say("Не удалось сохранить (код %d). Запускайте проект из редактора Godot." % err)
		return false
	level_path = path
	last_path = path
	dirty = false
	_update_title()
	say("Сохранено: %s%s" % [path, ("   · ошибок: %d (см. список внизу)" % errs.size()) if not errs.is_empty() else ""])
	return true


func _autosave() -> void:
	if not dirty or runtime != null:
		return
	_store_editor_state()
	DirAccess.make_dir_recursive_absolute(AUTOSAVE_DIR)
	var err := ResourceSaver.save(clone_level(level), autosave_path())
	if err == OK:
		say("Автосохранение: " + autosave_path())


## true — можно продолжать (сохранено, или не жалко, или нечего терять).
func _confirm_discard() -> bool:
	if not dirty:
		return true
	var c := await ask("Несохранённые изменения", "В уровне «%s» есть несохранённые изменения." % level.id, ["Сохранить", "Не сохранять", "Отмена"])
	if c == 0:
		return await save_level(level_path == "")
	return c == 1


func close_editor() -> void:
	if await _confirm_discard():
		get_tree().change_scene_to_file(DEV_MENU)


func mark_dirty() -> void:
	if not dirty:
		dirty = true
		_update_title()


func _update_title() -> void:
	get_window().title = "Конструктор — %s (%s)%s" % [level.id, level.epoch, " *" if dirty else ""]


# ============================================================ изменения и обновление

func exec(c) -> void:
	if c != null:
		undo.exec(c)


func push_done(c) -> void:
	if c != null:
		undo.push_done(c)


func _on_undo_change() -> void:
	mark_dirty()
	_prune_selection()
	_full_refresh()
	# «Играть отсюда»: правка свойств в инспекторе применяется сразу
	if runtime != null and is_instance_valid(runtime):
		for r in selection:
			if r is PlacedObject:
				runtime.apply_object_props(r)


## Полное обновление после изменения данных: картинки, холст, инспектор (значения).
func _full_refresh() -> void:
	refresh_view()
	if inspector != null:
		inspector.sync()
	_refresh_bg_list()


## Лёгкое обновление (во время перетаскивания): только картинки и холст.
func refresh_view() -> void:
	_sync_sprites()
	canvas.invalidate()


func _prune_selection() -> void:
	var keep: Array = []
	for r in selection:
		if _in_level(r):
			keep.append(r)
	if keep.size() != selection.size():
		selection = keep
		sel_points.clear()
	if selection.size() == 1 and selection[0] is GeoShape:
		var n: int = selection[0].points.size()
		sel_points = sel_points.filter(func(i): return i < n)


func _in_level(r: Resource) -> bool:
	if r is GeoShape:
		return level.shapes.has(r)
	if r is PlacedObject:
		return level.objects.has(r)
	if r is BackgroundLayer:
		return level.backgrounds.has(r)
	return false


func set_selection(arr: Array) -> void:
	var same := arr.size() == selection.size()
	if same:
		for i in range(arr.size()):
			if arr[i] != selection[i]:
				same = false
				break
	selection = arr.duplicate()
	if not same:
		sel_points.clear()
	if inspector != null:
		inspector.sync()
	canvas.invalidate()


# ============================================================ картинки на холсте

func _sync_sprites() -> void:
	bg_color_rect.color = level.bg_color
	bg_color_layer.visible = world.visible
	# темнота уровня — видна в «Виде игрока» (F6)
	var dark := player_view and level.darkness_enabled
	if dark and _darkness == null:
		_darkness = CanvasModulate.new()
		world.add_child(_darkness)
	if _darkness != null:
		_darkness.visible = dark
		_darkness.color = level.darkness_color if dark else Color.WHITE
	var alive := {}
	for b in level.backgrounds:
		alive[b.uid] = true
		_sync_one(b.uid, b.path, b.region, false, b)
	for o in level.objects:
		var def := def_of(o)
		if def != null and def.transformable:
			var img := object_image(o)
			if img != "":
				alive[o.uid] = true
				_sync_one(o.uid, img, Rect2(), true, o)
	for k in _sprites.keys():
		if not alive.has(k):
			_sprites[k]["node"].queue_free()
			_sprites.erase(k)


func _sync_one(uid: String, path: String, region: Rect2, centered: bool, r: Resource) -> void:
	var key := "%s|%s" % [path, region]
	var e: Dictionary = _sprites.get(uid, {})
	if e.is_empty() or e["key"] != key or not is_instance_valid(e["node"]):
		if not e.is_empty() and is_instance_valid(e["node"]):
			e["node"].queue_free()
		var holder := BgParallax.new()
		var img := ArtLoader.make_node(path, region, centered)
		holder.add_child(img)
		sprites_root.add_child(holder)
		e = {"node": holder, "img": img, "key": key}
		_sprites[uid] = e
	var holder: Node2D = e["node"]
	var img_node: Node2D = e["img"]
	var li := item_layer(r)
	var lay: Dictionary = layers[li]
	holder.visible = lay["visible"] and not (player_view and li == LevelData.Layer.SERVICE)
	holder.modulate = Color(1, 1, 1, lay["alpha"])
	if r is BackgroundLayer:
		holder.base_position = r.position
		holder.position = r.position
		holder.parallax = r.parallax
		holder.reference = level.bounds.position
		holder.enabled = player_view
		holder.z_index = clampi(LevelData.LAYER_Z[li] + r.z, -4000, 3900)
		img_node.scale = r.scale
		img_node.modulate = r.modulate
	else:
		holder.enabled = false
		holder.base_position = r.position
		var xf := LevelData.object_xform(r)
		holder.transform = xf
		holder.z_index = LevelData.LAYER_Z[li]
		img_node.modulate = r.props.get("modulate", Color.WHITE)


# ============================================================ вид и привязки

func zoom() -> float:
	return cam.zoom.x


## Экранные пиксели → мировые (размер ручек, толщина линий, радиус магнита).
func px(screen_px: float) -> float:
	return screen_px / maxf(zoom(), 0.0001)


func mouse_world() -> Vector2:
	return world.get_global_mouse_position()


func view_rect() -> Rect2:
	var sz := get_viewport().get_visible_rect().size / zoom()
	return Rect2(cam.get_screen_center_position() - sz * 0.5, sz)


## Масштаб с неподвижной точкой: pivot_world остаётся под screen_pos (по умолчанию — под курсором).
func zoom_at(screen_factor: float, pivot_world: Vector2, screen_pos = null) -> void:
	var z := clampf(zoom() * screen_factor, ep.zoom_min, ep.zoom_max)
	var vp := get_viewport().get_visible_rect().size
	var sp: Vector2 = screen_pos if screen_pos != null else get_viewport().get_mouse_position()
	cam.zoom = Vector2.ONE * z
	cam.position = pivot_world - (sp - vp * 0.5) / z
	canvas.invalidate()


func _fit_rect(r: Rect2) -> void:
	if not r.has_area():
		r = r.grow(T * 4)
	var area := catcher.size if catcher != null and catcher.size.x > 10 else get_viewport().get_visible_rect().size
	var z := minf(area.x / (r.size.x * 1.1), area.y / (r.size.y * 1.1))
	cam.zoom = Vector2.ONE * clampf(z, ep.zoom_min, ep.zoom_max)
	cam.position = r.get_center()
	if catcher != null and catcher.size.x > 10:
		# центр области холста может не совпадать с центром окна (панели по бокам)
		var vp := get_viewport().get_visible_rect().size
		var c := catcher.get_global_rect().get_center()
		cam.position -= (c - vp * 0.5) / cam.zoom.x
	canvas.invalidate()


func focus_selection() -> void:
	if selection.is_empty():
		return
	var r := Rect2()
	var first := true
	for it in selection:
		var b := item_bbox(it)
		r = b if first else r.merge(b)
		first = false
	_fit_rect(r.grow(T * 2))


func grid_step() -> float:
	return T / float([1, 2, 4][clampi(ep.grid_snap_div, 0, 2)])


func snap_grid(p: Vector2) -> Vector2:
	var g := grid_step()
	return Vector2(roundf(p.x / g) * g, roundf(p.y / g) * g)


## Общая привязка для рисования и правки:
## Alt — без привязок; Shift при заданной prev — угол кратен angle_snap_deg;
## иначе магнит к точкам/рёбрам других контуров, иначе сетка (если включена).
func snap(p: Vector2, prev = null, exclude: GeoShape = null, exclude_index: int = -1) -> Vector2:
	if EdInput.alt():
		return p
	if prev != null and EdInput.shift():
		var d: Vector2 = p - prev
		var step := deg_to_rad(maxf(ep.angle_snap_deg, 1.0))
		var a := roundf(d.angle() / step) * step
		return prev + Vector2.from_angle(a) * d.length()
	if magnet:
		var m = magnet_point(p, exclude, exclude_index)
		if m != null:
			return m
	if grid_snap:
		return snap_grid(p)
	return p


## Ближайшая точка или ребро других контуров в радиусе snap_radius (экранные px). null — нет.
func magnet_point(p: Vector2, exclude: GeoShape = null, exclude_index: int = -1):
	var r := px(ep.snap_radius)
	var best_d := r
	var best = null
	if not show_collision:
		return null
	for s in level.shapes:
		var wp := level.shape_world_points(s)
		for i in range(wp.size()):
			if s == exclude and i == exclude_index:
				continue
			var d := wp[i].distance_to(p)
			if d < best_d:
				best_d = d
				best = wp[i]
	if best != null:
		return best
	best_d = r
	for s in level.shapes:
		if s == exclude:
			continue
		var wp := level.shape_world_points(s)
		var n := wp.size()
		var edges := n if s.is_closed() else n - 1
		for i in range(edges):
			var c := Geometry2D.get_closest_point_to_segment(p, wp[i], wp[(i + 1) % n])
			var d := c.distance_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


# ============================================================ объекты, слои, попадания

func def_of(o: PlacedObject) -> ObjectDef:
	return Catalog.get_def(o.def_id)


func is_art(r: Resource) -> bool:
	if not (r is PlacedObject):
		return false
	var d := def_of(r)
	return d != null and d.transformable


func object_image(o: PlacedObject) -> String:
	var d := def_of(o)
	return o.props.get("image", d.image if d != null else "")


## Размер объекта в его локальных координатах (без масштаба).
func object_local_size(o: PlacedObject) -> Vector2:
	var d := def_of(o)
	if d != null and d.transformable:
		var s := ArtLoader.image_size(object_image(o))
		if s != Vector2.ZERO:
			return s
	if d == null:
		return Vector2(T, T)
	if o.def_id == START_DEF:
		var m: Resource = Params.get_res("movement")
		return Vector2(m.body_width, m.body_height)
	match d.kind:
		"exit", "door", "atmosphere":
			return Vector2(prop(o, "width", d.editor_size.x), prop(o, "height", d.editor_size.y))
		"plate":
			return Vector2(prop(o, "width", 48.0), 12.0)
		"dummy":
			var dp: Resource = Params.get_res("dummy")
			return Vector2(dp.body_width, dp.body_height)
		"anim_decor":
			var s := ObjectDraw.decor_frame_size(self, o)
			if s != Vector2.ZERO:
				return s
	return d.editor_size


## Значение свойства экземпляра с учётом каталога (экземпляр → каталог → скрипт).
func prop(o: PlacedObject, pname: String, fallback: Variant = null) -> Variant:
	return Catalog.prop_value(def_of(o), o, pname, fallback)


## Прямоугольник объекта в мире: у объектов с формами — по формам, иначе — по размеру вокруг положения.
func object_rect(o: PlacedObject) -> Rect2:
	var roles := level.role_shapes(o.uid)
	if not roles.is_empty():
		var r := Rect2()
		var first := true
		for s in roles:
			var b := Geometry.bbox(level.shape_world_points(s))
			r = b if first else r.merge(b)
			first = false
		r = r.grow(px(6))
		return r.merge(Rect2(o.position - Vector2(8, 8), Vector2(16, 16)))
	var sz := object_local_size(o)
	return Rect2(o.position - sz * 0.5, sz)


func object_world_poly(o: PlacedObject) -> PackedVector2Array:
	if is_art(o):
		var h := object_local_size(o) * 0.5
		var local := PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
		return LevelData.object_xform(o) * local
	var r := object_rect(o)
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func item_center(r: Resource) -> Vector2:
	if r is PlacedObject:
		return r.position
	return item_bbox(r).get_center()


func bg_size(b: BackgroundLayer) -> Vector2:
	var full := ArtLoader.image_size(b.path)
	if b.region.has_area():
		full = b.region.size
	return full * b.scale


func bg_rect(b: BackgroundLayer) -> Rect2:
	return Rect2(b.position, bg_size(b)).abs()


func item_layer(r: Resource) -> int:
	if r is GeoShape:
		if r.kind == GeoShape.Kind.PATH:
			return LevelData.Layer.SERVICE
		if r.role != "":
			var parent := level.find_object(r.parent_uid)
			if parent != null:
				return clampi(parent.layer, 0, LevelData.LAYER_TITLES.size() - 1)
		return LevelData.Layer.GAMEPLAY
	if r is PlacedObject or r is BackgroundLayer:
		return clampi(r.layer, 0, LevelData.LAYER_TITLES.size() - 1)
	return LevelData.Layer.GAMEPLAY


func layer_visible(i: int) -> bool:
	return layers[i]["visible"] and not (player_view and i == LevelData.Layer.SERVICE)


func layer_editable(i: int) -> bool:
	return layer_visible(i) and not layers[i]["locked"]


func item_selectable(r: Resource) -> bool:
	if not layer_editable(item_layer(r)):
		return false
	if r is GeoShape and player_view:
		return false
	if r is GeoShape and r.role == "" and r.kind != GeoShape.Kind.PATH and not show_collision:
		return false
	if r is BackgroundLayer and r.locked:
		return false
	return true


func item_bbox(r: Resource) -> Rect2:
	if r is GeoShape:
		return Geometry.bbox(level.shape_world_points(r))
	if r is PlacedObject:
		return Geometry.bbox(object_world_poly(r))
	if r is BackgroundLayer:
		return bg_rect(r)
	return Rect2()


func item_hit(r: Resource, p: Vector2) -> bool:
	var tol := px(ep.handle_size)
	if r is GeoShape:
		var wp := level.shape_world_points(r)
		var n := wp.size()
		var closed: bool = r.is_closed()
		var edges := n if closed else n - 1
		for i in range(edges):
			if Geometry.dist_to_segment(p, wp[i], wp[(i + 1) % n]) <= maxf(tol, r.thickness * 0.5 if not closed else 0.0):
				return true
		return closed and n >= 3 and Geometry2D.is_point_in_polygon(p, wp)
	if r is PlacedObject:
		return Geometry2D.is_point_in_polygon(p, object_world_poly(r))
	if r is BackgroundLayer:
		return bg_rect(r).has_point(p)
	return false


## Всё, что под курсором, сверху вниз (служебное и передний план — первыми, фоны — последними).
## Формы объектов идут сразу после своего объекта (клик — объект, повторный клик или двойной — его форма).
func hit_items(p: Vector2, _for_pick: bool = false) -> Array:
	var out: Array = []
	var objs := level.objects.duplicate()
	objs.reverse()
	var shs := level.shapes.duplicate()
	shs.reverse()
	for layer_i in range(LevelData.LAYER_TITLES.size() - 1, -1, -1):
		for s in shs:
			if s.kind == GeoShape.Kind.PATH and item_layer(s) == layer_i and item_selectable(s) and item_hit(s, p):
				out.append(s)
		for o in objs:
			if item_layer(o) == layer_i and not is_art(o) and item_selectable(o) and item_hit(o, p):
				out.append(o)
				for s in shs:
					if s.parent_uid == o.uid and s.role != "" and item_selectable(s) and item_hit(s, p):
						out.append(s)
		if layer_i == LevelData.Layer.GAMEPLAY:
			for s in shs:
				if s.role == "" and s.kind != GeoShape.Kind.PATH and item_selectable(s) and item_hit(s, p):
					out.append(s)
		for o in objs:
			if item_layer(o) == layer_i and is_art(o) and item_selectable(o) and item_hit(o, p):
				out.append(o)
		var bgs := level.backgrounds.filter(func(b): return item_layer(b) == layer_i)
		bgs.sort_custom(func(a, b): return a.z > b.z)
		for b in bgs:
			if item_selectable(b) and item_hit(b, p):
				out.append(b)
	return out


func items_in_rect(r: Rect2) -> Array:
	var out: Array = []
	for arr in [level.objects, level.shapes, level.backgrounds]:
		for it in arr:
			if item_selectable(it) and r.intersects(item_bbox(it)):
				out.append(it)
	return out


## Верхний арт-объект, в рамке которого лежит точка.
func art_at(p: Vector2) -> PlacedObject:
	for it in hit_items(p):
		if is_art(it):
			return it
	return null


# ============================================================ действия с уровнем

func new_shape(kind: int, world_pts: PackedVector2Array, attach: PlacedObject = null) -> GeoShape:
	var s := GeoShape.new()
	s.kind = kind
	s.uid = level.next_uid("path" if kind == GeoShape.Kind.PATH else "shape")
	s.closed = GeoShape.kind_is_closed(kind)
	s.thickness = ep.default_thickness
	s.one_way = ep.default_one_way
	s.solid_angle_deg = ep.default_solid_angle
	s.color = kind_color(kind)
	s.visible_in_game = kind == GeoShape.Kind.RECT
	var pts := world_pts
	if attach != null:
		s.parent_uid = attach.uid
		pts = LevelData.object_xform(attach).affine_inverse() * world_pts
	s.position = pts[0]
	var local := PackedVector2Array()
	for p in pts:
		local.append(p - s.position)
	s.points = local
	return s


## Форма объекта (роль): точки в мире → контур, привязанный к объекту o.
func new_role_shape(o: PlacedObject, role: String, world_pts: PackedVector2Array, closed: bool) -> GeoShape:
	var s := new_shape(GeoShape.Kind.BODY if closed else GeoShape.Kind.WALL, world_pts, o)
	s.role = role
	var d := def_of(o)
	s.color = d.editor_color if d != null else Color(1, 0.85, 0.55)
	return s


func kind_color(kind: int) -> Color:
	match kind:
		GeoShape.Kind.PATH:
			return Color(0.55, 0.9, 1.0)
		GeoShape.Kind.PLATFORM:
			return ep.platform_color
		GeoShape.Kind.WALL:
			return ep.wall_color
		GeoShape.Kind.RECT:
			return ep.block_color
		GeoShape.Kind.KILL:
			return ep.kill_color
	return ep.body_color


func add_items(list_name: String, items: Array, name: String = "Добавить") -> void:
	exec(Commands.ListCmd.new(level, list_name, items, true, name))


func new_object(def: ObjectDef, pos: Vector2) -> Array:
	var o := PlacedObject.new()
	o.def_id = def.id
	o.uid = level.next_uid(def.uid_prefix if def.uid_prefix != "" else (def.id if def.id.is_valid_identifier() else "obj"))
	o.position = pos
	o.layer = def.default_layer
	var shapes: Array = []
	if def.image != "":
		o.props = {"image": def.image}
	for s in def.shapes:
		var c: GeoShape = s.duplicate()
		c.uid = ""
		c.parent_uid = o.uid
		shapes.append(c)
	return [o, shapes]


## Пол под точкой p (ближайшее сверху ребро твёрдого контура в пределах reach): y или NAN.
func floor_below(p: Vector2, reach: float) -> float:
	var best := NAN
	var to := p + Vector2(0, reach)
	for s in level.shapes:
		if s.role != "" or s.kind == GeoShape.Kind.PATH or s.kind == GeoShape.Kind.KILL:
			continue
		var wp := level.shape_world_points(s)
		var n := wp.size()
		var edges := n if s.is_closed() else n - 1
		for i in range(edges):
			var hit = Geometry2D.segment_intersects_segment(p, to, wp[i], wp[(i + 1) % n])
			if hit != null and (is_nan(best) or hit.y < best):
				best = hit.y
	return best


## Точка постановки с учётом «ставить на пол» (Alt — без).
func place_point(def: ObjectDef, p: Vector2) -> Vector2:
	if def == null or not def.snap_to_floor or EdInput.alt():
		return p
	var y := floor_below(p - Vector2(0, T), T * 12.0)
	if is_nan(y):
		return p
	var h := def.editor_size.y
	if def.id == START_DEF:
		h = Params.get_res("movement").body_height
	elif def.kind == "door" or def.kind == "exit":
		h = float(Catalog.prop_value(def, null, "height", h))
	elif def.kind == "dummy":
		h = Params.get_res("dummy").body_height
	return Vector2(p.x, y - h * 0.5)


## Поставить объект каталога (из палитры). Старт героя — один на уровень: существующий переезжает.
## Готовый набор (kit) ставит несколько объектов со связями.
func place_object(def: ObjectDef, pos: Vector2) -> PlacedObject:
	if not def.kit.is_empty():
		var made := place_kit(def, pos)
		return made[0] if not made.is_empty() else null
	if def.unique:
		for o in level.objects:
			if o.def_id == def.id:
				var b := Commands.snap(o, ["position"])
				o.position = pos
				push_done(Commands.props_from(o, b, "Переставить " + def.title))
				set_selection([o])
				return o
	var made := new_object(def, pos)
	var o: PlacedObject = made[0]
	var cmds: Array = [Commands.ListCmd.new(level, "objects", [o], true)]
	var shs: Array = made[1]
	if not shs.is_empty():
		_assign_uids(shs, "shape")
		cmds.append(Commands.ListCmd.new(level, "shapes", shs, true))
	exec(Commands.Batch.new(cmds, "Поставить " + def.title))
	set_selection([o])
	return o


## Готовый набор: объекты набора со своими свойствами и формами, ссылки "@key" → uid объектов набора.
func place_kit(def: ObjectDef, pos: Vector2) -> Array:
	var objs: Array = []
	var shapes: Array = []
	var keys := {}
	var used := level.all_uids()
	for it in def.kit:
		var d := Catalog.get_def(it.get("def_id", ""))
		if d == null:
			say("Набор %s: нет «%s» в каталоге" % [def.id, it.get("def_id", "")])
			continue
		var made := new_object(d, pos + (it.get("offset", Vector2.ZERO) as Vector2))
		var o: PlacedObject = made[0]
		o.uid = _free_uid(d.id, used)
		used[o.uid] = true
		keys[it.get("key", o.uid)] = o.uid
		var props: Dictionary = (it.get("props", {}) as Dictionary).duplicate(true)
		props.merge(o.props, false)
		props["_kit"] = def.id
		props["_kit_key"] = it.get("key", "")
		o.props = props
		objs.append(o)
		var shs: Array = made[1]
		if it.has("shapes"):
			shs = []
			for sh in it["shapes"]:
				var g := GeoShape.new()
				g.role = sh["role"]
				g.closed = sh["closed"]
				g.kind = GeoShape.Kind.BODY if g.closed else GeoShape.Kind.WALL
				g.points = sh["points"]
				g.color = d.editor_color
				shs.append(g)
		for s in shs:
			s.parent_uid = o.uid
			s.uid = _free_uid("shape", used)
			used[s.uid] = true
			shapes.append(s)
	# ссылки внутри набора
	for o in objs:
		var p: Dictionary = o.props
		for k in p.keys():
			var v = p[k]
			if v is String and v.begins_with("@"):
				p[k] = keys.get(v.substr(1), v)
			elif v is Array or v is PackedStringArray:
				var arr: Array = []
				for x in v:
					arr.append(keys.get(String(x).substr(1), x) if String(x).begins_with("@") else x)
				p[k] = PackedStringArray(arr)
	var cmds: Array = [Commands.ListCmd.new(level, "objects", objs, true)]
	if not shapes.is_empty():
		cmds.append(Commands.ListCmd.new(level, "shapes", shapes, true))
	exec(Commands.Batch.new(cmds, "Поставить набор " + def.title))
	set_selection(objs)
	say("Набор «%s»: %s" % [def.title, ", ".join(objs.map(func(x): return x.uid))])
	return objs


func _assign_uids(items: Array, prefix: String) -> void:
	var tmp: Array = []
	for it in items:
		it.uid = level.next_uid(prefix)
		# временно добавляем, чтобы следующий uid не совпал
		if it is GeoShape:
			level.shapes.append(it)
		tmp.append(it)
	for it in tmp:
		if it is GeoShape:
			level.shapes.erase(it)


## Удалить выделенное. У арт-объекта с контурами — спросить, что делать с контурами.
func delete_selection() -> void:
	if selection.is_empty():
		return
	var objs: Array = selection.filter(func(r): return r is PlacedObject)
	var shs: Array = selection.filter(func(r): return r is GeoShape)
	var bgs: Array = selection.filter(func(r): return r is BackgroundLayer)
	var children: Array = []
	for o in objs:
		for s in level.shapes_of(o.uid):
			if s.role != "":
				if not shs.has(s):
					shs.append(s)   # формы объекта удаляются вместе с ним
			elif not shs.has(s):
				children.append(s)
	var cmds: Array = []
	if not children.is_empty():
		var c := await ask("Контуры объекта", "У удаляемых объектов есть привязанные контуры (%d)." % children.size(), ["Удалить контуры тоже", "Отвязать", "Отмена"])
		if c == 2 or c < 0:
			return
		if c == 0:
			shs.append_array(children)
		else:
			for s in children:
				cmds.append(unbind_cmd(s))
	if not shs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "shapes", shs, false))
	if not objs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "objects", objs, false))
	if not bgs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "backgrounds", bgs, false))
	selection.clear()
	sel_points.clear()
	exec(Commands.Batch.new(cmds, "Удалить"))
	set_selection([])


## Отвязать контур от арт-объекта: остаётся на месте в мировых координатах.
func unbind_cmd(s: GeoShape) -> Commands.PropsCmd:
	var b := Commands.snap(s, ["points", "position", "parent_uid"])
	var wp := level.shape_world_points(s)
	var after := {"parent_uid": "", "position": wp[0], "points": Transform2D(0.0, -wp[0]) * wp}
	return Commands.PropsCmd.new(s, b, after, "Отвязать")


## Привязать контур к арт-объекту: точки переводятся в координаты объекта, на экране ничего не двигается.
func bind_cmd(s: GeoShape, o: PlacedObject) -> Commands.PropsCmd:
	var b := Commands.snap(s, ["points", "position", "parent_uid"])
	var wp := level.shape_world_points(s)
	var local := LevelData.object_xform(o).affine_inverse() * wp
	var after := {"parent_uid": o.uid, "position": local[0], "points": Transform2D(0.0, -local[0]) * local}
	return Commands.PropsCmd.new(s, b, after, "Привязать")


## Скопировать выделенное (с привязанными контурами объектов).
func copy_selection() -> void:
	if selection.is_empty():
		return
	clipboard.clear()
	var with_children: Array = selection.duplicate()
	for r in selection:
		if r is PlacedObject:
			for s in level.shapes_of(r.uid):
				if not with_children.has(s):
					with_children.append(s)
	var r := Rect2()
	var first := true
	for it in with_children:
		var b := item_bbox(it)
		r = b if first else r.merge(b)
		first = false
		var c: Resource = it.duplicate()
		if c is PlacedObject:
			c.props = it.props.duplicate(true)
		# контур без родителя в копии — в мировых координатах
		if c is GeoShape and c.parent_uid != "" and not _has_uid(with_children, c.parent_uid):
			var wp := level.shape_world_points(it)
			c.parent_uid = ""
			c.position = wp[0]
			c.points = Transform2D(0.0, -wp[0]) * wp
		clipboard.append(c)
	clipboard_center = r.get_center()
	say("Скопировано: %d" % clipboard.size())


func _has_uid(items: Array, u: String) -> bool:
	for it in items:
		if it.uid == u:
			return true
	return false


## Вставить буфер так, чтобы его центр оказался в точке at.
func paste_at(at: Vector2) -> void:
	if clipboard.is_empty():
		return
	var delta := at - clipboard_center
	if grid_snap and not EdInput.alt():
		delta = snap_grid(delta)
	var made: Array = []
	var remap := {}
	for c in clipboard:
		var d: Resource = c.duplicate()
		if d is PlacedObject:
			d.props = c.props.duplicate(true)
		made.append(d)
	var used := level.all_uids()
	for d in made:
		var prefix: String = ("path" if d.kind == GeoShape.Kind.PATH else "shape") if d is GeoShape else ("bg" if d is BackgroundLayer else d.def_id)
		var nu := _free_uid(prefix, used)
		used[nu] = true
		remap[d.uid] = nu
		d.uid = nu
	var cmds: Array = []
	var objs: Array = []
	var shs: Array = []
	var bgs: Array = []
	for d in made:
		if d is GeoShape:
			if d.parent_uid != "" and remap.has(d.parent_uid):
				d.parent_uid = remap[d.parent_uid]
			else:
				d.parent_uid = ""
				d.position += delta
			shs.append(d)
		elif d is PlacedObject:
			if d.def_id == START_DEF and level.objects.any(func(o): return o.def_id == START_DEF):
				continue   # второй старт не вставляем
			d.position += delta
			objs.append(d)
		elif d is BackgroundLayer:
			d.position += delta
			bgs.append(d)
	if not bgs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "backgrounds", bgs, true))
	if not objs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "objects", objs, true))
	if not shs.is_empty():
		cmds.append(Commands.ListCmd.new(level, "shapes", shs, true))
	exec(Commands.Batch.new(cmds, "Вставить"))
	set_selection(objs + shs.filter(func(s): return s.parent_uid == "" or not remap.values().has(s.parent_uid)) + bgs)


func _free_uid(prefix: String, used: Dictionary) -> String:
	var n := 1
	while used.has("%s_%d" % [prefix, n]):
		n += 1
	return "%s_%d" % [prefix, n]


func duplicate_selection() -> void:
	var keep_clip := clipboard.duplicate()
	var keep_center := clipboard_center
	copy_selection()
	paste_at(clipboard_center + Vector2(ep.paste_offset, ep.paste_offset))
	clipboard = keep_clip
	clipboard_center = keep_center


## X / Y / R для выделенного: отражение по горизонтали, по вертикали, поворот.
func transform_selection(op: String) -> void:
	var cmds: Array = []
	for r in selection:
		if r is GeoShape:
			var b := Commands.snap(r, ["points"])
			var c := Geometry.bbox(r.points).get_center()
			var pts := PackedVector2Array()
			for p in r.points:
				var q: Vector2 = p - c
				match op:
					"flip_h":
						q.x = -q.x
					"flip_v":
						q.y = -q.y
					"rotate":
						q = q.rotated(deg_to_rad(ep.rotate_step))
				pts.append(q + c)
			r.points = pts
			cmds.append(Commands.props_from(r, b, "Отразить"))
		elif r is PlacedObject:
			var b := Commands.snap(r, ["flip_h", "rotation_deg", "props"])
			if is_art(r):
				match op:
					"flip_h":
						r.flip_h = not r.flip_h
					"flip_v":
						r.flip_h = not r.flip_h
						r.rotation_deg = wrapf(r.rotation_deg + 180.0, -180.0, 180.0)
					"rotate":
						r.rotation_deg = wrapf(r.rotation_deg + ep.rotate_step, -180.0, 180.0)
			elif r.def_id == "dummy" and op == "flip_h":
				var p: Dictionary = r.props.duplicate()
				p["facing"] = 1 - int(p.get("facing", 0))
				r.props = p
			elif not level.role_shapes(r.uid).is_empty():
				# формы объекта отражаются и поворачиваются вокруг его положения
				for s in level.role_shapes(r.uid):
					if selection.has(s):
						continue
					var sb := Commands.snap(s, ["points", "position"])
					var npts := PackedVector2Array()
					for q in s.points:
						var v: Vector2 = q + s.position
						match op:
							"flip_h": v.x = -v.x
							"flip_v": v.y = -v.y
							"rotate": v = v.rotated(deg_to_rad(ep.rotate_step))
						npts.append(v)
					s.position = Vector2.ZERO
					s.points = npts
					cmds.append(Commands.props_from(s, sb, "Отразить форму"))
			else:
				r.flip_h = not r.flip_h if op == "flip_h" else r.flip_h
			cmds.append(Commands.props_from(r, b, "Отразить"))
	cmds = cmds.filter(func(c): return c != null)
	if not cmds.is_empty():
		push_done(Commands.Batch.new(cmds, "Преобразовать"))


func nudge(v: Vector2) -> void:
	var cmds: Array = []
	if selection.size() == 1 and selection[0] is GeoShape and not sel_points.is_empty():
		var s: GeoShape = selection[0]
		var b := Commands.snap(s, ["points"])
		var basis := level.shape_xform(s).affine_inverse()
		var lv := basis.basis_xform(v)
		var pts := s.points.duplicate()
		for i in sel_points:
			pts[i] += lv
		s.points = pts
		push_done(Commands.props_from(s, b, "Сдвиг точек"))
		return
	for r in moveable_selection():
		var b := Commands.snap(r, ["position"])
		r.position += move_delta_for(r, v)
		cmds.append(Commands.props_from(r, b, "Сдвиг"))
	cmds = cmds.filter(func(c): return c != null)
	if not cmds.is_empty():
		var bt := Commands.Batch.new(cmds, "Сдвиг")
		bt.merge_key = "nudge"
		push_done(bt)


## Выделенное без контуров, родитель которых тоже выделен (они едут вместе с ним).
func moveable_selection() -> Array:
	var out: Array = []
	for r in selection:
		if r is GeoShape and r.parent_uid != "":
			var parent := level.find_object(r.parent_uid)
			if parent != null and selection.has(parent):
				continue
		out.append(r)
	return out


## Сдвиг в мире → сдвиг поля position (у привязанного контура — в координатах родителя).
func move_delta_for(r: Resource, world_delta: Vector2) -> Vector2:
	if r is GeoShape and r.parent_uid != "":
		var parent := level.find_object(r.parent_uid)
		if parent != null:
			return LevelData.object_xform(parent).affine_inverse().basis_xform(world_delta)
	return world_delta


# ============================================================ картинки: перетаскивание и выбор

func _on_files_dropped(files: PackedStringArray) -> void:
	if runtime != null or _dialog_open:
		return
	var at := mouse_world()
	for f in files:
		var ext := f.get_extension().to_lower()
		if not ext in ["png", "jpg", "jpeg", "webp"]:
			say("Пропущен %s: нужна картинка PNG или JPG" % f.get_file())
			continue
		var dst := await _import_file(f)
		if dst == "":
			continue
		await add_image(dst, at)
		at += Vector2(ep.paste_offset, ep.paste_offset)


## Копирует файл в res://art/<эпоха уровня>/. Если такое имя есть — спросить «заменить / переименовать».
func _import_file(src: String) -> String:
	var dir := "res://art/%s" % level.epoch
	DirAccess.make_dir_recursive_absolute(dir)
	var dst := dir.path_join(src.get_file())
	if ProjectSettings.globalize_path(dst) == src:
		return dst
	if FileAccess.file_exists(dst):
		var c := await ask("Файл уже есть", "В %s уже есть %s." % [dir, src.get_file()], ["Заменить", "Переименовать", "Отмена"])
		if c == 2 or c < 0:
			return ""
		if c == 1:
			var base := src.get_file().get_basename()
			var n := 2
			while FileAccess.file_exists(dir.path_join("%s_%d.%s" % [base, n, src.get_extension()])):
				n += 1
			dst = dir.path_join("%s_%d.%s" % [base, n, src.get_extension()])
	var err := DirAccess.copy_absolute(src, ProjectSettings.globalize_path(dst))
	if err != OK:
		say("Не удалось скопировать %s (код %d)" % [src, err])
		return ""
	ArtLoader.forget(dst)
	_sprites_reload(dst)
	return dst


func _sprites_reload(path: String) -> void:
	for k in _sprites.keys():
		if (_sprites[k]["key"] as String).begins_with(path + "|"):
			_sprites[k]["node"].queue_free()
			_sprites.erase(k)


## Спросить «Фон / Арт-объект» и поставить картинку в точку at.
func add_image(path: String, at: Vector2) -> void:
	if ArtLoader.load_texture(path) == null:
		say("Не удалось загрузить картинку " + path)
		return
	var c := await ask("Картинка", "Как добавить %s?" % path.get_file(), ["Фон", "Арт-объект", "Отмена"])
	if c == 0:
		var b := BackgroundLayer.new()
		b.uid = level.next_uid("bg")
		b.path = path
		b.layer = LevelData.Layer.BASE
		var sz := ArtLoader.image_size(path)
		var k := level.bounds.size.y / maxf(sz.y, 1.0)
		b.scale = Vector2(k, k)
		b.position = Vector2(at.x, level.bounds.position.y)
		b.z = level.backgrounds.size()
		add_items("backgrounds", [b], "Добавить фон")
		set_selection([b])
	elif c == 1:
		var art := Catalog.get_def(ART_DEF)
		var o := PlacedObject.new()
		o.def_id = ART_DEF if art != null else ""
		o.uid = level.next_uid("art")
		o.position = at
		o.layer = LevelData.Layer.GAMEPLAY
		o.props = {"image": path}
		add_items("objects", [o], "Добавить арт-объект")
		set_selection([o])


func add_image_dialog() -> void:
	var path := await pick_image()
	if path != "":
		await add_image(path, view_rect().get_center())


# ============================================================ автообводка и палитра

func autotrace(o: PlacedObject, top_only: bool) -> void:
	var img := ArtLoader.load_image(object_image(o))
	if img == null:
		say("Нет картинки для обводки")
		return
	var half := Vector2(img.get_size()) * 0.5
	var polys: Array
	if top_only:
		polys = Autotrace.top_edges(img, ep.alpha_threshold, ep.trace_epsilon, ep.top_edge_min_run)
	else:
		polys = Autotrace.bodies(img, ep.alpha_threshold, ep.trace_epsilon)
	if polys.is_empty():
		say("Ничего не найдено: картинка без прозрачности или порог слишком высокий")
		return
	var made: Array = []
	var kind := GeoShape.Kind.PLATFORM if top_only else GeoShape.Kind.BODY
	var xf := LevelData.object_xform(o)
	for poly in polys:
		var local := PackedVector2Array()
		for p in poly:
			local.append(p - half)
		var s := new_shape(kind, xf * local, o)
		made.append(s)
	_assign_uids(made, "shape")
	add_items("shapes", made, "Автообводка")
	set_selection(made)
	say("Автообводка: %d контур(ов)" % made.size())


func save_art_to_palette(o: PlacedObject) -> void:
	var img := object_image(o)
	var r := await form("Сохранить в палитру", [
		{"name": "title", "label": "Название", "value": img.get_file().get_basename()},
		{"name": "id", "label": "id (латиница, цифры, _)", "value": img.get_file().get_basename().to_lower().replace(" ", "_").replace("-", "_")},
	])
	if r.is_empty():
		return
	var def := ObjectDef.new()
	def.id = r["id"]
	def.title = r["title"]
	def.category = "Арт-объекты"
	def.epoch = level.epoch
	var base := Catalog.get_def(ART_DEF)
	if base != null:
		def.scene = base.scene
		def.props_script = base.props_script
	def.transformable = true
	def.default_layer = LevelData.Layer.GAMEPLAY
	def.image = img
	def.editor_size = ArtLoader.image_size(img)
	var shs: Array[GeoShape] = []
	for s in level.shapes_of(o.uid):
		var c: GeoShape = s.duplicate()
		c.parent_uid = ""
		shs.append(c)
	def.shapes = shs
	var path := "res://catalog/%s/%s.tres" % [level.epoch, def.id]
	if FileAccess.file_exists(path) and await ask("Палитра", "В палитре уже есть %s. Заменить?" % def.id, ["Заменить", "Отмена"]) != 0:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(def, path)
	if err != OK:
		say("Не удалось сохранить %s (код %d)" % [path, err])
		return
	Catalog.reload()
	palette.rebuild()
	var b := Commands.snap(o, ["def_id"])
	o.def_id = def.id
	push_done(Commands.props_from(o, b, "Связать с палитрой"))
	say("В палитре: %s (%s), контуров: %d" % [def.title, path, shs.size()])


## «Обновить из палитры»: картинка и контуры экземпляра — как сейчас в каталоге.
func update_from_palette(o: PlacedObject) -> void:
	var def := def_of(o)
	if def == null or def.image == "":
		return
	var cmds: Array = []
	var b := Commands.snap(o, ["props"])
	var p: Dictionary = o.props.duplicate(true)
	p["image"] = def.image
	cmds.append(Commands.PropsCmd.new(o, b, {"props": p}))
	var old := level.shapes_of(o.uid)
	if not old.is_empty():
		cmds.append(Commands.ListCmd.new(level, "shapes", old, false))
	var fresh: Array = []
	for s in def.shapes:
		var c: GeoShape = s.duplicate()
		c.parent_uid = o.uid
		fresh.append(c)
	_assign_uids(fresh, "shape")
	if not fresh.is_empty():
		cmds.append(Commands.ListCmd.new(level, "shapes", fresh, true))
	exec(Commands.Batch.new(cmds, "Обновить из палитры"))
	say("Обновлено из палитры: %s" % def.title)


# ============================================================ инструменты

func set_tool(n: String) -> void:
	if runtime != null:
		return
	if tool != null:
		tool.deactivate()
	tool_name = n
	tool = tools[n]
	tool.activate()
	for k in tool_buttons:
		tool_buttons[k].set_pressed_no_signal(k == n)
	canvas.invalidate()


func begin_place(def: ObjectDef) -> void:
	tools["place"].def = def
	set_tool("place")


## Обвести форму объекта заново (или добавить ещё одну — replace = null). Инструмент точек, как у коллизии.
func begin_form_draw(o: PlacedObject, role: String, replace: GeoShape = null) -> void:
	var d := def_of(o)
	set_tool("form")
	var t = tools["form"]
	t.target_obj = o
	t.target_role = role
	t.replace = replace
	t.allow_open = not (role in ["area", "weak"] or (d != null and d.kind == "breakable"))
	say("Обведите форму «%s»: клик — точка, держи ЛКМ — лассо, клик по первой точке — замкнуть%s. Esc — отмена." % [GeoShape.ROLE_TITLES.get(role, role), ", Enter — открытая" if t.allow_open else ""])


## Двойной клик по объекту: правка его формы (выделить форму — появятся ручки точек). Esc — назад к объекту.
func enter_form_edit(o: PlacedObject, at: Vector2) -> bool:
	var roles := level.role_shapes(o.uid)
	if roles.is_empty():
		return false
	var pick: GeoShape = roles[0]
	for s in roles:
		if item_hit(s, at):
			pick = s
			break
	set_selection([pick])
	say("Правка формы %s: тяни точки, клик по ребру — новая точка, ПКМ — удалить. Esc — к объекту." % o.uid)
	return true


## Пипетка: следующий клик по подходящему объекту отдаёт его uid в on_pick.
func begin_pick(accept: Callable, on_pick: Callable, label: String, source: Resource = null, multi: bool = false) -> void:
	var prev := tool_name if tool_name != "pick" else "select"
	set_tool("pick")
	var t = tools["pick"]
	t.accept = accept
	t.on_pick = on_pick
	t.label = label
	t.source = source
	t.multi = multi
	t._prev_tool = prev
	say("Пипетка: кликните %s на холсте (Esc — отмена)" % label)


## Связи объекта для линий на холсте: [{to: uid, mode: int, kind: "link"/"lit"/"path"/"ref"}].
func links_of(o: PlacedObject) -> Array:
	var out: Array = []
	var d := def_of(o)
	if d == null or d.props_script == null:
		return out
	var t = prop(o, "targets", PackedStringArray())
	if t is Array or t is PackedStringArray:
		for u in t:
			out.append({"to": String(u), "mode": int(prop(o, "link_mode", 0)), "kind": "link"})
	if bool(prop(o, "lit_enabled", false)):
		var lt = prop(o, "lit_targets", PackedStringArray())
		for u in lt:
			out.append({"to": String(u), "mode": int(prop(o, "lit_link_mode", 3)), "kind": "lit"})
	var picks: Dictionary = d.props_script.get_script_constant_map().get("PICKS", {})
	for pname in picks:
		if picks[pname] in ["path", "object"]:
			var v := String(prop(o, pname, ""))
			if v != "":
				out.append({"to": v, "mode": -1, "kind": "path" if picks[pname] == "path" else "ref"})
	return out


## «Сохранить как значения каталога» (dev): свойства и формы экземпляра → default_props и shapes его записи
## каталога (или элемента готового набора, если объект поставлен набором). Новые объекты из палитры — с ними.
func save_to_catalog(o: PlacedObject) -> void:
	var kit_id := String(o.props.get("_kit", ""))
	var kit_key := String(o.props.get("_kit_key", ""))
	var props := {}
	for k in o.props:
		if not String(k).begins_with("_") and k != "image":
			props[k] = Commands.Cmd.copy_value(o.props[k])
	var shs: Array = []
	for s in level.role_shapes(o.uid):
		var wp := level.shape_world_points(s)
		var local := PackedVector2Array()
		for q in wp:
			local.append(q - o.position)
		shs.append({"role": s.role, "points": local, "closed": s.is_closed()})
	var target: ObjectDef
	if kit_id != "":
		target = Catalog.get_def(kit_id)
		if target == null:
			kit_id = ""
	if kit_id != "":
		var kit: Array = target.kit.duplicate(true)
		var found := false
		for i in range(kit.size()):
			if kit[i].get("key", "") == kit_key:
				var it: Dictionary = kit[i]
				var merged: Dictionary = (it.get("props", {}) as Dictionary).duplicate(true)
				for k in props:
					var v = props[k]
					if (k == "targets" or k == "lit_targets") and it.get("props", {}).has(k):
						continue   # связи набора остаются ссылками "@key"
					merged[k] = v
				it["props"] = merged
				if not shs.is_empty():
					it["shapes"] = shs
				kit[i] = it
				found = true
		if not found:
			say("Не найден элемент «%s» в наборе %s" % [kit_key, kit_id])
			return
		target.kit = kit
	else:
		target = def_of(o)
		if target == null:
			return
		var dp := target.default_props.duplicate(true)
		for k in props:
			if k == "targets" or k == "lit_targets":
				continue   # связи — свойство конкретного уровня
			dp[k] = props[k]
		target.default_props = dp
		if not shs.is_empty():
			var arr: Array[GeoShape] = []
			for sh in shs:
				var g := GeoShape.new()
				g.role = sh["role"]
				g.closed = sh["closed"]
				g.kind = GeoShape.Kind.BODY if g.closed else GeoShape.Kind.WALL
				g.points = sh["points"]
				g.color = target.editor_color
				arr.append(g)
			target.shapes = arr
	var path := target.resource_path
	if path == "":
		path = "res://catalog/%s/%s.tres" % [target.epoch, target.id]
	var err := ResourceSaver.save(target, path)
	if err != OK:
		say("Не удалось сохранить %s (код %d)" % [path, err])
		return
	Catalog.reload()
	palette.rebuild()
	say("Значения каталога «%s» обновлены (%s): свойств %d, форм %d" % [target.title, path, props.size(), shs.size()])


# ============================================================ сценарий уровня (фаза 4)

func script_path() -> String:
	return LevelRuntime.script_path_for(level)


func _ids_brief() -> String:
	var lines: PackedStringArray = []
	for o in level.objects:
		var d := def_of(o)
		if d == null or not (d.kind in ["zone", "marker"]):
			continue
		var note := String(prop(o, "note", "")).strip_edges().replace("\n", " / ")
		lines.append("- %s «%s» (%s): %s" % ["зона" if d.kind == "zone" else "метка", o.uid, "%d, %d" % [o.position.x, o.position.y], note if note != "" else "без заметки"])
	return "\n".join(lines)


## Текст для агента: уровень, путь сценария, зоны и метки с заметками, прочие объекты с id.
func copy_script_brief() -> void:
	var others: PackedStringArray = []
	for o in level.objects:
		var d := def_of(o)
		if d != null and not (d.kind in ["zone", "marker", "start", "note", ""]):
			others.append("%s (%s)" % [o.uid, d.title])
	var txt := "Уровень %s «%s», файл %s\nСценарий: %s (%s)\n\nЗоны и метки:\n%s\n\nДругие объекты: %s\n\nЧто должно происходить:\n" % [
		level.id, level.title, level_file_path(), script_path(), "есть" if FileAccess.file_exists(script_path()) else "ещё нет",
		_ids_brief() if _ids_brief() != "" else "- нет", ", ".join(others) if not others.is_empty() else "нет"]
	DisplayServer.clipboard_set(txt)
	say("Задание для агента скопировано в буфер обмена — допиши, что должно происходить")


## Заготовка сценария: пустые события и список зон и меток.
func create_script_stub() -> void:
	var path := script_path()
	if FileAccess.file_exists(path):
		say("Сценарий уже есть: " + path)
		return
	var ids := _ids_brief()
	var txt := """extends "res://game/level/level_script.gd"
## Сценарий уровня %s. Команды — заметка «Технология/Сценарии уровней».
## Зоны и метки уровня:
%s

# Настройки
# const ZOOM := 0.7   # пример: насколько отъезжает камера


func on_level_start() -> void:
	pass


func on_zone_enter(id: String) -> void:
	match id:
		_:
			pass


func on_zone_exit(_id: String) -> void:
	pass


func on_event(_uid: String, _ev: String, _data: Dictionary) -> void:
	pass
""" % [level.id, "\n".join(Array(("" if ids == "" else ids).split("\n")).map(func(x): return "## " + x)) if ids != "" else "## (пока нет)"]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		say("Не удалось создать " + path)
		return
	f.store_string(txt)
	f.close()
	say("Заготовка сценария: " + path)
	inspector._sig = "-"
	inspector.sync()


## Форма по картинке: самый большой непрозрачный силуэт картинки (центр — в объекте + сдвиг, масштаб) → форма role.
func trace_form(o: PlacedObject, role: String, image_path: String, sc: float, offset: Vector2) -> void:
	var img := ArtLoader.load_image(image_path)
	if img == null:
		say("Нет картинки для обводки: " + image_path)
		return
	var polys: Array = Autotrace.bodies(img, ep.alpha_threshold, ep.trace_epsilon)
	if polys.is_empty():
		say("Ничего не найдено: картинка без прозрачности или порог слишком высокий")
		return
	var best: PackedVector2Array = polys[0]
	for p in polys:
		if absf(Geometry.signed_area(p)) > absf(Geometry.signed_area(best)):
			best = p
	var half := Vector2(img.get_size()) * 0.5
	var world := PackedVector2Array()
	for q in best:
		world.append(o.position + offset + (q - half) * sc)
	var s := new_role_shape(o, role, world, true)
	var cmds: Array = []
	for old in level.role_shapes(o.uid, role):
		cmds.append(Commands.ListCmd.new(level, "shapes", [old], false))
	cmds.append(Commands.ListCmd.new(level, "shapes", [s], true))
	exec(Commands.Batch.new(cmds, "Форма по картинке"))
	set_selection([s])
	say("Форма по картинке: %d точек. Правьте точки или «Упростить»." % world.size())


func say(text: String) -> void:
	_message = text
	_message_t = 6.0
	print("[конструктор] ", text)


# ============================================================ «Играть отсюда»

## «Играть отсюда». from_start — от «Старта героя» (F5, кнопка ▶); иначе — от курсора (Shift+F5).
## Если старта на уровне нет, F5 запускает от курсора.
func play(from_start: bool) -> void:
	if runtime != null:
		return
	var rt := LevelRuntime.new()
	rt.level = level
	rt.test_mode = true
	var start := level.objects.filter(func(o): return o.def_id == START_DEF)
	if from_start and not start.is_empty():
		rt.has_launch = true
		rt.launch_pos = start[0].position
	else:
		if from_start:
			say("На уровне нет «Старта героя» — запуск от курсора")
		rt.has_launch = true
		rt.launch_pos = _last_mouse_world
	tool.deactivate()
	_store_editor_state()
	undo.seal()
	_play_mark = undo.done.size()
	_play_last = undo.done.back() if not undo.done.is_empty() else null
	world.visible = false
	bg_color_layer.visible = false
	cam.enabled = false
	runtime = rt
	add_child(rt)
	_set_play_ui(true)


## Интерфейс во время игры: виден только инспектор справа (F2 — скрыть/показать), остальное спрятано.
func _set_play_ui(playing: bool) -> void:
	for n in [_top_bar, palette.get_parent(), _bottom, _status_bar]:
		n.visible = not playing
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE if playing else Control.MOUSE_FILTER_STOP
	var show_insp := not playing or (play_inspector and selection.size() == 1 and selection[0] is PlacedObject)
	inspector.get_parent().visible = show_insp
	ui.visible = not playing or show_insp
	if playing and show_insp:
		inspector.sync()


func stop_play() -> void:
	if runtime == null:
		return
	var pos: Vector2 = cam.position
	if runtime.player != null and is_instance_valid(runtime.player):
		pos = runtime.player.global_position
	runtime.queue_free()
	runtime = null
	Fx.set_base_scale(1.0)
	world.visible = true
	_set_play_ui(false)
	cam.enabled = true
	cam.make_current()
	cam.position = pos
	cam.reset_smoothing()
	get_viewport().gui_release_focus()
	tool.activate()
	_full_refresh()
	var last = undo.done.back() if not undo.done.is_empty() else null
	if undo.done.size() != _play_mark or last != _play_last:
		var c := await ask("Правки во время игры", "Во время игры менялись свойства объектов. Оставить эти изменения в уровне?", ["Оставить", "Вернуть как было"])
		if c == 1:
			var guard := 0
			while not undo.done.is_empty() and (undo.done.size() > _play_mark or undo.done.back() != _play_last) and guard < 1000:
				undo.undo()
				guard += 1
			undo.undone.clear()
			say("Правки, сделанные во время игры, отменены")


# ============================================================ ввод

func is_typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _process(delta: float) -> void:
	if runtime != null or tool == null:
		return
	_autosave_t += delta
	if _autosave_t >= maxf(ep.autosave_interval, 5.0):
		_autosave_t = 0.0
		_autosave()
	if _message_t > 0.0:
		_message_t -= delta
	_update_status()


## Ввод мыши с холста (catcher — область между панелями).
func _canvas_input(event: InputEvent) -> void:
	if runtime != null or tool == null:
		return
	if event is InputEventMouse:
		_last_mouse_world = mouse_world()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not catcher.has_focus():
			catcher.grab_focus()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(ep.zoom_step, mouse_world())
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(1.0 / ep.zoom_step, mouse_world())
			return
		var pan_click := mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and Input.is_action_pressed("ed_pan"))
		if pan_click and mb.pressed:
			_panning = true
			_pan_from = mb.position
			_cam_from = cam.position
			return
		if _panning and not mb.pressed and (mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_LEFT):
			_panning = false
			return
	if event is InputEventMouseMotion and _panning:
		cam.position = _cam_from - (event.position - _pan_from) / zoom()
		canvas.invalidate()
		return
	if event is InputEventMagnifyGesture:
		zoom_at(event.factor, mouse_world())
		return
	if event is InputEventPanGesture:
		cam.position += event.delta * px(16.0)
		canvas.invalidate()
		return
	tool.input(event)
	canvas.invalidate()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if runtime != null:
		if is_typing():
			return
		if EdInput.pressed(event, "ed_play") or EdInput.pressed(event, "ed_play_cursor") or EdInput.pressed(event, "ed_cancel"):
			stop_play()
			get_viewport().set_input_as_handled()
		elif EdInput.pressed(event, "ed_inspector_play"):
			play_inspector = not play_inspector
			_set_play_ui(true)
			get_viewport().set_input_as_handled()
		return
	if is_typing() or _dialog_open or tool == null:
		return
	if tool.key(event):
		get_viewport().set_input_as_handled()
		canvas.invalidate()
		return
	var handled := true
	if EdInput.pressed(event, "ed_select"):
		set_tool("select")
	elif EdInput.pressed(event, "ed_body"):
		set_tool("body")
	elif EdInput.pressed(event, "ed_platform"):
		set_tool("platform")
	elif EdInput.pressed(event, "ed_wall"):
		set_tool("wall")
	elif EdInput.pressed(event, "ed_block"):
		set_tool("block")
	elif EdInput.pressed(event, "ed_kill"):
		set_tool("kill")
	elif EdInput.pressed(event, "ed_path"):
		set_tool("path")
	elif EdInput.pressed(event, "ed_zone"):
		set_tool("zone")
	elif EdInput.pressed(event, "ed_marker"):
		var md := Catalog.get_def("marker")
		if md != null:
			begin_place(md)
			say("Метка: клик в холсте (Shift — несколько). Потом дай ей id (m_…) и заметку.")
	elif EdInput.pressed(event, "ed_links"):
		toggle("show_links")
		say("Линии связей: " + ("всегда" if show_links else "только у выделенного"))
	elif EdInput.pressed(event, "ed_grid"):
		toggle("grid_snap")
	elif EdInput.pressed(event, "ed_collision"):
		toggle("show_collision")
	elif EdInput.pressed(event, "ed_player_view"):
		toggle("player_view")
	elif EdInput.pressed(event, "ed_play"):
		play(true)
	elif EdInput.pressed(event, "ed_play_cursor"):
		play(false)
	elif EdInput.pressed(event, "ed_undo", true):
		undo.undo()
	elif EdInput.pressed(event, "ed_redo", true):
		undo.redo()
	elif EdInput.pressed(event, "ed_save"):
		save_level(level_path == "")
	elif EdInput.pressed(event, "ed_copy"):
		copy_selection()
	elif EdInput.pressed(event, "ed_paste"):
		paste_at(_last_mouse_world)
	elif EdInput.pressed(event, "ed_duplicate"):
		duplicate_selection()
	elif EdInput.pressed(event, "ed_delete"):
		delete_selection()
	elif EdInput.pressed(event, "ed_flip_h"):
		transform_selection("flip_h")
	elif EdInput.pressed(event, "ed_flip_v"):
		transform_selection("flip_v")
	elif EdInput.pressed(event, "ed_rotate"):
		transform_selection("rotate")
	elif EdInput.pressed(event, "ed_focus"):
		focus_selection()
	elif EdInput.pressed(event, "ed_home"):
		_fit_rect(level.bounds)
	elif EdInput.pressed(event, "ed_zoom_reset"):
		zoom_at(1.0 / zoom(), view_rect().get_center(), get_viewport().get_visible_rect().size * 0.5)
	elif EdInput.pressed(event, "ed_left", true):
		nudge(Vector2(-ep.nudge_small, 0))
	elif EdInput.pressed(event, "ed_right", true):
		nudge(Vector2(ep.nudge_small, 0))
	elif EdInput.pressed(event, "ed_up", true):
		nudge(Vector2(0, -ep.nudge_small))
	elif EdInput.pressed(event, "ed_down", true):
		nudge(Vector2(0, ep.nudge_small))
	elif EdInput.pressed(event, "ed_left_big", true):
		nudge(Vector2(-ep.nudge_big, 0))
	elif EdInput.pressed(event, "ed_right_big", true):
		nudge(Vector2(ep.nudge_big, 0))
	elif EdInput.pressed(event, "ed_up_big", true):
		nudge(Vector2(0, -ep.nudge_big))
	elif EdInput.pressed(event, "ed_down_big", true):
		nudge(Vector2(0, ep.nudge_big))
	elif EdInput.pressed(event, "ed_cancel"):
		if not sel_points.is_empty():
			sel_points.clear()
		elif tool_name != "select":
			set_tool("select")
		elif selection.size() == 1 and selection[0] is GeoShape and selection[0].role != "" and level.find_object(selection[0].parent_uid) != null:
			set_selection([level.find_object(selection[0].parent_uid)])   # из правки формы — к объекту
		else:
			set_selection([])
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		canvas.invalidate()


func toggle(what: String) -> void:
	set(what, not get(what))
	if toggle_buttons.has(what):
		toggle_buttons[what].set_pressed_no_signal(get(what))
	if what == "player_view" or what == "show_collision":
		_prune_hidden_selection()
		refresh_view()
	canvas.invalidate()


func _prune_hidden_selection() -> void:
	var keep := selection.filter(func(r): return item_selectable(r) or (r is BackgroundLayer and r.locked))
	if keep.size() != selection.size():
		set_selection(keep)


# ============================================================ проверка

func validate() -> void:
	_refresh_problems()
	var e := _problems.filter(func(p): return p["error"]).size()
	say("Проверка: ошибок %d, предупреждений %d" % [e, _problems.size() - e])


func _refresh_problems() -> void:
	_problems = Validator.run(level, ep)
	if problems_list == null:
		return
	problems_list.clear()
	for p in _problems:
		var i := problems_list.add_item(("⛔ " if p["error"] else "⚠ ") + p["text"])
		problems_list.set_item_custom_fg_color(i, Color(1, 0.45, 0.45) if p["error"] else Color(1, 0.8, 0.4))
	if _problems.is_empty():
		problems_list.add_item("✓ Проблем не найдено")
	canvas.invalidate()


func _on_problem_clicked(i: int) -> void:
	if i < 0 or i >= _problems.size():
		return
	var p: Dictionary = _problems[i]
	cam.position = p["pos"]
	var r := level.find_any(p["uid"]) if p["uid"] != "" else null
	if r != null:
		set_selection([r])
	canvas.invalidate()


func problem_uids() -> Dictionary:
	var d := {}
	for p in _problems:
		if p["error"] and p["uid"] != "":
			d[p["uid"]] = true
	return d


# ============================================================ интерфейс

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = UI_FONT_SIZE
	root.theme = th
	ui.add_child(root)
	ui_root = root
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	root.add_child(vb)

	_top_bar = _build_top_bar()
	vb.add_child(_top_bar)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_constant_override("separation", 0)
	vb.add_child(mid)

	var left := _panel(Vector2(220, 0))
	left.clip_contents = true
	palette = PaletteScript.new()
	palette.ed = self
	left.add_child(palette)
	mid.add_child(left)

	catcher = Control.new()
	catcher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catcher.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.focus_mode = Control.FOCUS_ALL
	catcher.gui_input.connect(_canvas_input)
	catcher.mouse_exited.connect(func() -> void: canvas.invalidate())
	catcher.set_drag_forwarding(Callable(), _can_drop_palette, _drop_palette)
	mid.add_child(catcher)

	var right := _panel(Vector2(360, 0))
	right.clip_contents = true
	inspector = InspectorScript.new()
	inspector.ed = self
	right.add_child(inspector)
	mid.add_child(right)

	_bottom = _build_bottom()
	vb.add_child(_bottom)

	var sb := PanelContainer.new()
	sb.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.08, 0.97)))
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.clip_text = true
	sb.add_child(status_label)
	vb.add_child(sb)
	_status_bar = sb

	palette.rebuild()
	inspector.sync()


func _style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.11, 0.94)))
	return p


func _btn(parent: Control, text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_top_bar() -> Control:
	var p := _panel(Vector2(0, 0))
	var hb := HFlowContainer.new()
	hb.add_theme_constant_override("h_separation", 4)
	p.add_child(hb)

	var file := MenuButton.new()
	file.text = "Файл"
	file.flat = false
	var fp := file.get_popup()
	fp.add_item("Новый", 0)
	fp.add_item("Открыть…", 1)
	fp.add_item("Сохранить (Ctrl+S)", 2)
	fp.add_item("Сохранить как…", 3)
	fp.add_separator()
	fp.add_item("Закрыть", 4)
	fp.id_pressed.connect(_on_file_menu)
	hb.add_child(file)

	var edit := MenuButton.new()
	edit.text = "Правка"
	edit.flat = false
	var epp := edit.get_popup()
	for item in [["Отменить (Ctrl+Z)", 0], ["Повторить (Ctrl+Y)", 1], ["Копировать (Ctrl+C)", 2], ["Вставить (Ctrl+V)", 3], ["Дублировать (Ctrl+D)", 4], ["Удалить (Delete)", 5]]:
		epp.add_item(item[0], item[1])
	epp.id_pressed.connect(_on_edit_menu)
	hb.add_child(edit)
	hb.add_child(VSeparator.new())

	for t in [["select", "Выделение", "V"], ["body", "Тело", "P"], ["platform", "Платформа", "N"], ["wall", "Стена", "W"], ["block", "Блок", "B"], ["kill", "Смерть", "K"], ["path", "Путь", "L"], ["zone", "Зона", "Z"]]:
		var b := Button.new()
		b.text = "%s %s" % [t[1], t[2]]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_tool.bind(t[0]))
		hb.add_child(b)
		tool_buttons[t[0]] = b
	hb.add_child(VSeparator.new())

	for t in [["grid_snap", "Сетка G", "Привязка к сетке (шаг — вкладка «Редактор»)"], ["magnet", "Магнит", "Прилипать к точкам и рёбрам других контуров"], ["show_collision", "Коллизия C", "Показывать контуры коллизии"], ["show_grid", "Сетка", "Рисовать сетку"], ["show_links", "Связи T", "Линии связей на холсте всегда (выключено — только у выделенного объекта)"], ["player_view", "Вид игрока F6", "Без служебного слоя, сетки и контуров; фоны с параллаксом и темнотой уровня"]]:
		var b := Button.new()
		b.text = t[1]
		b.tooltip_text = t[2]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = get(t[0])
		b.toggled.connect(func(on: bool) -> void:
			set(t[0], on)
			_prune_hidden_selection()
			refresh_view())
		hb.add_child(b)
		toggle_buttons[t[0]] = b
	hb.add_child(VSeparator.new())
	_btn(hb, "Добавить картинку", add_image_dialog, "Картинки из art/<эпоха>/ и art/common/. Можно просто перетащить PNG/JPG из проводника в окно.")
	_btn(hb, "Проверить", validate)
	_btn(hb, "▶ F5", _play_button, "F5 / ▶ — от «Старта героя», Shift+F5 — от курсора")
	return p


func _on_file_menu(id: int) -> void:
	match id:
		0: new_level_dialog()
		1: open_dialog()
		2: save_level(level_path == "")
		3: save_level(true)
		4: close_editor()


func _on_edit_menu(id: int) -> void:
	match id:
		0: undo.undo()
		1: undo.redo()
		2: copy_selection()
		3: paste_at(view_rect().get_center())
		4: duplicate_selection()
		5: delete_selection()


func _play_button() -> void:
	if not level.objects.any(func(o): return o.def_id == START_DEF):
		_last_mouse_world = view_rect().get_center()
	play(true)


func _build_bottom() -> Control:
	var p := _panel(Vector2(0, 150))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)

	var lay := GridContainer.new()
	lay.columns = 4
	lay.add_theme_constant_override("h_separation", 6)
	lay.add_theme_constant_override("v_separation", 0)
	for txt in ["Слой", "Видно", "Замок", "Прозр."]:
		var l := Label.new()
		l.text = txt
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
		lay.add_child(l)
	for i in range(LevelData.LAYER_TITLES.size()):
		var l := Label.new()
		l.text = LevelData.LAYER_TITLES[i]
		l.add_theme_font_size_override("font_size", 12)
		lay.add_child(l)
		var vis := CheckBox.new()
		vis.focus_mode = Control.FOCUS_NONE
		vis.self_modulate = CHECK_TINT
		vis.toggled.connect(func(on: bool) -> void: _set_layer(i, "visible", on))
		lay.add_child(vis)
		var lock := CheckBox.new()
		lock.focus_mode = Control.FOCUS_NONE
		lock.self_modulate = CHECK_TINT
		lock.toggled.connect(func(on: bool) -> void: _set_layer(i, "locked", on))
		lay.add_child(lock)
		var a := HSlider.new()
		a.min_value = 0.0
		a.max_value = 1.0
		a.step = 0.05
		a.custom_minimum_size = Vector2(70, 0)
		a.focus_mode = Control.FOCUS_NONE
		a.value_changed.connect(func(v: float) -> void: _set_layer(i, "alpha", v))
		lay.add_child(a)
		layer_rows.append({"vis": vis, "lock": lock, "alpha": a})
	hb.add_child(lay)

	var bgbox := VBoxContainer.new()
	var bl := Label.new()
	bl.text = "Фоны (клик — выбрать, даже запертый)"
	bl.add_theme_font_size_override("font_size", 11)
	bgbox.add_child(bl)
	bg_list = ItemList.new()
	bg_list.custom_minimum_size = Vector2(220, 0)
	bg_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg_list.focus_mode = Control.FOCUS_NONE
	bg_list.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void:
		if i < level.backgrounds.size():
			set_selection([level.backgrounds[i]]))
	bgbox.add_child(bg_list)
	hb.add_child(bgbox)

	var pb := VBoxContainer.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pl := Label.new()
	pl.text = "Проверка уровня (клик — показать место)"
	pl.add_theme_font_size_override("font_size", 11)
	pb.add_child(pl)
	problems_list = ItemList.new()
	problems_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	problems_list.focus_mode = Control.FOCUS_NONE
	problems_list.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void: _on_problem_clicked(i))
	pb.add_child(problems_list)
	hb.add_child(pb)
	return p


func _set_layer(i: int, key: String, v: Variant) -> void:
	layers[i][key] = v
	_prune_hidden_selection()
	refresh_view()


func _refresh_layer_rows() -> void:
	for i in range(layer_rows.size()):
		var r: Dictionary = layer_rows[i]
		r["vis"].set_pressed_no_signal(layers[i]["visible"])
		r["lock"].set_pressed_no_signal(layers[i]["locked"])
		r["alpha"].set_value_no_signal(layers[i]["alpha"])
	for k in toggle_buttons:
		toggle_buttons[k].set_pressed_no_signal(get(k))


func _refresh_bg_list() -> void:
	if bg_list == null:
		return
	bg_list.clear()
	for b in level.backgrounds:
		bg_list.add_item("%s%s  %s" % ["🔒 " if b.locked else "", b.uid, b.path.get_file()])
	_refresh_layer_rows()


func _update_status() -> void:
	var m := _last_mouse_world
	var t: String = "x %d px (%.1f T)   y %d px (%.1f T)   |   масштаб %d%%   |   %s" % [m.x, m.x / T, m.y, m.y / T, roundi(zoom() * 100.0), tool.title()]
	var hint: String = tool.hint()
	if hint != "":
		t += "   |   " + hint
	if grid_snap:
		t += "   |   сетка %s" % ["T", "T/2", "T/4"][clampi(ep.grid_snap_div, 0, 2)]
	if _message_t > 0.0 and _message != "":
		t += "      ●  " + _message
	status_label.text = t


# ------------------------------------------------------------ палитра → холст (перетаскивание)

func _can_drop_palette(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("def_id")


func _drop_palette(_pos: Vector2, data: Variant) -> void:
	var def := Catalog.get_def(data["def_id"])
	if def != null:
		place_object(def, place_point(def, snap(mouse_world())))
		set_tool("select")


# ============================================================ диалоги

signal _dialog_closed(choice: int)


## Вопрос с кнопками. Возвращает номер кнопки (−1 — закрыли крестиком).
func ask(title: String, text: String, buttons: Array) -> int:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.exclusive = true
	d.get_ok_button().text = buttons[0]
	for i in range(1, buttons.size()):
		d.add_button(buttons[i], false, str(i))
	var result := [-1]
	d.confirmed.connect(func() -> void: result[0] = 0)
	d.custom_action.connect(func(a: StringName) -> void:
		result[0] = int(String(a))
		d.hide())
	await _run_dialog(d)
	return result[0]


## Форма из полей: [{name, label, value, options?, values?}]. Возвращает {} при отмене.
func form(title: String, fields: Array) -> Dictionary:
	var d := ConfirmationDialog.new()
	d.title = title
	d.exclusive = true
	var grid := GridContainer.new()
	grid.columns = 2
	d.add_child(grid)
	var ctrls := {}
	for f in fields:
		var l := Label.new()
		l.text = f["label"]
		grid.add_child(l)
		if f.has("options"):
			var ob := OptionButton.new()
			for o in f["options"]:
				ob.add_item(o)
			ob.select(maxi((f["values"] as Array).find(f["value"]), 0))
			grid.add_child(ob)
			ctrls[f["name"]] = ob
		else:
			var le := LineEdit.new()
			le.text = f["value"]
			le.custom_minimum_size = Vector2(260, 0)
			grid.add_child(le)
			ctrls[f["name"]] = le
	var result := [{}]
	d.confirmed.connect(func() -> void:
		var r := {}
		for f in fields:
			var c: Control = ctrls[f["name"]]
			if c is OptionButton:
				r[f["name"]] = f["values"][c.selected]
			else:
				r[f["name"]] = (c as LineEdit).text.strip_edges()
		result[0] = r)
	await _run_dialog(d)
	var r: Dictionary = result[0]
	if r.has("id") and not valid_id(r["id"]):
		say("id «%s» не подходит: только латиница в нижнем регистре, цифры и «_»" % r["id"])
		return {}
	return r


## Список уровней по эпохам. Возвращает путь или "".
func pick_level() -> String:
	var d := ConfirmationDialog.new()
	d.title = "Открыть уровень"
	d.exclusive = true
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(420, 320)
	d.add_child(list)
	var levels := LevelFiles.all_levels()
	for lv in levels:
		var ei := LevelData.EPOCHS.find(lv["epoch"])
		list.add_item("%s  /  %s" % [LevelData.EPOCH_TITLES[ei] if ei >= 0 else lv["epoch"], lv["id"]])
	var result := [""]
	var pick := func(i: int) -> void:
		if i >= 0 and i < levels.size():
			result[0] = levels[i]["path"]
	d.confirmed.connect(func() -> void:
		var s := list.get_selected_items()
		if not s.is_empty():
			pick.call(s[0]))
	list.item_activated.connect(func(i: int) -> void:
		pick.call(i)
		d.hide())
	await _run_dialog(d)
	return result[0]


## Картинки из art/<эпоха>/ и art/common/ с миниатюрами и поиском.
func pick_image() -> String:
	var d := ConfirmationDialog.new()
	d.title = "Добавить картинку"
	d.exclusive = true
	var vb := VBoxContainer.new()
	d.add_child(vb)
	var search := LineEdit.new()
	search.placeholder_text = "поиск по имени"
	vb.add_child(search)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(640, 420)
	list.max_columns = 0
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.fixed_icon_size = Vector2i(ep.thumb_size, ep.thumb_size)
	list.same_column_width = true
	vb.add_child(list)
	var paths := LevelFiles.images_in("res://art/" + level.epoch)
	if level.epoch != "common":
		paths.append_array(LevelFiles.images_in("res://art/common"))
	var shown: Array = []
	var fill := func(filter: String) -> void:
		list.clear()
		shown.clear()
		for p in paths:
			if filter == "" or p.get_file().to_lower().contains(filter.to_lower()):
				list.add_item(p.get_file(), palette.thumb(p))
				shown.append(p)
	fill.call("")
	search.text_changed.connect(func(t: String) -> void: fill.call(t))
	var result := [""]
	d.confirmed.connect(func() -> void:
		var s := list.get_selected_items()
		if not s.is_empty():
			result[0] = shown[s[0]])
	list.item_activated.connect(func(i: int) -> void:
		result[0] = shown[i]
		d.hide())
	if paths.is_empty():
		list.add_item("В art/%s/ и art/common/ пока нет картинок — перетащите PNG из проводника в окно." % level.epoch)
	await _run_dialog(d)
	return result[0]


func _run_dialog(d: Window) -> void:
	_dialog_open = true
	ui_root.add_child(d)
	d.popup_centered()
	var done := [false]
	d.visibility_changed.connect(func() -> void:
		if not d.visible and not done[0]:
			done[0] = true
			_dialog_closed.emit.call_deferred(0))   # отложенно: «confirmed» приходит уже после скрытия
	await _dialog_closed
	d.queue_free()
	_dialog_open = false
