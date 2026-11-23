extends Resource
## Свойства движущейся платформы. Форма — контур объекта (роль form): открытый — платформа, замкнутый — тело.
## Путь — отдельный объект «Путь» (инструмент L); платформа сдвигается так же, как точка пути от его начала.

const LABELS := {"path_uid": "Путь", "speed": "Скорость", "mode": "Режим", "pause": "Пауза в точках",
	"ease": "Плавный старт и остановка", "wait_for_player": "Ждёт героя", "start_active": "Едет с начала",
	"thickness": "Толщина (открытая форма)", "one_way": "Проходима снизу", "image": "Картинка",
	"image_scale": "Картинка: масштаб", "color": "Цвет", "reset_on_death": "Откат при смерти героя",
	"on_blocked": "Если путь перекрыт штрихом"}
const UNITS := {"speed": "px/с", "pause": "с", "thickness": "px", "image_scale": "×"}
const HINTS := {
	"path_uid": "uid пути (инструмент «Путь», L) — кнопка ⌖ выбирает путь на холсте.",
	"mode": "Туда-обратно — до конца и назад. По кругу — для замкнутого пути. Один раз — доехать до конца и остановиться.",
	"ease": "0 — равномерно, 1 — мягко разгоняется и тормозит у каждой точки.",
	"wait_for_player": "Стоит в начале (и в конце), пока герой не встанет на неё.",
	"start_active": "Активна = едет. Связь (рычаг) запускает и останавливает.",
	"image": "Необязательно: картинка поверх формы (art/…).",
	"on_blocked": "Ждать — доезжает вплотную и стоит, пока штрих не исчезнет. Развернуться — едет по пути обратно. Сломать штрих — штрих мигает и исчезает, платформа едет дальше (результат рисуемого контура не ломается — перед ним ждёт).",
}
const PICKS := {"path_uid": "path", "image": "image"}

@export var path_uid: String = ""
@export_range(10.0, 800.0, 5.0, "or_greater") var speed: float = 120.0
@export_enum("Туда-обратно", "По кругу", "Один раз") var mode: int = 0
@export_range(0.0, 5.0, 0.05) var pause: float = 0.5
@export_range(0.0, 1.0, 0.05) var ease: float = 0.6
@export var wait_for_player: bool = false
@export_enum("Ждать", "Развернуться", "Сломать штрих") var on_blocked: int = 0
@export var start_active: bool = true
@export_range(4.0, 64.0, 1.0) var thickness: float = 16.0
@export var one_way: bool = true
@export var image: String = ""
@export_range(0.05, 4.0, 0.01, "or_greater") var image_scale: float = 1.0
@export var color: Color = Color(0.55, 0.62, 0.7)
@export var reset_on_death: bool = true
