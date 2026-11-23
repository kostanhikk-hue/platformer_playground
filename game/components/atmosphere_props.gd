extends Resource
## Свойства атмосферы: частицы в прямоугольной области. Только вид, без коллизии.

const LABELS := {"preset": "Пресет", "width": "Ширина области", "height": "Высота области", "density": "Плотность",
	"size": "Размер частиц", "speed": "Скорость", "wind_deg": "Ветер: направление", "wind": "Ветер: сила",
	"use_preset_color": "Цвет пресета", "color": "Цвет", "alpha": "Прозрачность"}
const UNITS := {"width": "px", "height": "px", "density": "×", "size": "×", "speed": "×", "wind_deg": "°", "wind": "px/с²"}
const HINTS := {
	"preset": "Пыль — медленно плавает. Искры факела — летят вверх и гаснут. Песок — несётся по ветру. Лепестки — падают, кружась.",
	"density": "Множитель числа частиц пресета.",
	"wind_deg": "0° — вправо, 90° — вверх, 180° — влево, −90° — вниз.",
}

@export_enum("Пыль", "Искры факела", "Песок", "Лепестки") var preset: int = 0
@export_range(16.0, 4000.0, 8.0, "or_greater") var width: float = 512.0
@export_range(16.0, 4000.0, 8.0, "or_greater") var height: float = 256.0
@export_range(0.0, 5.0, 0.05, "or_greater") var density: float = 1.0
@export_range(0.1, 5.0, 0.05, "or_greater") var size: float = 1.0
@export_range(0.0, 5.0, 0.05, "or_greater") var speed: float = 1.0
@export_range(-180.0, 180.0, 1.0) var wind_deg: float = 0.0
@export_range(0.0, 400.0, 1.0, "or_greater") var wind: float = 0.0
@export var use_preset_color: bool = true
@export var color: Color = Color(1, 1, 1)
@export_range(0.0, 1.0, 0.05) var alpha: float = 0.7
