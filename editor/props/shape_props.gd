extends Resource
## Инспектор: свойства контура коллизии (прокси — значения переносятся в GeoShape командами).

const LABELS := {
	"kind": "Вид", "material": "Материал", "thickness": "Толщина", "one_way": "Проходима снизу",
	"solid_angle_deg": "Стена, если круче", "visible_in_game": "Видна в игре", "color": "Цвет",
	"pos_x": "Положение X", "pos_y": "Положение Y",
}
const UNITS := {"thickness": "px", "solid_angle_deg": "°", "pos_x": "px", "pos_y": "px"}
const HINTS := {
	"kind": "Тело ↔ Смерть (замкнутые), Платформа ↔ Стена (открытые). Смена замкнутого на открытый размыкает контур.",
	"thickness": "Для платформ и стен: толщина отрезков. Верхняя грань лежит на нарисованной линии.",
	"one_way": "Для платформы: пологие участки можно проходить снизу.",
	"solid_angle_deg": "Участки платформы круче этого угла — сплошная стена (как у штрихов кисти).",
	"visible_in_game": "Нарисовать контур в игре его цветом (обычно коллизия невидима — видна картина).",
}

@export_group("Контур")
@export_enum("Тело", "Платформа", "Стена", "Блок", "Смерть") var kind: int = 0
@export_enum("Обычный", "Лёд") var material: int = 0
@export_range(1.0, 64.0, 1.0, "or_greater") var thickness: float = 12.0
@export var one_way: bool = true
@export_range(30.0, 90.0, 1.0) var solid_angle_deg: float = 60.0
@export var visible_in_game: bool = false
@export var color: Color = Color.WHITE
@export_group("Положение")
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
