extends Node
## Сценарий уровня (фаза 4): content/levels/<эпоха>/<id>.gd рядом с уровнем, наследует этот файл.
## Пишет агент по просьбе: «в cave_01 при входе в t_bulls богиня говорит…». В конструкторе — только зоны,
## метки и заметки. При «Играть отсюда» сценарий каждый раз загружается заново (без кэша).
##
## В начале сценария — блок «Настройки»: все числа (время, масштаб, задержки) константами с комментарием.
##
## События (переопределить):
##   on_level_start() · on_zone_enter(id) · on_zone_exit(id) · on_event(uid, name, data) ·
##   on_player_died(count) · on_checkpoint(uid)
## Команды — ниже, по разделам. Всё, что длится во времени, работает с await. При смерти героя и выходе из
## уровня запущенные цепочки прерываются (команда после await просто не продолжится).
## Состояние храните во флагах (flag / set_flag / once), а не в своих переменных: флаги, включённые объекты,
## пресеты, приёмы, камера и блокировка ввода откатываются при смерти к последнему чекпоинту.
## Полный список команд — заметка «Технология/Сценарии уровней».

## Никогда не испускается: на нём «повисают» прерванные цепочки.
signal _halt

const Lines := preload("res://game/dialog/lines_db.gd")

var runtime: Node          ## game/level/level_runtime.gd
var level: LevelData
var player: Node2D
var dialog: Node           ## game/dialog/dialog_player.gd
var flags := {}            ## флаги (откатываются при смерти)
var deaths := 0            ## номер смерти на уровне
var _epoch := 0
var _zones_in := {}
var _cam_tweens := {}
var _input_locked := false


# ================================================================ события (переопределяются)

func on_level_start() -> void:
	pass

func on_zone_enter(_id: String) -> void:
	pass

func on_zone_exit(_id: String) -> void:
	pass

func on_event(_uid: String, _name: String, _data: Dictionary) -> void:
	pass

func on_player_died(_count: int) -> void:
	pass

func on_checkpoint(_uid: String) -> void:
	pass


# ================================================================ поиск

## Зона-триггер по id. Нет — ошибка в логе.
func zone(id: String) -> Node:
	return _need(id, "зона")


## Метка (точка) по id.
func marker(id: String) -> Node:
	return _need(id, "метка")


## Любой объект уровня по uid (дверь, рычаг, рисуемый контур…).
func obj(id: String) -> Node:
	return _need(id, "объект")


## Точка в мире: метка, объект или Vector2.
func pos_of(target) -> Vector2:
	if target is Vector2:
		return target
	var n: Node = obj(target) if target is String else target
	return n.global_position if n is Node2D else Vector2.ZERO


func _need(id: String, what: String) -> Node:
	var n: Node = runtime.get_component(id) if runtime != null else null
	if n == null:
		var msg := "Сценарий уровня %s: нет %s «%s»" % [level.id if level != null else "?", what, id]  # loc: dev — ошибка в лог
		push_error(msg)
		Events.log_line("script", "ОШИБКА: " + msg)
	return n


# ================================================================ время

## Пауза: await wait(2.0).
func wait(sec: float) -> void:
	var e := _epoch
	await get_tree().create_timer(maxf(sec, 0.0), false).timeout
	if e != _epoch:
		await _halt


## Герой сейчас в зоне?
func in_zone(id: String) -> bool:
	return _zones_in.has(id)


# ================================================================ объекты и флаги

## Включить / выключить объект (активация Ф2: дверь открыта, свет горит, контур виден…).
func activate(id: String, on: bool = true) -> void:
	var n := obj(id)
	if n != null and n.has_method("set_active"):
		_log("activate %s %s" % [id, "вкл" if on else "выкл"])
		n.set_active(on)


func toggle(id: String) -> void:
	var n := obj(id)
	if n != null and n.has_method("set_active"):
		_log("toggle " + id)
		n.set_active(not n.is_active())


func flag(key: String) -> Variant:
	return flags.get(key, false)


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	_log("flag %s = %s" % [key, str(value)])


## true только в первый раз (флаг ставится сам). Откатывается при смерти, как флаги.
func once(key: String) -> bool:
	var k := "once:" + key
	if flags.has(k):
		return false
	flags[k] = true
	return true


# ================================================================ герой

func lock_input() -> void:
	_input_locked = true
	if runtime != null:
		runtime.script_input_lock = true
	_log("lock_input")


func unlock_input() -> void:
	_input_locked = false
	if runtime != null:
		runtime.script_input_lock = false
	_log("unlock_input")


## Приём героя: "attack" (удар), "ink" (линия), "wave" (волна) — включить или выключить.
func set_ability(ability: String, on: bool) -> void:
	if not ability in ["attack", "ink", "wave"]:
		push_error("set_ability: нет приёма «%s» (attack, ink, wave)" % ability)
		return
	if on:
		player.skills_off.erase(ability)
	else:
		player.skills_off[ability] = true
	_log("set_ability %s %s" % [ability, "вкл" if on else "выкл"])


## Пресет механики: apply_preset("ink", "short thick") — файл data/presets/ink/*short_thick*.tres.
func apply_preset(set_key: String, preset: String) -> void:
	if runtime.apply_preset(set_key, preset):
		_log("apply_preset %s %s" % [set_key, preset])


## Вернуть набор параметров к значениям уровня (как до первого apply_preset).
func reset_preset(set_key: String) -> void:
	runtime.reset_preset(set_key)
	_log("reset_preset " + set_key)


# ================================================================ реплики

## Реплика из content/dialog/lines.csv. С await — дождаться окончания (в очереди — после предыдущих).
func say(line_id: String) -> void:
	var e := _epoch
	_log("say " + line_id)
	var r = dialog.say(line_id)
	if r != null and not r.done:
		await r.finished
	if e != _epoch:
		await _halt


## Случайная реплика набора без повторов. Пропускается, если кто-то говорит.
func bark(set_name: String) -> void:
	var e := _epoch
	var r = dialog.bark(set_name)
	_log("bark %s%s" % [set_name, "" if r != null else " (пропущен)"])
	if r != null and not r.done:
		await r.finished
	if e != _epoch:
		await _halt


## Следующая подсказка набора по порядку (последняя повторяется). Пропускается, если кто-то говорит.
## Номер подсказки — во флаге, поэтому откатывается при смерти.
func hint(set_name: String) -> void:
	var e := _epoch
	var k := "hint:" + set_name
	var i: int = int(flags.get(k, 0))
	var r = dialog.hint_line(set_name, i)
	_log("hint %s #%d%s" % [set_name, i + 1, "" if r != null else " (пропущен)"])
	if r != null:
		flags[k] = i + 1
		if not r.done:
			await r.finished
	if e != _epoch:
		await _halt


## Все реплики момента (колонка moment в lines.csv) по порядку id: await say_moment("cave_01_m02").
func say_moment(moment: String) -> void:
	var e := _epoch
	var ids: Array = Lines.moment_lines(moment)
	if ids.is_empty():
		var msg := "Сценарий уровня %s: нет реплик момента «%s»" % [level.id if level != null else "?", moment]  # loc: dev — ошибка в лог
		push_error(msg)
		Events.log_line("script", "ОШИБКА: " + msg)
		return
	_log("say_moment %s (%d)" % [moment, ids.size()])
	var last = null
	for id in ids:
		last = dialog.say(id)
	if last != null and not last.done:
		await last.finished
	if e != _epoch:
		await _halt


## Подсказка на экране: ключ из content/i18n/hints.csv («hint.move»). sec > 0 — сама скроется.
## Клавиши в подсказке ({jump}, {move}) подставляются текущие.
func show_hint(key: String, sec: float = 0.0) -> void:
	_log("show_hint " + key)
	runtime.show_hint(key, {}, sec)


func hide_hint() -> void:
	runtime.hide_hint()


## Кто-то говорит?
func speaking() -> bool:
	return dialog.busy()


# ================================================================ камера

## Масштаб камеры: z — множитель к масштабу вкладки «Камера» (1 — как обычно, 0.7 — отдалить). За time с.
func camera_zoom(z: float, time: float = 1.0) -> void:
	_log("camera_zoom %.2f за %.1f с" % [z, time])
	await _cam_tween("cam_zoom_mult", maxf(z, 0.05), time)


## Добавочное смещение точки взгляда (px) за time с.
func camera_offset(v: Vector2, time: float = 1.0) -> void:
	_log("camera_offset %s" % str(v))
	await _cam_tween("cam_extra_offset", v, time)


## Плавно перевести камеру на метку / объект за time с, подержать hold с, вернуть к герою (ещё time с).
func camera_show(id: String, time: float = 1.0, hold: float = 1.0) -> void:
	var n := obj(id)
	if n == null:
		return
	_log("camera_show %s" % id)
	var e := _epoch
	player.cam_focus = (n as Node2D).global_position
	await _cam_tween("cam_focus_w", 1.0, time)
	if e != _epoch:
		await _halt
	await wait(hold)
	await _cam_tween("cam_focus_w", 0.0, time)
	if e != _epoch:
		await _halt


## Запереть камеру в границах зоны (арена босса).
func camera_lock(zone_id: String) -> void:
	var z := zone(zone_id)
	if z != null and z.has_method("world_rect"):
		player.cam_lock = z.world_rect()
		_log("camera_lock " + zone_id)


func camera_unlock() -> void:
	player.cam_lock = Rect2()
	_log("camera_unlock")


## Вернуть камеру к настройкам уровня (масштаб, смещение, показ, замок) за time с.
func camera_reset(time: float = 1.0) -> void:
	_log("camera_reset")
	player.cam_lock = Rect2()
	_cam_tween("cam_extra_offset", Vector2.ZERO, time)
	_cam_tween("cam_focus_w", 0.0, time)
	await _cam_tween("cam_zoom_mult", 1.0, time)


## Тряска камеры (через Fx).
func shake(power: float, time: float = 0.3) -> void:
	Fx.shake(power, time)


func _cam_tween(prop: String, to: Variant, time: float) -> void:
	var e := _epoch
	var old: Tween = _cam_tweens.get(prop, null)
	if old != null and old.is_valid():
		old.kill()
	if time <= 0.0:
		player.set(prop, to)
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, prop, to, time)
	_cam_tweens[prop] = tw
	await tw.finished
	if e != _epoch:
		await _halt


# ================================================================ служебное (зовёт уровень)

func _log(text: String) -> void:
	Events.log_line("script", text)


func _zone(id: String, entered: bool) -> void:
	if entered:
		_zones_in[id] = true
		on_zone_enter(id)
	else:
		_zones_in.erase(id)
		on_zone_exit(id)


## Прервать все цепочки (смерть, выход): камера к герою, ввод разблокирован, реплики замолкают.
func interrupt() -> void:
	_epoch += 1
	for k in _cam_tweens:
		var t: Tween = _cam_tweens[k]
		if t != null and t.is_valid():
			t.kill()
	_cam_tweens.clear()
	if player != null and is_instance_valid(player):
		player.cam_focus_w = 0.0
	if dialog != null:
		dialog.stop_all()


func resets_on_death() -> bool:
	return true


func snapshot() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"skills_off": player.skills_off.duplicate(),
		"zoom": player.cam_zoom_mult, "offset": player.cam_extra_offset, "lock": player.cam_lock,
		"input": _input_locked,
		"presets": runtime.presets_applied.duplicate(),
	}


func restore(d: Dictionary) -> void:
	flags = d.get("flags", {}).duplicate(true)
	player.skills_off = d.get("skills_off", {}).duplicate()
	player.cam_zoom_mult = d.get("zoom", 1.0)
	player.cam_extra_offset = d.get("offset", Vector2.ZERO)
	player.cam_lock = d.get("lock", Rect2())
	player.cam_focus_w = 0.0
	_input_locked = d.get("input", false)
	runtime.script_input_lock = _input_locked
	runtime.restore_presets(d.get("presets", {}))
