extends "res://game/level/level_script.gd"
## Сценарий тестового уровня test_triggers (приёмка фазы 4). Зоны: t_wide, t_hint, t_take_wave; метка m_exit.

# Настройки
const WIDE_ZOOM := 0.7           # насколько отдаляется камера в зоне t_wide (1 — как обычно)
const WIDE_TIME := 1.5           # за сколько секунд отдаляется и возвращается
const SHOW_EXIT_TIME := 1.0      # за сколько секунд камера переходит на выход и обратно
const SHOW_EXIT_HOLD := 2.0      # сколько секунд держит выход в кадре
const HINT_DELAY := 15.0         # сколько стоять в зоне t_hint до каждой следующей подсказки
const BARK_FROM_DEATH := 3       # с какой смерти богиня язвит
const INK_PRESET := "short thick"  # пресет линии после зоны t_take_wave
const MOVE_HINT_TIME := 10.0     # сколько секунд в начале видна подсказка hint.move

var _hint_visit := 0


func on_level_start() -> void:
	show_hint("hint.move", MOVE_HINT_TIME)
	say("goddess_test_001")
	say("goddess_test_002")


func on_zone_enter(id: String) -> void:
	match id:
		"t_wide":
			camera_zoom(WIDE_ZOOM, WIDE_TIME)
		"t_hint":
			_hint_loop()
		"t_take_wave":
			if not flag("wave_taken"):
				set_flag("wave_taken")
				set_ability("wave", false)
				apply_preset("ink", INK_PRESET)
				await say("goddess_test_wave")
				say("hero_test_005")


func on_zone_exit(id: String) -> void:
	if id == "t_wide":
		camera_reset(WIDE_TIME)


func on_event(uid: String, ev: String, _data: Dictionary) -> void:
	if uid == "p_door" and ev == "painted":
		lock_input()
		say("goddess_test_door")
		await camera_show("m_exit", SHOW_EXIT_TIME, SHOW_EXIT_HOLD)
		unlock_input()


func on_player_died(count: int) -> void:
	if count >= BARK_FROM_DEATH:
		bark("goddess_on_death")


## Каждые HINT_DELAY с в зоне — следующая подсказка. Вышел — счёт начинается заново.
func _hint_loop() -> void:
	_hint_visit += 1
	var visit := _hint_visit
	while true:
		await wait(HINT_DELAY)
		if visit != _hint_visit or not in_zone("t_hint"):
			return
		hint("hint_test_door")
