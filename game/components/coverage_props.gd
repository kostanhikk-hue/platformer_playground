extends Resource
## Свойства закрашиваемой поверхности. Область — замкнутый контур объекта (роль area), уязвимые места —
## дополнительные контуры (роль weak): если они есть, процент считается только по ним.

const LABELS := {"accept_ink": "Закрашивает линия", "accept_wave": "Закрашивает волна", "accept_melee": "Закрашивает удар",
	"paint_strength": "Сила закрашивания (× толщины штриха)", "wash_rate": "Отмывание", "thresholds": "Пороги событий, %",
	"on_full": "Закрашено на 100 %", "owner_uid": "Привязать к объекту", "targets": "Цели связей",
	"link_mode": "Что делать с целями", "start_active": "Можно закрашивать с начала", "reset_on_death": "Откат при смерти героя"}
const UNITS := {"paint_strength": "×", "wash_rate": "%/с"}
const HINTS := {
	"paint_strength": "Ячейка закрашена, если до штриха ≤ половина толщины × это число. Больше — один штрих закрашивает шире.",
	"wash_rate": "0 — краска не сходит. Иначе столько процентов покрытия в секунду сходит само (враг «стряхивает» краску).",
	"thresholds": "Через запятую. На каждом пороге — событие painted_percent {value}.",
	"on_full": "Уничтожить владельца — объект, к которому привязана область (манекен), исчезает. Активировать цели — срабатывают связи.",
	"owner_uid": "Необязательно: область двигается вместе с этим объектом (врагом, арт-объектом).",
}
const PICKS := {"owner_uid": "object"}

@export_group("Что закрашивает")
@export var accept_ink: bool = true
@export var accept_wave: bool = true
@export var accept_melee: bool = true
@export_range(0.2, 4.0, 0.05, "or_greater") var paint_strength: float = 1.0
@export_range(0.0, 50.0, 0.5, "or_greater") var wash_rate: float = 0.0

@export_group("Пороги")
@export var thresholds: String = "25, 50, 100"
@export_enum("Ничего", "Уничтожить владельца", "Активировать цели") var on_full: int = 2
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 0

@export_group("Общее")
@export var owner_uid: String = ""
@export var start_active: bool = true
@export var reset_on_death: bool = true
