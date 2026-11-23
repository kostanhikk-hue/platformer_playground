extends Resource
## Инспектор: положение, масштаб, поворот и отражение арт-объекта.

const LABELS := {"pos_x": "Положение X", "pos_y": "Положение Y", "scale_x": "Масштаб X", "scale_y": "Масштаб Y",
	"rotation_deg": "Поворот", "flip_h": "Отражён по горизонтали"}
const UNITS := {"pos_x": "px", "pos_y": "px", "scale_x": "×", "scale_y": "×", "rotation_deg": "°"}

@export_group("Положение")
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
@export_range(0.05, 4.0, 0.01, "or_greater") var scale_x: float = 1.0
@export_range(0.05, 4.0, 0.01, "or_greater") var scale_y: float = 1.0
@export_range(-180.0, 180.0, 1.0, "or_greater", "or_less") var rotation_deg: float = 0.0
@export var flip_h: bool = false
