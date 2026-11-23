extends Node
## Регистрирует действия ввода (автозагрузка). Все скрипты используют только имена действий.
## Для подсказок: последнее устройство (клавиатура/мышь или геймпад) и названия назначенных клавиш —
## keys_text("jump") → «Пробел / W». Подсказка «{jump} — прыжок» подставляет их сама (Loc).
## Сигнал input_changed — сменилось устройство или назначение (подсказки перестраиваются).

signal input_changed

## Группы действий для подсказок: {move} → клавиши «влево» и «вправо».
const HINT_GROUPS := {"move": ["left", "right"]}
## Сколько клавиш одного действия показывать в подсказке («Пробел / W», без третьей).
const MAX_KEYS_IN_HINT := 2
## Наклон стика, после которого считаем, что игрок взял геймпад.
const PAD_SWITCH_AXIS := 0.5

const DEVICE_KEYBOARD := "keyboard"
const DEVICE_PAD := "pad"

## Последнее использованное устройство: "keyboard" (клавиатура и мышь) или "pad".
var device := DEVICE_KEYBOARD


func _ready() -> void:
	_key("left", [KEY_A, KEY_LEFT])
	_key("right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_key("attack", [KEY_J, KEY_X])
	_key("ink", [KEY_K, KEY_C])
	_key("wave", [KEY_L, KEY_V])
	_key("reset", [KEY_R])
	_key("toggle_ui", [KEY_TAB])
	_key("back", [KEY_ESCAPE])
	_key("interact", [KEY_E])

	_add("left", _joy_axis(-1.0))
	_add("right", _joy_axis(1.0))
	_add("jump", _joy_btn(JOY_BUTTON_A))
	_add("attack", _joy_btn(JOY_BUTTON_X))
	_add("ink", _joy_btn(JOY_BUTTON_Y))
	_add("wave", _joy_btn(JOY_BUTTON_B))
	_add("interact", _joy_btn(JOY_BUTTON_RIGHT_SHOULDER))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	_add("ink", mb)
	var ml := InputEventMouseButton.new()
	ml.button_index = MOUSE_BUTTON_LEFT
	_add("wave", ml)


func _key(action: String, keys: Array) -> void:
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		_add(action, e)


func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, ev)


func _joy_axis(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _joy_btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


# ================================================================ назначение клавиш

## Заменить клавиши действия (экран управления — позже). Подсказки обновятся сами.
func rebind(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)
	input_changed.emit()


func set_device(d: String) -> void:
	if d != device:
		device = d
		input_changed.emit()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		set_device(DEVICE_KEYBOARD)
	elif event is InputEventJoypadButton and event.pressed:
		set_device(DEVICE_PAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > PAD_SWITCH_AXIS:
		set_device(DEVICE_PAD)


# ================================================================ названия клавиш для подсказок

## Можно ли подставить в подсказку клавиши по этому имени ({jump}, {move}…).
func is_hint_action(name: String) -> bool:
	return HINT_GROUPS.has(name) or (InputMap.has_action(name) and not name.begins_with("ui_"))


## Клавиши действия или группы на текущем устройстве: «Пробел / W», «A / D», «Левый стик».
func keys_text(name: String) -> String:
	var labels := PackedStringArray()
	if HINT_GROUPS.has(name):
		for a in HINT_GROUPS[name]:
			var l := action_labels(a)
			if not l.is_empty() and not l[0] in labels:
				labels.append(l[0])
	else:
		for l in action_labels(name):
			if labels.size() >= MAX_KEYS_IN_HINT:
				break
			labels.append(l)
	if labels.is_empty():
		return Loc.t("ui.key.none")
	return Loc.t("ui.key.separator").join(labels)


## Первая клавиша действия на текущем устройстве (значок «E» над рычагом).
func key_label(action: String) -> String:
	var l := action_labels(action)
	return l[0] if not l.is_empty() else ""


## Названия всех клавиш действия на текущем устройстве (без повторов, по порядку назначения).
## Если на текущем устройстве действие не назначено (например, R на геймпаде) — клавиши другого устройства.
func action_labels(action: String) -> PackedStringArray:
	var out := _labels_for(action, device == DEVICE_PAD)
	if out.is_empty():
		out = _labels_for(action, device != DEVICE_PAD)
	return out


func _labels_for(action: String, pad_events: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		var pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if pad != pad_events:
			continue
		var s := event_label(e)
		if s != "" and not s in out:
			out.append(s)
	return out


## Название одной клавиши. Понятные буквы и цифры — как есть (в раскладке игрока, кириллица —
## по латинской клавише), остальное — ключи ui.key.* из content/i18n/ui.csv.
func event_label(e: InputEvent) -> String:
	if e is InputEventKey:
		var kc: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		var name := OS.get_keycode_string(kc)
		if name.length() == 1 and DisplayServer.get_name() != "headless":
			var local := OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(kc))
			if local.length() == 1 and local.unicode_at(0) < 0x0250:   # латиница, цифры, знаки
				name = local
		if name.length() <= 1:
			return name.to_upper()
		return _named("ui.key." + name.to_lower().replace(" ", "_"), name)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				return _named("ui.key.lmb", "LMB")
			MOUSE_BUTTON_RIGHT:
				return _named("ui.key.rmb", "RMB")
			MOUSE_BUTTON_MIDDLE:
				return _named("ui.key.mmb", "MMB")
		return "M%d" % e.button_index
	if e is InputEventJoypadButton:
		var ids := {JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y",
			JOY_BUTTON_LEFT_SHOULDER: "pad_lb", JOY_BUTTON_RIGHT_SHOULDER: "pad_rb", JOY_BUTTON_LEFT_STICK: "pad_ls",
			JOY_BUTTON_RIGHT_STICK: "pad_rs", JOY_BUTTON_START: "pad_start", JOY_BUTTON_BACK: "pad_back",
			JOY_BUTTON_DPAD_UP: "pad_dpad_up", JOY_BUTTON_DPAD_DOWN: "pad_dpad_down",
			JOY_BUTTON_DPAD_LEFT: "pad_dpad_left", JOY_BUTTON_DPAD_RIGHT: "pad_dpad_right"}
		return _named("ui.key." + ids.get(e.button_index, ""), "Pad %d" % e.button_index)
	if e is InputEventJoypadMotion:
		match e.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return _named("ui.key.pad_lstick", "L")
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return _named("ui.key.pad_rstick", "R")
			JOY_AXIS_TRIGGER_LEFT:
				return _named("ui.key.pad_lt", "LT")
			JOY_AXIS_TRIGGER_RIGHT:
				return _named("ui.key.pad_rt", "RT")
	return ""


func _named(key: String, fallback: String) -> String:
	return Loc.t(key) if Loc.has(key) else fallback
