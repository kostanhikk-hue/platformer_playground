extends Node2D
## Уровень в игре: загружает LevelData, строит его (level_builder), ставит героя, ведёт чекпоинты,
## смерть (падение ниже kill_y, смертельные зоны) и выход.
## Игра: LevelRuntime.requested_path = путь; change_scene_to_file(SCENE).
## Конструктор («Играть отсюда»): создаёт этот узел сам, задаёт level, test_mode и launch_pos —
## поэтому в игре и в проверке из конструктора работает один и тот же код.
##
## Фаза 2 (компоненты):
##   get_component(uid) — объект уровня по uid (для связей); get_path_points(uid) — путь;
##   spawn_object(def_id, pos, props) — создать объект по ходу игры;
##   снимки: при старте и при активации чекпоинта собираются snapshot() всех объектов с reset_on_death,
##   при возрождении героя (сигнал respawned) — restore();
##   взаимодействие (game/components/interaction.gd), темнота уровня, кисть уровня, уведомления карточек,
##   лог событий шины Events (Shift+Tab, только dev).

signal completed

const SCENE := "res://game/level/level_runtime.tscn"
const MAIN_MENU := "res://game/ui/main_menu.tscn"
const PlayerScript := preload("res://game/player/player.gd")
const LevelBuilder := preload("res://game/level/level_builder.gd")
const Catalog := preload("res://game/level/catalog.gd")
const Interaction := preload("res://game/components/interaction.gd")
const Dev := preload("res://core/dev.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const DialogPlayer := preload("res://game/dialog/dialog_player.gd")
const Lines := preload("res://game/dialog/lines_db.gd")

static var requested_path := ""

var level: LevelData
var test_mode := false
var launch_pos := Vector2.ZERO
var has_launch := false
var player
var info: Dictionary = {}
var interaction: Node2D
var brush: Resource            ## кисть уровня (пресет уровня или вкладка «Кисть»)
var _hud: CanvasLayer
var _done_panel: PanelContainer
var _finished := false
var _snapshot: Dictionary = {}  ## uid → снимок
var _spawned: Array = []
var _log_panel: PanelContainer
var _log_label: Label
var _card_box: VBoxContainer
var _hint_label: Label
var _hint_serial := 0
var _ctx: Dictionary = {}
## Фаза 4: сценарий уровня (content/levels/<эпоха>/<id>.gd), реплики, ввод, пресеты.
var level_script: Node = null
var dialog: CanvasLayer
var script_input_lock := false
var presets_applied: Dictionary = {}    ## набор → имя пресета (apply_preset сценария)
var _preset_backup: Dictionary = {}     ## набор → копия значений до первого apply_preset
var deaths := 0
var _death_pending := false


func _ready() -> void:
	if level == null and requested_path != "":
		level = LevelData.load_level(requested_path)
	_build_hud()
	if level == null:
		_message("ui.level.not_found", {"path": requested_path}, "ui.level.to_menu", _to_menu)
		return
	Events.clear_log()
	brush = _level_brush()
	_ctx = {
		"on_checkpoint": _on_checkpoint,
		"on_exit": _on_exit,
		"on_kill": _on_kill,
		"kill_y": level.kill_y,
		"runtime": self,
	}
	info = LevelBuilder.build(level, self, _ctx)
	if level.darkness_enabled:
		var cm := CanvasModulate.new()
		cm.name = "Darkness"
		cm.color = level.darkness_color
		add_child(cm)
	var spawn: Vector2
	if has_launch:
		spawn = launch_pos
	elif info["start"] != null:
		spawn = info["start"]
	else:
		spawn = level.bounds.get_center()
	launch_pos = spawn
	player = PlayerScript.new()
	player.spawn_pos = spawn
	player.position = spawn
	player.kill_y = level.kill_y
	player.camera_bounds = level.bounds
	add_child(player)
	if brush != null:
		player.br = brush
	player.respawned.connect(_on_respawned)
	player.cam.make_current()
	player.cam.reset_smoothing()
	interaction = Interaction.new()
	interaction.player = player
	add_child(interaction)
	player.died.connect(_on_death)
	player.fell.connect(_on_death)
	Lines.reload()
	dialog = DialogPlayer.new()
	add_child(dialog)
	if not level.known_errors.is_empty():
		_banner("В уровне есть ошибки (%d): %s" % [level.known_errors.size(), level.known_errors[0]])  # loc: dev
	_load_script()
	take_snapshot.call_deferred()
	_start_script.call_deferred()


# ------------------------------------------------------------ сценарий уровня

## Путь сценария: рядом с уровнем, то же имя, .gd.
static func script_path_for(lv: LevelData) -> String:
	return LevelData.path_for(lv.epoch, lv.id).get_basename() + ".gd"


## Сценарий загружается без кэша: агент поправил файл — F5 — новое поведение. Ошибка — уровень без сценария.
func _load_script() -> void:
	var path := script_path_for(level)
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var sc = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (sc is Script) or not sc.can_instantiate():
		_script_error("Сценарий %s не загрузился (ошибка в коде) — уровень работает без него" % path)
		return
	var inst = sc.new()
	if not (inst is Node) or not inst.has_method("on_zone_enter"):
		_script_error("Сценарий %s должен начинаться с: extends \"res://game/level/level_script.gd\"" % path)
		if inst is Node:
			inst.free()
		return
	level_script = inst
	level_script.name = "LevelScript"
	level_script.runtime = self
	level_script.level = level
	level_script.player = player
	level_script.dialog = dialog
	add_child(level_script)
	Events.event.connect(_on_bus_event)
	Events.log_line("script", "сценарий загружен: " + path.get_file())


func _script_error(msg: String) -> void:
	push_error(msg)
	Events.log_line("script", "ОШИБКА: " + msg)
	if Dev.enabled():
		_banner(msg)


func _start_script() -> void:
	if level_script != null:
		level_script.on_level_start()


func _on_bus_event(uid: String, ev: String, data: Dictionary) -> void:
	if level_script != null and is_instance_valid(level_script):
		level_script.on_event(uid, ev, data)


## Зона-триггер сообщила о входе / выходе героя.
func zone_event(uid: String, entered: bool) -> void:
	Events.log_line(uid, "вход" if entered else "выход")
	if level_script != null:
		level_script._zone(uid, entered)


func _on_death() -> void:
	deaths += 1
	_death_pending = true


# ------------------------------------------------------------ пресеты механик (сценарий)

func _preset_file(set_key: String, preset: String) -> String:
	var dir: String = Params.REGISTRY.get(set_key, {}).get("presets", "")
	if dir == "":
		return ""
	var want := preset.strip_edges().to_lower().replace(" ", "_")
	var rx := RegEx.create_from_string("^\\d+_")
	for f in DirAccess.get_files_at(dir):
		var fname := f.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var base := fname.get_basename().to_lower()
		if base == want or rx.sub(base, "") == want:
			return dir.path_join(fname)
	return ""


func apply_preset(set_key: String, preset: String) -> bool:
	if not Params.REGISTRY.has(set_key):
		_script_error("apply_preset: нет набора параметров «%s»" % set_key)
		return false
	var path := _preset_file(set_key, preset)
	if path == "":
		_script_error("apply_preset: нет пресета «%s» в наборе %s" % [preset, set_key])
		return false
	var src = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var res: Resource = Params.get_res(set_key)
	if not _preset_backup.has(set_key):
		_preset_backup[set_key] = res.duplicate()
	_copy_params(src, res)
	presets_applied[set_key] = preset
	return true


func reset_preset(set_key: String) -> void:
	if _preset_backup.has(set_key):
		_copy_params(_preset_backup[set_key], Params.get_res(set_key))
	presets_applied.erase(set_key)


## Откат: наборы в состояние снимка (какие пресеты были применены).
func restore_presets(applied: Dictionary) -> void:
	for k in _preset_backup.keys():
		if applied.has(k):
			if presets_applied.get(k, "") != applied[k]:
				reset_preset(k)
				apply_preset(k, applied[k])
		else:
			reset_preset(k)


func _copy_params(from: Resource, to: Resource) -> void:
	if from == null or to == null:
		return
	for pr in to.get_property_list():
		if pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and pr["name"] in from:
			to.set(pr["name"], from.get(pr["name"]))


func _exit_tree() -> void:
	if level_script != null and is_instance_valid(level_script):
		level_script.interrupt()
	if Events.event.is_connected(_on_bus_event):
		Events.event.disconnect(_on_bus_event)
	for k in _preset_backup.keys():
		_copy_params(_preset_backup[k], Params.get_res(k))
	_preset_backup.clear()


func _level_brush() -> Resource:
	if level.brush_preset != "" and ResourceLoader.exists(level.brush_preset):
		var r = ResourceLoader.load(level.brush_preset, "", ResourceLoader.CACHE_MODE_IGNORE)
		if r != null:
			return r
	return Params.get_res("brush")


## Кисть для объекта: свой пресет (путь) или кисть уровня.
func brush_for(preset: String) -> Resource:
	if preset != "" and ResourceLoader.exists(preset):
		var r = load(preset)
		if r != null:
			return r
	return brush if brush != null else Params.get_res("brush")


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _process(_delta: float) -> void:
	var ts: float = maxf(Params.world.time_scale, 0.01)
	if not is_equal_approx(ts, Fx.base_scale):
		Fx.set_base_scale(ts)
	if player != null and not _finished:
		player.input_locked = _typing() or script_input_lock
	if _log_panel != null and _log_panel.visible:
		_log_label.text = "ЛОГ СОБЫТИЙ (Shift+Tab — скрыть)\n" + (Events.log_text() if not Events.log.is_empty() else "— пока пусто —")  # loc: dev


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _typing():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and event.shift_pressed:
		if Dev.enabled():
			_toggle_log()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset"):
		if test_mode:
			player.spawn_pos = launch_pos   # в конструкторе R — на точку запуска
		player.reset(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("back") and not test_mode:
		_to_menu()


# ------------------------------------------------------------ объекты

func get_component(uid: String) -> Node:
	var n = info.get("objects", {}).get(uid, null)
	if n != null and is_instance_valid(n):
		return n
	return null


func get_path_points(uid: String) -> Dictionary:
	return info.get("paths", {}).get(uid, {})


## Создать объект каталога по ходу игры (результат «Создать объект» рисуемого контура). Возвращает узел.
func spawn_object(def_id: String, pos: Vector2, props: Dictionary = {}) -> Node:
	var def := Catalog.get_def(def_id)
	if def == null:
		push_warning("spawn_object: нет «%s» в каталоге" % def_id)
		return null
	var o := PlacedObject.new()
	o.def_id = def_id
	o.uid = "%s_spawn%d" % [def_id, _spawned.size() + 1]
	o.position = pos
	o.layer = def.default_layer
	o.props = props.duplicate(true)
	var n := LevelBuilder.make_object(null, o, def, _built_ctx())
	if n == null:
		return null
	add_child(n)
	info["objects"][o.uid] = n
	_spawned.append(n)
	return n


func _built_ctx() -> Dictionary:
	var c := _ctx.duplicate()
	c["paths"] = info.get("paths", {})
	c["level"] = level
	return c


func despawn(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	info["objects"].erase(String(n.name))
	_spawned.erase(n)
	n.queue_free()


## Конструктор: свойства экземпляра поменяли во время «Играть отсюда» — применить сразу.
func apply_object_props(o: PlacedObject) -> void:
	var n := get_component(o.uid)
	if n == null:
		return
	if n.has_method("apply_props"):
		n.apply_props(Catalog.make_props(Catalog.get_def(o.def_id), o), o)
	elif n.has_method("setup_object"):
		n.setup_object(Catalog.make_props(Catalog.get_def(o.def_id), o), _built_ctx())


# ------------------------------------------------------------ снимки и смерть

func _snapshot_nodes() -> Array:
	var out: Array = []
	for uid in info.get("objects", {}):
		var n = info["objects"][uid]
		if n != null and is_instance_valid(n) and n.has_method("snapshot"):
			if not n.has_method("resets_on_death") or n.resets_on_death():
				out.append([uid, n])
	if level_script != null and is_instance_valid(level_script):
		out.append(["__script", level_script])
	return out


## Снимок всех объектов с «Сбрасывать при смерти» (старт уровня и активация чекпоинта).
func take_snapshot() -> void:
	_snapshot.clear()
	for pair in _snapshot_nodes():
		_snapshot[pair[0]] = pair[1].snapshot()


func _on_respawned() -> void:
	# штрихи героя при смерти удаляются (и при падении, и при уроне)
	for s in player.strokes + player.waves:
		if is_instance_valid(s):
			s.queue_free()
	player.strokes.clear()
	player.waves.clear()
	if level_script != null and is_instance_valid(level_script):
		level_script.interrupt()
	for pair in _snapshot_nodes():
		if _snapshot.has(pair[0]):
			pair[1].restore(_snapshot[pair[0]])
	if _death_pending:
		_death_pending = false
		Events.log_line("player", "смерть №%d" % deaths)
		if level_script != null and is_instance_valid(level_script):
			level_script.on_player_died(deaths)


## Чекпоинт-компонент активирован: новая точка возрождения + снимок.
func checkpoint_reached(cp: Node, point: Vector2) -> void:
	for other in get_tree().get_nodes_in_group("level_checkpoint"):
		if other != cp and other.has_method("set_current"):
			other.set_current(false)
	if player != null:
		player.set_respawn_point(point)
	take_snapshot.call_deferred()
	if level_script != null:
		level_script.on_checkpoint.call_deferred(cp.get("uid") if cp.get("uid") != null else String(cp.name))


func _on_checkpoint(point: Vector2) -> void:
	if player != null:
		player.spawn_pos = point
	take_snapshot.call_deferred()


func _on_kill() -> void:
	if player != null:
		player.fell.emit()
		player.reset(false)   # как падение ниже kill_y: на последний чекпоинт или на старт


func _on_exit() -> void:
	if _finished:
		return
	_finished = true
	player.input_locked = true
	completed.emit()
	if test_mode:
		_message("ui.level.complete", {}, "", Callable())
	else:
		_message("ui.level.complete", {}, "ui.level.to_menu", _to_menu)


func _to_menu() -> void:
	Fx.set_base_scale(1.0)
	get_tree().change_scene_to_file(MAIN_MENU)


# ------------------------------------------------------------ интерфейс

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 50
	add_child(_hud)
	var help := Label.new()
	if test_mode:
		help.text = "R — на точку запуска   |   E — взаимодействие   |   Tab — панель   |   Shift+Tab — лог событий   |   F2 — инспектор   |   Esc / F5 — назад к правке"  # loc: dev
	else:
		Loc.bind(help, "hint.level_controls")   # клавиши подставляются текущие (клавиатура / геймпад)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_hud.add_child(help)
	# внизу во всю ширину: длинный перевод переносится вверх, а не уходит за край экрана
	help.anchor_left = 0.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 12.0
	help.offset_right = -12.0
	help.offset_bottom = -6.0
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.anchor_left = 0.15
	_hint_label.anchor_right = 0.85
	_hint_label.offset_top = 64.0
	_hint_label.visible = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hint_label)
	if level != null:
		var t := Label.new()
		var title_key := "level.%s.title" % level.id
		if Loc.has(title_key):
			t.text = title_key
		else:
			t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			t.text = level.title   # название из конструктора, пока нет ключа level.<id>.title
		t.position = Vector2(12, 8)
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
		_hud.add_child(t)
	_card_box = VBoxContainer.new()
	_card_box.position = Vector2(1280 - 360, 12)
	_card_box.add_theme_constant_override("separation", 6)
	_hud.add_child(_card_box)


func _toggle_log() -> void:
	if _log_panel == null:
		_log_panel = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.08, 0.88)
		sb.set_content_margin_all(8)
		_log_panel.add_theme_stylebox_override("panel", sb)
		_log_panel.position = Vector2(12, 60)
		_log_panel.custom_minimum_size = Vector2(620, 0)
		_log_label = Label.new()
		_log_label.add_theme_font_size_override("font_size", 12)
		_log_panel.add_child(_log_label)
		_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_log_panel)
		_log_panel.visible = false
	_log_panel.visible = not _log_panel.visible


## Уведомление о карточке в углу: картинка, название, «где и когда». Игра не останавливается.
## card — запись из content/dialog/cards.csv (id, image); тексты — ключи card.<id>.title / where / when.
func show_card(card: Dictionary) -> void:
	var op: Resource = Params.get_res("objects")
	var id := str(card.get("id", ""))
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	sb.border_color = Color(1, 0.8, 0.4, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(op.card_notify_width, 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	var img_path: String = card.get("image", "")
	if img_path != "" and ArtLoader.exists(img_path):
		var tex := ArtLoader.load_texture(img_path)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(64, 64)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title_key := "card.%s.title" % id
	var head := Label.new()
	Loc.bind(head, "ui.card.new", {"title": Loc.ref(title_key if Loc.has(title_key) else "ui.card.untitled")})
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(head)
	if Loc.has("card.%s.where" % id) or Loc.has("card.%s.when" % id):
		var sub := Label.new()
		Loc.bind(sub, "ui.card.where_when", {"where": Loc.ref("card.%s.where" % id), "when": Loc.ref("card.%s.when" % id)})
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(sub)
	_card_box.position.x = get_viewport().get_visible_rect().size.x - op.card_notify_width - 16
	_card_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(maxf(op.card_notify_time, 0.1))
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Подсказка на экране (ключ из content/i18n/hints.csv). sec > 0 — скрыть через sec с, 0 — до hide_hint().
## Клавиши в подсказке ({jump}, {move}) — текущие, обновляются при смене устройства и языка.
func show_hint(key: String, args: Dictionary = {}, sec: float = 0.0) -> void:
	_hint_serial += 1
	var serial := _hint_serial
	Loc.bind(_hint_label, key, args)
	_hint_label.visible = true
	if sec > 0.0:
		await get_tree().create_timer(sec, false).timeout
		if serial == _hint_serial and is_instance_valid(_hint_label):
			hide_hint()


func hide_hint() -> void:
	_hint_serial += 1
	if _hint_label != null:
		_hint_label.visible = false


func _banner(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(12, 34)
	l.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_hud.add_child(l)


## Экран-сообщение по центру: key — ключ из ui.csv, button — ключ подписи кнопки (пусто — без кнопки).
func _message(key: String, args: Dictionary, button: String, cb: Callable) -> void:
	_done_panel = PanelContainer.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(center)
	center.add_child(_done_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_done_panel.add_child(box)
	var l := Label.new()
	Loc.bind(l, key, args)
	l.add_theme_font_size_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	if button != "":
		var b := Button.new()
		b.text = button
		b.pressed.connect(cb)
		box.add_child(b)
		b.grab_focus.call_deferred()
