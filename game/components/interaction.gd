extends Node2D
## Взаимодействие (действие ввода interact: E / правый бампер). Создаётся уровнем (level_runtime).
## Каждый кадр ищет ближайший объект группы "interactive" в радиусе interact_radius (вкладка «Взаимодействие»),
## подсвечивает его, рисует значок клавиши и передаёт нажатие / удержание / отпускание:
##   on_interact_pressed(player), on_interact_held(player, delta), on_interact_released(player).
## Объект сам решает, можно ли с ним взаимодействовать: can_interact(player), точка — interact_point(from).
## Пока курсор стоит в поле панели или инспектора (или герой заблокирован), взаимодействие не срабатывает.

var player: Node2D
var current: Node = null
var holding := false
var _ip: Resource


func _ready() -> void:
	_ip = Params.get_res("interact")
	z_index = 3500
	z_as_relative = false
	top_level = true


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _physics_process(delta: float) -> void:
	var blocked: bool = player == null or not is_instance_valid(player) or player.dead or player.input_locked or _typing()
	var best: Node = null
	if not blocked:
		var r: float = _ip.interact_radius
		var best_d := INF
		var pp: Vector2 = player.global_position
		for n in get_tree().get_nodes_in_group("interactive"):
			if not n.is_inside_tree() or not n.has_method("can_interact") or not n.can_interact(player):
				continue
			var d: float = (n.interact_point(pp) as Vector2).distance_to(pp)
			if d <= r and d < best_d:
				best_d = d
				best = n
	if holding and best != current:
		_release()
	if best != current:
		if current != null and is_instance_valid(current):
			current.highlighted = false
			current.queue_redraw()
		current = best
		if current != null:
			current.highlighted = true
			current.queue_redraw()
	if current != null and not blocked:
		if Input.is_action_just_pressed("interact"):
			holding = true
			current.on_interact_pressed(player)
		elif holding and Input.is_action_pressed("interact"):
			current.on_interact_held(player, delta)
		elif holding:
			_release()
	elif holding:
		_release()
	queue_redraw()


func _release() -> void:
	holding = false
	if current != null and is_instance_valid(current):
		current.on_interact_released(player)


func _draw() -> void:
	if current == null or not is_instance_valid(current) or player == null:
		return
	var p: Vector2 = current.interact_point(player.global_position) - Vector2(0, _ip.icon_offset_y)
	var s: float = _ip.icon_size
	var ready: bool = current.interact_ready(player)
	var col: Color = _ip.icon_color if ready else _ip.icon_off_color
	var r := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
	draw_rect(r, Color(0, 0, 0, 0.65))
	draw_rect(r, col, false, 2.0)
	var f := ThemeDB.fallback_font
	var fs := int(s * 0.7)
	# пусто — текущая клавиша «Взаимодействия» (E или RB — по последнему устройству)
	var key: String = _ip.key_text if _ip.key_text != "" else GameInput.key_label("interact")
	var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(p.x - tw * 0.5, p.y + fs * 0.35), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if holding:
		draw_arc(p, s * 0.8, 0, TAU, 24, Color(col, 0.6), 2.0)
