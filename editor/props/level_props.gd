extends Resource
## Инспектор: настройки уровня (вкладка «Уровень»).

const LABELS := {"id": "id (имя файла)", "title": "Название", "epoch": "Эпоха", "kill_y": "Высота смерти (kill_y)",
	"bg_color": "Цвет фона", "bounds_x": "Границы: X", "bounds_y": "Границы: Y", "bounds_w": "Границы: ширина",
	"bounds_h": "Границы: высота", "darkness_enabled": "Темнота", "darkness_color": "Темнота: цвет и сила",
	"brush_preset": "Кисть уровня"}
const UNITS := {"kill_y": "px", "bounds_x": "px", "bounds_y": "px", "bounds_w": "px", "bounds_h": "px"}
const HINTS := {
	"id": "Латиница, цифры, «_». Файл: content/levels/<эпоха>/<id>.tres. Новый id или эпоха — при сохранении новый файл.",
	"kill_y": "Упавший ниже этой Y герой возвращается на чекпоинт (или старт).",
	"bounds_w": "Границы уровня = пределы камеры. Их можно тянуть ручками рамки на холсте.",
	"darkness_enabled": "Затемнить уровень (CanvasModulate): видно только то, что освещают факелы. В конструкторе — в «Виде игрока» (F6).",
	"darkness_color": "Чем темнее цвет — тем сильнее затемнение.",
	"brush_preset": "Пресет кисти для всего, что рисуется на уровне (штрихи героя, рисуемые контуры). Пусто — вкладка «Кисть».",
}
const PICKS := {"brush_preset": "brush"}

@export_group("Уровень")
@export var id: String = ""
@export var title: String = ""
@export_enum("Общее", "Пещера", "Египет", "Греция") var epoch: int = 0
@export_range(-2000.0, 6000.0, 10.0, "or_greater", "or_less") var kill_y: float = 900.0
@export var bg_color: Color = Color.BLACK
@export_group("Границы")
@export_range(-10000.0, 10000.0, 32.0, "or_greater", "or_less") var bounds_x: float = 0.0
@export_range(-10000.0, 10000.0, 32.0, "or_greater", "or_less") var bounds_y: float = 0.0
@export_range(320.0, 20000.0, 32.0, "or_greater") var bounds_w: float = 1920.0
@export_range(320.0, 10000.0, 32.0, "or_greater") var bounds_h: float = 640.0
@export_group("Свет и кисть")
@export var darkness_enabled: bool = false
@export var darkness_color: Color = Color(0.16, 0.14, 0.2)
@export var brush_preset: String = ""
