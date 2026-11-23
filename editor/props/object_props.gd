extends Resource
## Инспектор: положение объекта (служебные объекты, враги).

const LABELS := {"pos_x": "Положение X", "pos_y": "Положение Y"}
const UNITS := {"pos_x": "px", "pos_y": "px"}

@export_group("Положение")
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
