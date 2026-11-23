extends Resource
## Свойства «Выхода».

const LABELS := {"target_level": "Следующий уровень (пока не используется)", "width": "Ширина", "height": "Высота",
	"locked": "Заперт (пока не откроет связь)", "reset_on_death": "Откат при смерти героя"}
const UNITS := {"width": "px", "height": "px"}
const HINTS := {
	"target_level": "Пригодится в кампании. Сейчас выход ведёт на экран «Уровень пройден» и в главное меню.",
	"locked": "Запертый выход не пропускает, пока его не откроет связь (рисуемая дверь, рычаг). Активен = открыт.",
}

@export var target_level: String = ""
@export_range(8.0, 512.0, 4.0, "or_greater") var width: float = 64.0
@export_range(8.0, 512.0, 4.0, "or_greater") var height: float = 96.0
@export var locked: bool = false
@export var reset_on_death: bool = true
