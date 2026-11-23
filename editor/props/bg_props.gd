extends Resource
## Инспектор: свойства фона.

const LABELS := {
	"pos_x": "Положение X", "pos_y": "Положение Y", "scale_x": "Масштаб X", "scale_y": "Масштаб Y",
	"parallax_x": "Параллакс X", "parallax_y": "Параллакс Y", "region_x": "Кадр: X", "region_y": "Кадр: Y",
	"region_w": "Кадр: ширина", "region_h": "Кадр: высота", "modulate": "Оттенок", "z": "Порядок в слое",
	"locked": "Замок",
}
const UNITS := {"pos_x": "px", "pos_y": "px", "scale_x": "×", "scale_y": "×", "parallax_x": "×", "parallax_y": "×",
	"region_x": "px", "region_y": "px", "region_w": "px", "region_h": "px"}
const HINTS := {
	"parallax_x": "1 — движется вместе с миром, 0 — стоит на месте (небо), 0.5 — вдвое медленнее мира.",
	"region_w": "Кадрирование в пикселях картинки. Ширина или высота 0 — вся картинка.",
	"locked": "Запертый фон не выделяется кликом (выбрать можно в списке «Фоны» внизу).",
}

@export_group("Положение")
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_x: float = 0.0
@export_range(-10000.0, 10000.0, 1.0, "or_greater", "or_less") var pos_y: float = 0.0
@export_range(0.05, 4.0, 0.01, "or_greater") var scale_x: float = 1.0
@export_range(0.05, 4.0, 0.01, "or_greater") var scale_y: float = 1.0
@export_group("Параллакс")
@export_range(0.0, 2.0, 0.01, "or_greater") var parallax_x: float = 1.0
@export_range(0.0, 2.0, 0.01, "or_greater") var parallax_y: float = 1.0
@export_group("Кадрирование")
@export_range(0.0, 8192.0, 1.0, "or_greater") var region_x: float = 0.0
@export_range(0.0, 8192.0, 1.0, "or_greater") var region_y: float = 0.0
@export_range(0.0, 8192.0, 1.0, "or_greater") var region_w: float = 0.0
@export_range(0.0, 8192.0, 1.0, "or_greater") var region_h: float = 0.0
@export_group("Вид")
@export var modulate: Color = Color.WHITE
@export_range(-50, 50, 1) var z: int = 0
@export var locked: bool = false
