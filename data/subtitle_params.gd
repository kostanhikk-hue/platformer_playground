extends Resource
## Титры и голос. Файл: data/subtitle_default.tres  ·  Вкладка «Титры». Код: game/dialog/dialog_player.gd

const LABELS := {
	"font_size": "Размер шрифта",
	"name_size": "Размер имени",
	"bg_alpha": "Прозрачность подложки",
	"max_width": "Ширина титра",
	"bottom_margin": "Отступ снизу",
	"reading_speed": "Скорость чтения без голоса",
	"min_time": "Минимальное время на экране",
	"tail_time": "Титр держится после голоса",
	"gap": "Пауза между репликами",
	"show_names": "Показывать имя говорящего",
	"goddess_color": "Цвет имени: богиня",
	"hero_color": "Цвет имени: герой",
	"other_color": "Цвет имени: остальные",
	"voice_db": "Громкость голоса",
	"fade_time": "Появление и исчезновение титра",
}
const UNITS := {"font_size": "px", "name_size": "px", "max_width": "px", "bottom_margin": "px", "reading_speed": "симв/с",
	"min_time": "с", "tail_time": "с", "gap": "с", "voice_db": "дБ", "fade_time": "с"}
const HINTS := {
	"reading_speed": "Если у реплики нет файла голоса, титр держится длина текста / эта скорость (но не меньше минимального времени).",
	"tail_time": "Сколько титр ещё виден после окончания голоса.",
	"gap": "Пауза между концом одной реплики и началом следующей в очереди.",
	"bg_alpha": "Фоны-картины пёстрые — без подложки текст теряется.",
}

@export_group("Вид")
@export_range(10, 48, 1) var font_size: int = 20
@export_range(8, 40, 1) var name_size: int = 15
@export_range(0.0, 1.0, 0.05) var bg_alpha: float = 0.6
@export_range(200.0, 1200.0, 10.0) var max_width: float = 760.0
@export_range(0.0, 300.0, 2.0) var bottom_margin: float = 44.0
@export var show_names: bool = true
@export var goddess_color: Color = Color(1.0, 0.78, 0.4)
@export var hero_color: Color = Color(0.55, 0.9, 0.6)
@export var other_color: Color = Color(0.8, 0.85, 1.0)
@export_range(0.0, 1.0, 0.01) var fade_time: float = 0.15

@export_group("Время")
@export_range(3.0, 40.0, 0.5) var reading_speed: float = 15.0
@export_range(0.2, 5.0, 0.1) var min_time: float = 1.5
@export_range(0.0, 2.0, 0.05) var tail_time: float = 0.25
@export_range(0.0, 3.0, 0.05) var gap: float = 0.4

@export_group("Голос")
@export_range(-40.0, 12.0, 0.5) var voice_db: float = 0.0
