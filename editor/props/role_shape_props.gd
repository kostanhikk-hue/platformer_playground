extends Resource
## Инспектор: форма объекта (рисуемый контур, область закраски, форма платформы…). Точки правятся на холсте.

const LABELS := {"pos_x": "Положение X", "pos_y": "Положение Y"}
const UNITS := {"pos_x": "px", "pos_y": "px"}
const HINTS := {"pos_x": "Сдвиг формы относительно объекта (вся форма целиком). Точки — тянуть на холсте."}

@export_group("Форма")
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
