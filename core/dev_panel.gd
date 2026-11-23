extends CanvasLayer
## loc: dev-file — инструмент разработчика, текст не локализуется
## Панель параметров на любой сцене с героем (автозагрузка DevPanel). Работает только в dev-сборке.
## Tab — показать/скрыть. Плейграунды держат свою панель сами (у них есть param_keys()), их не трогаем.
## Вкладки — все наборы героя и «Мир».

const ParamPanel := preload("res://core/param_panel.gd")
const Dev := preload("res://core/dev.gd")
const KEYS := ["movement", "attack", "ink", "wave", "brush", "dummy", "camera", "paintable", "coverage", "interact", "light", "objects", "subtitle", "world"]

var panel: Control
var _active := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = Dev.enabled()


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _scene_has_own_panel() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.has_method("param_keys")


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _process(_delta: float) -> void:
	if not _active:
		return
	var pl := _player()
	if pl == null or _scene_has_own_panel():
		if panel != null and panel.visible:
			panel.visible = false
		return
	if panel != null and panel.visible:
		pl.input_locked = _typing()
	if not _typing() and Input.is_action_just_pressed("toggle_ui") and not Input.is_key_pressed(KEY_SHIFT):
		_toggle(pl)


func _toggle(pl: Node) -> void:
	if panel == null:
		panel = ParamPanel.new()
		panel.position = Vector2(8, 8)
		add_child(panel)
		var entries := []
		for k in KEYS:
			entries.append(Params.entry(k))
		panel.build(entries)
		panel.add_footer_button("Скрыть (Tab)", func() -> void: panel.visible = false)
		panel.visible = false
	panel.visible = not panel.visible
	if not panel.visible:
		pl.input_locked = false
		get_viewport().gui_release_focus()


## Клик мимо панели снимает курсор с поля ввода.
func _unhandled_input(event: InputEvent) -> void:
	if panel != null and panel.visible and event is InputEventMouseButton and event.pressed and _typing():
		get_viewport().gui_release_focus()
