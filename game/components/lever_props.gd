extends Resource
## Свойства рычага.

const LABELS := {"mode": "Как работает", "start_active": "Включён с начала", "targets": "Цели связей",
	"link_mode": "Что делать с целями", "reset_on_death": "Откат при смерти героя"}
const HINTS := {
	"mode": "Туда-обратно — каждое нажатие E переключает. Однократный — включается один раз и больше не двигается.",
	"targets": "uid объектов, которые срабатывают при переключении (дверь, платформа, свет…).",
	"link_mode": "Включить / Выключить / Переключить — при каждом нажатии. Следовать — цель активна, пока рычаг включён.",
}

@export_enum("Туда-обратно", "Однократный") var mode: int = 0
@export var start_active: bool = false
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 3
@export var reset_on_death: bool = true
