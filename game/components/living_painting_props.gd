extends Resource
## Свойства ожившей картины. Форма — контур объекта (роль form): по ней можно стоять/ехать.

const LABELS := {
	"image": "Картинка", "image2": "Кадр 2", "image3": "Кадр 3", "frame_hz": "Смена кадров", "image_scale": "Масштаб картинки",
	"condition": "Оживает, если", "paintable_uid": "Рисуемый контур (для «Дорисована»)", "lit_radius": "Свет: радиус проверки",
	"rest_platform": "В покое — платформа", "awake": "Ожив — поведение", "path_uid": "Путь", "speed": "Скорость",
	"mode": "Режим пути", "pause": "Пауза в точках", "ease": "Плавный старт и остановка", "contact_damage": "Урон касанием (манекен)",
	"lost": "Условие пропало", "fx_flash": "Переход: вспышка", "fx_shake": "Переход: дрожь", "fx_tint": "Переход: смена оттенка",
	"color": "Цвет (без картинки)", "start_active": "Активна с начала (для «связью»)", "reset_on_death": "Откат при смерти героя",
}
const UNITS := {"frame_hz": "Гц", "image_scale": "×", "lit_radius": "px", "speed": "px/с", "pause": "с"}
const HINTS := {
	"image2": "2–3 кадра сменяются при оживании — «мерцающее» оживление (отсылка к многоногим зверям Шове).",
	"condition": "Освещена — в свете факела. Связью — её включает другой объект. Дорисована — когда дорисован указанный рисуемый контур.",
	"rest_platform": "Выключено — в покое это только рисунок (сквозь него можно пройти).",
	"awake": "Едет по пути — как движущаяся платформа (на ней можно ехать). Манекен — ходит, бьёт касанием, по нему можно бить.",
	"lost": "Замереть на месте / вернуться в исходную точку / доехать до конца пути и там замереть.",
}
const PICKS := {"image": "image", "image2": "image", "image3": "image", "paintable_uid": "object", "path_uid": "path"}

@export_group("Вид")
@export var image: String = ""
@export var image2: String = ""
@export var image3: String = ""
@export_range(0.5, 24.0, 0.5) var frame_hz: float = 6.0
@export_range(0.05, 4.0, 0.01, "or_greater") var image_scale: float = 1.0
@export var color: Color = Color(0.7, 0.36, 0.16)
@export_group("Условие")
@export_enum("Освещена", "Активирована связью", "Дорисована") var condition: int = 0
@export var paintable_uid: String = ""
@export_range(0.0, 200.0, 2.0, "or_greater") var lit_radius: float = 40.0
@export var start_active: bool = false
@export_group("Поведение")
@export var rest_platform: bool = true
@export_enum("Едет по пути", "Становится манекеном") var awake: int = 0
@export var path_uid: String = ""
@export_range(10.0, 800.0, 5.0, "or_greater") var speed: float = 110.0
@export_enum("Туда-обратно", "По кругу", "Один раз") var mode: int = 0
@export_range(0.0, 5.0, 0.05) var pause: float = 0.3
@export_range(0.0, 1.0, 0.05) var ease: float = 0.4
@export_range(-1.0, 60.0, 1.0, "or_greater") var contact_damage: float = -1.0
@export_enum("Замереть", "Вернуться в исходную точку", "Доехать до конца пути") var lost: int = 0
@export_group("Переход")
@export var fx_flash: bool = true
@export var fx_shake: bool = true
@export var fx_tint: bool = true
@export var reset_on_death: bool = true
