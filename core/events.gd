extends Node
## loc: dev-file — инструмент разработчика, текст не локализуется
## Шина событий (автозагрузка Events). Все компоненты уровня сообщают о событиях только через неё:
##   Events.emit_event(uid, "painted", {"value": 100})
## Фаза 4 подпишет на сигнал event триггеры, ничего не меняя в компонентах.
## Здесь же — служебные сигналы мира, чтобы компоненты не перебирали сцену каждый кадр:
##   stroke_spawned(stroke)         — герой создал штрих (линия, волна);
##   hit_area(rect, kind, source)   — удар героя: мировой прямоугольник попадания в активной фазе.
## Лог последних событий (LOG_SIZE) — для панели «Лог событий» (Shift+Tab в режиме игры, только dev).

signal event(source_uid: String, name: String, data: Dictionary)
signal stroke_spawned(stroke: Node)
signal hit_area(rect: Rect2, kind: String, source: Node)

const LOG_SIZE := 50

var log: Array = []   ## [{t, uid, name, data}] — новые в конце


func emit_event(source_uid: String, name: String, data: Dictionary = {}) -> void:
	log.append({"t": Time.get_ticks_msec() / 1000.0, "uid": source_uid, "name": name, "data": data.duplicate()})
	while log.size() > LOG_SIZE:
		log.pop_front()
	event.emit(source_uid, name, data)


## Строка в лог без события (входы в зоны, команды сценария, реплики) — сценарии на неё не реагируют.
func log_line(source: String, text: String) -> void:
	log.append({"t": Time.get_ticks_msec() / 1000.0, "uid": source, "name": text, "data": {}})
	while log.size() > LOG_SIZE:
		log.pop_front()


func clear_log() -> void:
	log.clear()


## Текст лога (новые сверху) — для HUD плейграунда и панели лога.
func log_text(count: int = LOG_SIZE) -> String:
	var lines: PackedStringArray = []
	for i in range(log.size() - 1, maxi(log.size() - 1 - count, -1), -1):
		var e: Dictionary = log[i]
		var d := "" if (e["data"] as Dictionary).is_empty() else "  " + JSON.stringify(e["data"])
		lines.append("%7.2f с   %s   %s%s" % [e["t"], e["uid"], e["name"], d])
	return "\n".join(lines)
