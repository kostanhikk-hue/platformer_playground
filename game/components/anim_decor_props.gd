extends Resource
## Свойства анимированного декора: картинка-лист + сетка кадров. Без разметки событий (пайплайн анимаций — фаза 1).

const LABELS := {"image": "Картинка-лист", "columns": "Колонок", "rows": "Строк", "frame_w": "Ширина кадра",
	"frame_h": "Высота кадра", "frames": "Кадров (0 — все)", "fps": "Кадров в секунду", "loop": "Петля",
	"random_start": "Случайный первый кадр", "scale": "Масштаб", "modulate": "Оттенок"}
const UNITS := {"frame_w": "px", "frame_h": "px", "fps": "к/с", "scale": "×"}
const HINTS := {"frame_w": "0 — ширина листа / колонки.", "frame_h": "0 — высота листа / строки.",
	"loop": "Выключено — проигрывается один раз и останавливается на последнем кадре."}
const PICKS := {"image": "image"}

@export var image: String = ""
@export_range(1, 32, 1, "or_greater") var columns: int = 4
@export_range(1, 32, 1, "or_greater") var rows: int = 1
@export_range(0.0, 1024.0, 1.0, "or_greater") var frame_w: float = 0.0
@export_range(0.0, 1024.0, 1.0, "or_greater") var frame_h: float = 0.0
@export_range(0, 256, 1, "or_greater") var frames: int = 0
@export_range(0.5, 60.0, 0.5) var fps: float = 8.0
@export var loop: bool = true
@export var random_start: bool = false
@export_range(0.05, 4.0, 0.01, "or_greater") var scale: float = 1.0
@export var modulate: Color = Color.WHITE
