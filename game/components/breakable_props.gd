extends Resource
## Свойства разрушаемого блока. Форма — замкнутый контур объекта (роль form).

const LABELS := {"hits": "Прочность (ударов)", "by_melee": "Ломается ударом", "by_ink": "Ломается линией",
	"by_wave": "Ломается волной", "restore_time": "Восстановление", "color": "Цвет", "targets": "Цели связей",
	"link_mode": "Что делать с целями", "reset_on_death": "Откат при смерти героя"}
const UNITS := {"restore_time": "с"}
const HINTS := {
	"hits": "Сколько попаданий выдерживает (каждый удар, штрих или волна — одно попадание).",
	"restore_time": "0 — не восстанавливается.",
	"targets": "Срабатывают, когда блок разрушен.",
}

@export_range(1, 20, 1, "or_greater") var hits: int = 3
@export var by_melee: bool = true
@export var by_ink: bool = true
@export var by_wave: bool = true
@export_range(0.0, 60.0, 0.5, "or_greater") var restore_time: float = 0.0
@export var color: Color = Color(0.5, 0.45, 0.42)
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 0
@export var reset_on_death: bool = true
