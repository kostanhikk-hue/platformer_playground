extends "res://game/level/level_runtime.gd"
## Плейграунд «Рисуемые объекты»: уровень content/levels/common/pg_paint.tres (его же можно открыть и править
## в конструкторе) + панель параметров (Tab) + HUD: состояние ближайшего объекта и последние события шины.
## Выход из «рисуемой двери» возвращает в начало полигона. Esc — меню разработки.

const PG_PATH := "res://content/levels/common/pg_paint.tres"
const ParamPanel := preload("res://core/param_panel.gd")
const DEV_MENU := "res://editor/launcher.tscn"

var panel
var hud_label: Label
var ink_bar: ProgressBar


## Вкладки панели (DevPanel видит этот метод и не открывает свою).
func param_keys() -> Array:
	return ["paintable", "coverage", "interact", "light", "objects", "ink", "wave", "brush", "world"]


func _ready() -> void:
	if level == null:
		level = LevelData.load_level(PG_PATH)
		requested_path = PG_PATH
	super()
	if level == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	panel = ParamPanel.new()
	panel.position = Vector2(8, 8)
	layer.add_child(panel)
	var entries := []
	for k in param_keys():
		entries.append(Params.entry(k))
	panel.build(entries)
	panel.add_footer_button("Респавн (R)", func() -> void: player.reset(true))
	panel.add_footer_button("← В меню (Esc)", _to_menu)
	panel.visible = false
	hud_label = Label.new()
	hud_label.position = Vector2(830, 40)
	hud_label.add_theme_font_size_override("font_size", 13)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(hud_label)
	ink_bar = ProgressBar.new()
	ink_bar.position = Vector2(830, 14)
	ink_bar.size = Vector2(300, 16)
	ink_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.5, 0.16)
	ink_bar.add_theme_stylebox_override("fill", fill)
	_hud.add_child(ink_bar)


func _process(delta: float) -> void:
	super(delta)
	if player == null or hud_label == null:
		return
	if not _typing() and Input.is_action_just_pressed("toggle_ui") and not Input.is_key_pressed(KEY_SHIFT):
		panel.visible = not panel.visible
	ink_bar.max_value = player.get_max_ink()
	ink_bar.value = player.get_ink()
	hud_label.text = _hud_text()


func _hud_text() -> String:
	var pp: Vector2 = player.global_position
	var best: Node = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("component"):
		if not n.has_method("debug_text") or not n.is_inside_tree() or n.get_parent() != self:
			continue
		var at: Vector2 = n.interact_point(pp) if n.has_method("interact_point") else n.global_position
		var d := at.distance_to(pp)
		if d < bd:
			bd = d
			best = n
	var s := "ОХРА %d / %d\n\nБЛИЖАЙШИЙ (%d px):\n%s" % [int(player.get_ink()), int(player.get_max_ink()), int(bd), best.debug_text() if best != null else "—"]
	s += "\n\nСОБЫТИЯ (Shift+Tab — весь лог):\n" + (Events.log_text(7) if not Events.log.is_empty() else "—")
	return s


## Выход «рисуемой двери» — обратно в начало полигона.
func _on_exit() -> void:
	player.spawn_pos = info["start"] if info.get("start") != null else launch_pos
	player.reset(true)
	_banner("Выход пройден — снова в начале полигона")


func _to_menu() -> void:
	Fx.set_base_scale(1.0)
	get_tree().change_scene_to_file(DEV_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not _typing():
		_to_menu()
		get_viewport().set_input_as_handled()
		return
	super(event)
