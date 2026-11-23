extends Resource
## Свойства экземпляра «Рисуемого контура» (инспектор конструктора). Форма — контур объекта с ролью outline:
## двойной клик по объекту в конструкторе — правка точек, кнопка «Нарисовать форму заново» — обвести заново.

const LABELS := {
	"method": "Как дорисовывать",
	"accept_ink": "Дорисовывает линия",
	"accept_wave": "Дорисовывает волна",
	"required_fill": "Нужно покрыть (доля)",
	"tolerance": "Допуск отклонения штриха",
	"hold_ink_per_px": "Удержание: охры за 1 px",
	"result": "Результат",
	"result_layer": "Слой результата",
	"thickness": "Платформа / стена: толщина",
	"one_way": "Платформа: проходима снизу",
	"solid_angle_deg": "Платформа: стена, если круче",
	"spawn_def": "Создать объект (id из каталога)",
	"spawn_at": "Где создать",
	"spawn_x": "Точка создания: X от центра объекта",
	"spawn_y": "Точка создания: Y от центра объекта (вниз +)",
	"lifetime": "Время жизни результата",
	"result_art": "Картинка готового вида",
	"art_scale": "Картинка: масштаб",
	"art_x": "Картинка: сдвиг X",
	"art_y": "Картинка: сдвиг Y (вниз +)",
	"targets": "Цели связей",
	"link_mode": "Что делать с целями",
	"start_active": "Пунктир виден с начала",
	"reset_on_death": "Откат при смерти героя",
	"brush_preset": "Кисть",
}
const UNITS := {"tolerance": "px", "hold_ink_per_px": "охры", "thickness": "px", "solid_angle_deg": "°",
	"spawn_x": "px", "spawn_y": "px", "lifetime": "с", "art_scale": "×", "art_x": "px", "art_y": "px"}
const HINTS := {
	"method": "Штрихом — провести линию или волну вдоль пунктира. Удержанием — встать рядом и держать E: кисть рисует сама, расходуя охру. Оба — можно комбинировать.",
	"required_fill": "Доля контура, покрытая штрихами, при которой он считается дорисованным (0.85 = 85 %).",
	"tolerance": "Насколько штрих может отойти от пунктира (плюс половина толщины штриха).",
	"hold_ink_per_px": "−1 — как на вкладке «Контур».",
	"result": "Что появится, когда контур дорисован. Тело — твёрдое по замкнутому контуру, платформа — по линии (проходима снизу), стена — сплошная ломаная, декор — только рисунок. Цели связей срабатывают при любом результате.",
	"result_layer": "Штрихи — нарисованное ведёт себя как штрих: плита со «штрихами» нажимается им, движущаяся платформа перед ним ждёт, манекен-холст проходит сквозь. Мир — становится частью уровня, эти правила на него не действуют. Герой и манекены стоят на результате в обоих случаях.",
	"spawn_def": "Необязательно: id объекта каталога (зверь-союзник, предмет) — появится, когда контур дорисован, и исчезнет вместе с результатом.",
	"lifetime": "0 — навсегда. Иначе через столько секунд результат исчезает (последние секунды мигает) и снова становится пунктиром.",
	"result_art": "Картинка из art/… — проявляется поверх нарисованного контура. По ней же можно обвести форму (кнопка в инспекторе).",
	"targets": "uid объектов, которые срабатывают, когда контур дорисован («Рисуемая дверь»: цель — выход).",
	"link_mode": "Включить / выключить / переключить цели при завершении. «Следовать» — цели активны, пока результат есть.",
	"start_active": "Выключено — контур скрыт, пока его не включит связь (рычаг, другой контур).",
	"brush_preset": "Пусто — кисть уровня.",
}
## Поля-ссылки: конструктор добавляет к ним выбор («def» — объект каталога, «image» — картинка, «brush» — пресет кисти).
const PICKS := {"spawn_def": "def", "result_art": "image", "brush_preset": "brush"}

@export_group("Дорисовка")
@export_enum("Штрихом", "Удержанием", "Оба") var method: int = 0
@export var accept_ink: bool = true
@export var accept_wave: bool = true
@export_range(0.05, 1.0, 0.01) var required_fill: float = 0.85
@export_range(0.0, 80.0, 1.0, "or_greater") var tolerance: float = 20.0
@export_range(-1.0, 2.0, 0.01, "or_greater") var hold_ink_per_px: float = -1.0

@export_group("Результат")
@export_enum("Декор", "Тело", "Платформа", "Стена") var result: int = 1
@export_enum("Штрихи", "Мир") var result_layer: int = 0
@export_range(1.0, 64.0, 1.0, "or_greater") var thickness: float = 12.0
@export var one_way: bool = true
@export_range(30.0, 90.0, 1.0) var solid_angle_deg: float = 60.0
@export var spawn_def: String = ""
@export_enum("В центре контура", "В точке") var spawn_at: int = 0
@export_range(-2000.0, 2000.0, 1.0, "or_greater", "or_less") var spawn_x: float = 0.0
@export_range(-2000.0, 2000.0, 1.0, "or_greater", "or_less") var spawn_y: float = 0.0
@export_range(0.0, 60.0, 0.5, "or_greater") var lifetime: float = 0.0

@export_group("Картинка готового вида")
@export var result_art: String = ""
@export_range(0.05, 4.0, 0.01, "or_greater") var art_scale: float = 1.0
@export_range(-1000.0, 1000.0, 1.0, "or_greater", "or_less") var art_x: float = 0.0
@export_range(-1000.0, 1000.0, 1.0, "or_greater", "or_less") var art_y: float = 0.0

@export_group("Связи")
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 0

@export_group("Общее")
@export var start_active: bool = true
@export var reset_on_death: bool = true
@export var brush_preset: String = ""
