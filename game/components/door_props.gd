extends Resource
## Свойства двери. Положение объекта — центр двери.

const LABELS := {"width": "Ширина", "height": "Высота", "open_dir": "Как открывается", "open_time": "Время открытия",
	"solid": "Закрытая — твёрдая", "start_active": "Открыта с начала", "reset_on_death": "Откат при смерти героя",
	"color": "Цвет"}
const UNITS := {"width": "px", "height": "px", "open_time": "с"}
const HINTS := {
	"open_dir": "Вверх — уезжает вверх на свою высоту. В стороны — две створки расходятся. Исчезнуть — растворяется.",
	"solid": "Выключено — закрытая дверь только рисуется (не мешает пройти).",
	"start_active": "Активна = открыта. Связь «Включить» открывает, «Выключить» закрывает.",
}

@export_range(8.0, 256.0, 4.0, "or_greater") var width: float = 32.0
@export_range(16.0, 512.0, 4.0, "or_greater") var height: float = 96.0
@export_enum("Вверх", "В стороны", "Исчезнуть") var open_dir: int = 0
@export_range(0.0, 3.0, 0.05) var open_time: float = 0.4
@export var solid: bool = true
@export var start_active: bool = false
@export var reset_on_death: bool = true
@export var color: Color = Color(0.55, 0.4, 0.28)
