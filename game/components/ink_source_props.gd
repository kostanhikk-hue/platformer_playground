extends Resource
## Свойства источника охры.

const LABELS := {"amount": "Сколько охры даёт", "recharge": "Перезарядка", "pickup": "Как подобрать",
	"start_active": "Заряжен с начала", "reset_on_death": "Откат при смерти героя"}
const UNITS := {"amount": "охры", "recharge": "с"}
const HINTS := {
	"amount": "−1 — заполнить запас полностью.",
	"recharge": "0 — однократный. Иначе снова заряжается через столько секунд.",
}

@export_range(-1.0, 300.0, 1.0, "or_greater") var amount: float = 50.0
@export_range(0.0, 60.0, 0.5, "or_greater") var recharge: float = 0.0
@export_enum("Касанием", "Взаимодействием") var pickup: int = 0
@export var start_active: bool = true
@export var reset_on_death: bool = true
