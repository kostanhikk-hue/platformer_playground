extends RefCounted
## Горячие клавиши конструктора — отдельный набор действий ввода (как GameInput, но только для editor/).
## Клавиши физические: работают при любой раскладке (в том числе русской).
## Проверка в коде: event.is_action_pressed(имя, false, true) — с точным совпадением модификаторов,
## чтобы Ctrl+Z, Z и Shift+F5 / F5 не путались.

const NONE := 0
const CTRL := 1
const SHIFT := 2
const ALT := 4

## имя: [[клавиша, модификаторы], ...]
const ACTIONS := {
	"ed_select": [[KEY_V, NONE]],
	"ed_body": [[KEY_P, NONE]],
	"ed_platform": [[KEY_N, NONE]],
	"ed_wall": [[KEY_W, NONE]],
	"ed_block": [[KEY_B, NONE]],
	"ed_kill": [[KEY_K, NONE]],
	"ed_path": [[KEY_L, NONE]],
	"ed_zone": [[KEY_Z, NONE]],
	"ed_marker": [[KEY_M, NONE]],
	"ed_links": [[KEY_T, NONE]],
	"ed_inspector_play": [[KEY_F2, NONE]],
	"ed_finish": [[KEY_ENTER, NONE], [KEY_KP_ENTER, NONE]],
	"ed_backspace": [[KEY_BACKSPACE, NONE]],
	"ed_cancel": [[KEY_ESCAPE, NONE]],
	"ed_grid": [[KEY_G, NONE]],
	"ed_collision": [[KEY_C, NONE]],
	"ed_play": [[KEY_F5, NONE]],
	"ed_play_cursor": [[KEY_F5, SHIFT]],
	"ed_player_view": [[KEY_F6, NONE]],
	"ed_undo": [[KEY_Z, CTRL]],
	"ed_redo": [[KEY_Y, CTRL], [KEY_Z, CTRL | SHIFT]],
	"ed_copy": [[KEY_C, CTRL]],
	"ed_paste": [[KEY_V, CTRL]],
	"ed_duplicate": [[KEY_D, CTRL]],
	"ed_delete": [[KEY_DELETE, NONE]],
	"ed_flip_h": [[KEY_X, NONE]],
	"ed_flip_v": [[KEY_Y, NONE]],
	"ed_rotate": [[KEY_R, NONE]],
	"ed_save": [[KEY_S, CTRL]],
	"ed_focus": [[KEY_F, NONE]],
	"ed_home": [[KEY_HOME, NONE]],
	"ed_zoom_reset": [[KEY_0, CTRL], [KEY_KP_0, CTRL]],
	"ed_left": [[KEY_LEFT, NONE]],
	"ed_right": [[KEY_RIGHT, NONE]],
	"ed_up": [[KEY_UP, NONE]],
	"ed_down": [[KEY_DOWN, NONE]],
	"ed_left_big": [[KEY_LEFT, SHIFT]],
	"ed_right_big": [[KEY_RIGHT, SHIFT]],
	"ed_up_big": [[KEY_UP, SHIFT]],
	"ed_down_big": [[KEY_DOWN, SHIFT]],
	"ed_pan": [[KEY_SPACE, NONE]],
}

## Подписи для подсказок в строке состояния.
const KEY_TEXT := {
	"ed_select": "V", "ed_body": "P", "ed_platform": "N", "ed_wall": "W", "ed_block": "B", "ed_kill": "K",
	"ed_grid": "G", "ed_collision": "C", "ed_play": "F5", "ed_play_cursor": "Shift+F5", "ed_player_view": "F6",
	"ed_path": "L", "ed_links": "T",
}


static func register() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k[0]
			e.ctrl_pressed = (k[1] & CTRL) != 0
			e.shift_pressed = (k[1] & SHIFT) != 0
			e.alt_pressed = (k[1] & ALT) != 0
			InputMap.action_add_event(action, e)


static func pressed(event: InputEvent, action: String, echo: bool = false) -> bool:
	return event.is_action_pressed(action, echo, true)


## Зажат ли модификатор (для привязок при рисовании — это не горячие клавиши).
static func shift() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


static func alt() -> bool:
	return Input.is_key_pressed(KEY_ALT)


static func ctrl() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
