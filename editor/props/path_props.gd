extends Resource
## Инспектор: путь (инструмент L) для движущихся платформ, оживших картин и патруля манекенов.

const LABELS := {"closed": "Замкнутый", "pos_x": "Положение X", "pos_y": "Положение Y"}
const UNITS := {"pos_x": "px", "pos_y": "px"}
const HINTS := {"closed": "Замкнутый путь — по кругу (последняя точка соединяется с первой). Открытый — туда-обратно или один раз."}

@export_group("Путь")
@export var closed: bool = false
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
