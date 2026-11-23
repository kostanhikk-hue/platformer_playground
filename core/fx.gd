extends Node
## Глобальные эффекты «сочности» (автозагрузка Fx): хитстоп, тряска камеры, масштаб времени.
## Любой скрипт: Fx.hitstop(0.06)  ·  Fx.shake(4.0, 0.12)
## Камера героя подписана на shake_requested.

signal shake_requested(amount: float, seconds: float)

var base_scale := 1.0
var _token := 0


## Показывать ли отладочные хитбоксы (галочка на вкладке «Мир»).
var debug_hitboxes: bool:
	get:
		return Params.world.show_hitboxes


func set_base_scale(s: float) -> void:
	base_scale = s
	Engine.time_scale = s


## Почти останавливает время на seconds (реальных секунд). Повторный вызов продлевает.
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_token += 1
	var mine := _token
	Engine.time_scale = Params.world.hitstop_scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	if mine == _token:
		Engine.time_scale = base_scale


func shake(amount: float, seconds: float = 0.12) -> void:
	if amount > 0.0 and seconds > 0.0:
		shake_requested.emit(amount, seconds)
