extends "res://core/playground_base.gd"
## Полигон движения: бег, инерция, лёд, прыжки, пропасти, стены.

func title() -> String:
	return "ДВИЖЕНИЕ"

func grid_range() -> Vector2i:
	return Vector2i(-640, 6000)

func param_keys() -> Array:
	return ["movement", "camera"]


func build_level() -> void:
	var floor_col := Color("#3b4252")
	var ice_col := Color("#5aa9c9")
	var plat_col := Color("#4c566a")

	block(Rect2(-640, -600, 40, 1400), floor_col)
	block(Rect2(-600, GROUND_Y, 1600, 400), floor_col)
	block(Rect2(1000, GROUND_Y, 600, 400), ice_col, true)
	block(Rect2(1600, GROUND_Y, 1000, 400), floor_col)

	block(Rect2(200, GROUND_Y - 4 * T, 128, 16), plat_col, false, true)
	block(Rect2(420, GROUND_Y - 7 * T, 128, 16), plat_col, false, true)
	block(Rect2(640, GROUND_Y - 10 * T, 128, 16), plat_col, false, true)
	block(Rect2(820, GROUND_Y - 3 * T - 32, 96, 32), plat_col)

	var x := 1700
	for i in range(1, 7):
		block(Rect2(x, GROUND_Y - i * T, 64, i * T), plat_col)
		label("%dT\n%dpx" % [i, i * T], Vector2(x + 4, GROUND_Y - i * T - 40))
		x += 120

	x = 2600
	for g in [3, 4, 5, 6, 7, 8]:
		label("%dT" % g, Vector2(x + g * T * 0.5 - 12, GROUND_Y - 30))
		x += g * T
		block(Rect2(x, GROUND_Y, 160, 400), floor_col)
		x += 160

	var sx := x
	block(Rect2(sx, GROUND_Y, 1200, 400), floor_col)
	var wall_h := 14 * T
	block(Rect2(sx + 200, GROUND_Y - wall_h, 32, wall_h - 3 * T), plat_col)
	var rx := sx + 200 + 32 + 5 * T
	block(Rect2(rx, GROUND_Y - wall_h, 32, wall_h), plat_col)
	block(Rect2(rx, GROUND_Y - wall_h, 400, 24), plat_col)

	label("РАЗГОН / ТОРМОЖЕНИЕ  →", Vector2(-560, GROUND_Y - 120), 18)
	label("ONE-WAY платформы", Vector2(200, GROUND_Y - 4 * T - 44))
	label("потолок", Vector2(836, GROUND_Y - 3 * T - 56))
	label("ЛЁД: инерция", Vector2(1020, GROUND_Y - 120), 18)
	label("СТОЛБЫ: что допрыгивает?", Vector2(1700, GROUND_Y - 290), 18)
	label("ПРОПАСТИ (в T)", Vector2(2610, GROUND_Y - 120), 18)
	label("ШАХТА: прыжки от стен", Vector2(sx + 120, GROUND_Y - 100), 18)


func hud_text() -> String:
	var mv: Resource = res("movement")
	var h: float = mv.jump_height
	var t: float = mv.time_to_apex
	var g := 2.0 * h / (t * t)
	var jv := 2.0 * h / t
	var v: Vector2 = player.velocity
	return "Скорость X: %d   Y: %d px/с\nСостояние: %s\nПик горизонтальной скорости: %d px/с\n\nПоследний прыжок:\n%s\n\nРасчёт: гравитация %d px/с², старт прыжка %d px/с\nПри падении: %d px/с²" % [
		int(v.x), int(v.y), player.state, int(player.max_speed_seen),
		player.last_jump_text, int(g), int(jv), int(g * mv.fall_mult)
	]
