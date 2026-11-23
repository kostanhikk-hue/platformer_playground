extends Resource
## Свойства источника света (факел настенный / переносимый).

const LABELS := {"radius": "Радиус действия", "view_radius": "Радиус света (вид)", "color": "Цвет", "energy": "Сила",
	"flicker_amp": "Мерцание: амплитуда", "flicker_hz": "Мерцание: частота", "carryable": "Переносимый",
	"line_of_sight": "Не светит сквозь стены", "look": "Вид", "start_active": "Горит с начала",
	"reset_on_death": "Откат при смерти героя"}
const UNITS := {"radius": "px", "view_radius": "px", "flicker_hz": "Гц"}
const HINTS := {
	"radius": "Механика: что ближе этого радиуса — освещено (оживают картины, срабатывают «освещаемые»).",
	"view_radius": "Как далеко видно свет на экране. −1 — как радиус действия.",
	"flicker_amp": "Доля, на которую дрожат радиус и яркость (0.1 = ±10 %).",
	"carryable": "Можно взять E — свет идёт за героем; ещё раз E — положить.",
	"line_of_sight": "Освещено, только если от огня до точки нет коллизии мира.",
	"start_active": "Активен = горит. Связь зажигает и гасит.",
}

@export_range(16.0, 800.0, 4.0, "or_greater") var radius: float = 200.0
@export_range(-1.0, 1200.0, 4.0, "or_greater") var view_radius: float = -1.0
@export var color: Color = Color(1.0, 0.72, 0.4)
@export_range(0.0, 4.0, 0.05, "or_greater") var energy: float = 1.2
@export_range(0.0, 0.5, 0.01) var flicker_amp: float = 0.08
@export_range(0.0, 20.0, 0.5) var flicker_hz: float = 7.0
@export var carryable: bool = false
@export var line_of_sight: bool = true
@export_enum("Факел на стене", "Факел в руке", "Только свет") var look: int = 0
@export var start_active: bool = true
@export var reset_on_death: bool = true
