extends Resource
## Свойства ломкой платформы. Форма — контур объекта (роль form): замкнутый — тело, открытый — платформа.

const LABELS := {"delay": "Задержка до обрушения", "shake": "Дрожать перед обрушением", "restore_time": "Восстановление",
	"thickness": "Толщина (открытая форма)", "one_way": "Проходима снизу (открытая форма)", "color": "Цвет",
	"reset_on_death": "Откат при смерти героя"}
const UNITS := {"delay": "с", "restore_time": "с", "thickness": "px"}
const HINTS := {
	"delay": "Сколько секунд после того, как герой встал сверху, платформа держится.",
	"restore_time": "0 — не восстанавливается. Иначе появляется снова через столько секунд.",
}

@export_range(0.0, 5.0, 0.05) var delay: float = 0.6
@export var shake: bool = true
@export_range(0.0, 30.0, 0.5, "or_greater") var restore_time: float = 3.0
@export_range(4.0, 64.0, 1.0) var thickness: float = 16.0
@export var one_way: bool = true
@export var color: Color = Color(0.6, 0.52, 0.42)
@export var reset_on_death: bool = true
