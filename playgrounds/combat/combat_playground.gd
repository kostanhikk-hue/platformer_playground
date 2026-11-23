extends "res://core/playground_base.gd"
## Полигон боя: удар, урон, неуязвимость, линия-охра, манекены (стоит / патруль / таран).

const EnemyScript := preload("res://game/enemy/enemy_dummy.gd")

var hp_bar: ProgressBar
var ink_bar: ProgressBar


func title() -> String:
	return "БОЙ, ЛИНИЯ И ВОЛНА"

func spawn_point() -> Vector2:
	return Vector2(0, 580)

func param_keys() -> Array:
	return ["wave", "ink", "attack", "brush", "dummy", "movement", "camera"]


func build_level() -> void:
	var floor_col := Color("#3b4252")
	var plat_col := Color("#4c566a")
	block(Rect2(-640, -600, 40, 1400), floor_col)
	block(Rect2(-600, GROUND_Y, 2000, 400), floor_col)      # арена
	block(Rect2(1800, GROUND_Y, 1000, 400), floor_col)      # за пропастью
	block(Rect2(2800, -600, 40, 1400), floor_col)
	# высокий уступ: допрыгнуть можно только с помощью штриха
	block(Rect2(120, GROUND_Y - 8 * T, 240, 24), plat_col)

	label("МАНЕКЕН: стоит\n(бей, смотри урон и отброс)", Vector2(380, GROUND_Y - 130))
	label("ПАТРУЛЬ\n(бей в движении)", Vector2(800, GROUND_Y - 130))
	label("ТАРАН: жёлтый — замах, синий — окно уязвимости ×2", Vector2(1060, GROUND_Y - 150))
	label("ПРОПАСТЬ 400 px: перекрой штрихами →", Vector2(1420, GROUND_Y - 120), 16)
	# низкий уступ: взбеги по волне (ЛКМ) и прыгни
	block(Rect2(-250, GROUND_Y - 6 * T, 190, 24), plat_col)
	label("УСТУП 6T: встань слева у стены,\nЛКМ вправо → взбеги по волне и прыгни", Vector2(-300, GROUND_Y - 6 * T - 70))
	label("УСТУП 8T: нужен штрих-платформа", Vector2(110, GROUND_Y - 8 * T - 80), 14)
	label("ЗА ПРОПАСТЬЮ: ещё один таран", Vector2(1860, GROUND_Y - 150), 16)


func after_ready() -> void:
	_spawn_dummy(Vector2(450, 570), 0, 0.0)
	_spawn_dummy(Vector2(900, 570), 1, -1.0)
	_spawn_dummy(Vector2(1230, 570), 2, -1.0)
	_spawn_dummy(Vector2(240, GROUND_Y - 8 * T - 30), 0, 0.0)
	_spawn_dummy(Vector2(2300, 570), 2, -1.0)

	hp_bar = _bar(Vector2(420, 34), Color(0.85, 0.25, 0.3), "HP")
	ink_bar = _bar(Vector2(420, 58), Color(0.85, 0.5, 0.16), "ОХРА")


func _spawn_dummy(pos: Vector2, behavior: int, contact: float) -> void:
	var e := EnemyScript.new()
	e.behavior_override = behavior
	e.contact_override = contact
	e.position = pos
	add_child(e)


func _bar(pos: Vector2, col: Color, text: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.custom_minimum_size = Vector2(300, 18)
	b.size = Vector2(300, 18)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("fill", fill)
	hud_layer.add_child(b)
	var l := Label.new()
	l.text = text
	l.position = Vector2(pos.x + 308, pos.y - 3)
	l.add_theme_font_size_override("font_size", 12)
	hud_layer.add_child(l)
	return b


func _frames(sec: float) -> int:
	return int(roundf(sec * 60.0))


func hud_text() -> String:
	var a: Resource = res("attack")
	var ink: Resource = res("ink")
	var w: Resource = res("wave")
	if hp_bar:
		hp_bar.max_value = a.max_hp
		hp_bar.value = player.hp
		ink_bar.max_value = ink.max_ink
		ink_bar.value = player.ink_amount
	var total: float = a.windup + a.active + a.recovery
	var v: Vector2 = player.velocity
	return "Скорость X: %d  Y: %d   Состояние: %s\n\nУДАР (кадры при 60 fps)\nзамах %d | активно %d | восстановление %d\nвсего %d кадров = %.2f с\nвзмахов: %d   попаданий: %d\nпоследнее: %s\n\nЛИНИЯ (ПКМ / K / C, держи — заряд, если включён)\nштрихов: %d / %d   охра: %d / %d   цена: %d\n%s\n\nВОЛНА (ЛКМ / L / V, держи — заряд)\nактивных: %d / %d   цена: %d охры\n%s" % [
		int(v.x), int(v.y), player.state,
		_frames(a.windup), _frames(a.active), _frames(a.recovery),
		_frames(total), total,
		player.swings, player.hits_landed, player.last_hit_text,
		player.strokes.size(), ink.max_strokes, int(player.ink_amount), int(ink.max_ink), int(ink.cost), player.ink_status(),
		player.waves.size(), w.max_waves, int(w.ink_cost), player.wave_status(),
	]
