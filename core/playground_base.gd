extends Node2D
## loc: dev-file — инструмент разработчика, текст не локализуется
## Общая база всех плейграундов: герой, панель настроек, HUD, сетка, возврат в меню.
## Новый плейграунд: наследуйся от этого файла и переопредели функции из блока «переопределяется».
## Параметры берутся из реестра Params (core/params.gd) — один и тот же ресурс у панели, героя и врагов.

const T := 32            ## размер тайла, px (сетка и подписи «N T»)
const GROUND_Y := 600    ## уровень пола на полигонах

const PlayerScript := preload("res://game/player/player.gd")
const ParamPanel := preload("res://core/param_panel.gd")
const MENU_SCENE := "res://editor/launcher.tscn"   ## меню разработки (плейграунды живут только в dev-сборке)

var player
var panel
var hud: Label
var hud_layer: CanvasLayer


# ---------------- переопределяется ----------------
func title() -> String:
	return "Playground"

func spawn_point() -> Vector2:
	return Vector2(100, 580)

## Ширина сетки по X: от, до.
func grid_range() -> Vector2i:
	return Vector2i(-640, 3000)

func build_level() -> void:
	pass

## Какие вкладки показать на панели — ключи из Params.REGISTRY, по порядку. «world» добавляется сам.
func param_keys() -> Array:
	return []

func hud_text() -> String:
	return ""

func help_text() -> String:
	return "A/D, ←/→ — бег   |   Пробел/W/↑ — прыжок   |   J/X — удар   |   ПКМ/K/C — линия   |   ЛКМ/L/V — волна (держи — заряд)   |   R — респавн   |   Tab — панель   |   Esc — меню"

func after_ready() -> void:
	pass
# --------------------------------------------------


func _ready() -> void:
	build_level()

	player = PlayerScript.new()
	player.spawn_pos = spawn_point()
	player.position = spawn_point()
	add_child(player)

	_build_ui()
	after_ready()
	queue_redraw()


## Ресурс параметров по ключу (короткая запись для наследников).
func res(key: String) -> Resource:
	return Params.get_res(key)


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not _typing():
		_to_menu()


## Клик мимо панели снимает курсор с поля ввода — иначе герой так и остаётся «заблокированным».
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _typing():
		get_viewport().gui_release_focus()


func _to_menu() -> void:
	Fx.set_base_scale(1.0)
	get_tree().change_scene_to_file(MENU_SCENE)


func _process(_delta: float) -> void:
	var typing := _typing()
	player.input_locked = typing
	if not typing:
		if Input.is_action_just_pressed("reset"):
			player.reset(true)
		if Input.is_action_just_pressed("toggle_ui"):
			panel.visible = not panel.visible
	var ts: float = maxf(Params.world.time_scale, 0.01)
	if not is_equal_approx(ts, Fx.base_scale):
		Fx.set_base_scale(ts)
	hud.text = hud_text()


# ------------------------------------------------------------ уровень

## Твёрдый прямоугольник. ice — скользкий (meta "ice"), one_way — проходим снизу.
func block(r: Rect2, col: Color, ice: bool = false, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.one_way_collision = one_way
	body.add_child(cs)
	var h := r.size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	poly.color = col
	body.add_child(poly)
	var edge := Polygon2D.new()
	var eh := minf(4.0, r.size.y)
	edge.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, -h.y + eh), Vector2(-h.x, -h.y + eh)])
	edge.color = col.lightened(0.35)
	body.add_child(edge)
	if ice:
		body.set_meta("ice", true)
	add_child(body)
	return body


## Подпись в мире.
func label(text: String, pos: Vector2, size: int = 13) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	add_child(l)


func _draw() -> void:
	var gr := grid_range()
	var minor := Color(1, 1, 1, 0.04)
	var major := Color(1, 1, 1, 0.1)
	for gx in range(gr.x, gr.y, T):
		draw_line(Vector2(gx, -600), Vector2(gx, 800), major if gx % (T * 5) == 0 else minor)
	for gy in range(-600, 800, T):
		draw_line(Vector2(gr.x, gy), Vector2(gr.y, gy), major if (gy - GROUND_Y) % (T * 5) == 0 else minor)
	var font := ThemeDB.fallback_font
	for gx in range(0, gr.y, T * 5):
		draw_string(font, Vector2(gx + 2, GROUND_Y + 18), "%d T" % (gx / T), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	for n in range(1, 15):
		draw_string(font, Vector2(gr.x + 4, GROUND_Y - n * T - 2), "%d T" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.35))


# ------------------------------------------------------------ интерфейс

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = ParamPanel.new()
	panel.position = Vector2(8, 8)
	layer.add_child(panel)
	var entries := []
	for k in param_keys() + ["world"]:
		entries.append(Params.entry(k))
	panel.build(entries)
	panel.add_footer_button("Респавн (R)", func() -> void: player.reset(true))
	panel.add_footer_button("← В меню (Esc)", _to_menu)

	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud = Label.new()
	hud.position = Vector2(830, 10)
	hud.add_theme_font_size_override("font_size", 14)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	hud_layer.add_child(hud)

	var help := Label.new()
	help.text = help_text()
	help.position = Vector2(420, 696)
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hud_layer.add_child(help)

	var title_l := Label.new()
	title_l.text = title()
	title_l.position = Vector2(420, 8)
	title_l.add_theme_font_size_override("font_size", 16)
	title_l.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	hud_layer.add_child(title_l)
