extends Resource
## «Рисуемый контур» — общие для всех контуров параметры ощущения. Файл: data/paintable_params.gd → data/paintable_default.tres
## Вкладка «Контур». То, что отличается у конкретного контура (форма, допуск, результат, связи), — в инспекторе конструктора.
## Код: game/components/paintable.gd

const LABELS := {
	"sample_step": "Шаг образцов вдоль контура",
	"auto_close_gap": "Дыры короче — дорисовываются сами",
	"fade_progress": "Потеря прогресса со временем",
	"hold_forget_time": "Удержание: прогресс забывается через",
	"dash_length": "Пунктир: длина штриха",
	"dash_gap": "Пунктир: промежуток",
	"dash_width": "Пунктир: толщина",
	"dash_color": "Пунктир: цвет",
	"dash_alpha": "Пунктир: прозрачность",
	"highlight_radius": "Пульсирует, если герой ближе",
	"pulse_hz": "Пульсация: частота",
	"pulse_amount": "Пульсация: сила",
	"paint_thickness": "Толщина нарисованного контура",
	"use_ink_color": "Цвет — как у линии-охры",
	"paint_color": "Цвет нарисованного (если не как у линии)",
	"hold_speed": "Удержание: скорость дорисовки",
	"hold_start_mult": "Удержание: скорость в начале (× полной)",
	"hold_accel_time": "Удержание: разгон до полной скорости",
	"hold_accel_curve": "Удержание: кривая разгона",
	"hold_ink_per_px": "Удержание: охры за 1 px (по умолчанию)",
	"hold_move_mult": "Удержание: подвижность героя",
	"reveal_time": "Готово: картинка проявляется за",
	"done_hitstop": "Готово: хитстоп",
	"done_shake": "Готово: тряска",
	"done_shake_time": "Готово: длительность тряски",
	"flash_time": "Готово: вспышка",
	"flash_width": "Готово: ширина вспышки",
	"flash_color": "Готово: цвет вспышки",
	"fade_time": "Исчезновение: мигание последние",
	"fade_blink_hz": "Исчезновение: частота мигания",
	"fade_min_alpha": "Исчезновение: прозрачность при мигании",
}
const UNITS := {
	"sample_step": "px", "auto_close_gap": "px", "fade_progress": "%/с", "hold_forget_time": "с",
	"dash_length": "px", "dash_gap": "px", "dash_width": "px", "highlight_radius": "px", "pulse_hz": "Гц",
	"paint_thickness": "px", "hold_speed": "px/с", "hold_accel_time": "с", "hold_ink_per_px": "охры",
	"reveal_time": "с", "done_hitstop": "с", "done_shake": "px", "done_shake_time": "с", "flash_time": "с",
	"flash_width": "px", "fade_time": "с", "fade_blink_hz": "Гц",
}
const HINTS := {
	"sample_step": "Контур разбивается на точки-образцы через это расстояние. Прогресс = покрытые образцы / все. Меньше — точнее, но дороже.",
	"auto_close_gap": "Если все непокрытые участки короче этого — контур считается дорисованным (и они дорисовываются сами). Так мелкие «дыры» не мешают.",
	"fade_progress": "0 — покрытое остаётся покрытым навсегда. Иначе недорисованный контур теряет столько процентов в секунду (с краёв нарисованных участков).",
	"hold_forget_time": "0 — прогресс удержания остаётся. Иначе через столько секунд после отпускания недорисованный контур сбрасывается в ноль.",
	"highlight_radius": "Пунктир пульсирует, когда герой ближе этого расстояния к контуру.",
	"hold_speed": "Кисть сама рисует от ближайшей к герою точки в обе стороны — с такой скоростью каждая сторона.",
	"hold_accel_curve": "Показатель степени разгона: 1 — равномерно, >1 — медленный старт.",
	"hold_ink_per_px": "Цена по умолчанию. У конкретного контура в инспекторе можно задать свою (−1 — как здесь).",
	"hold_move_mult": "Множитель скорости бега, пока держишь «Взаимодействие» у контура. 0 — герой стоит на месте.",
	"reveal_time": "За это время проявляется картинка «готового» вида (если задана у контура).",
	"fade_time": "Для контуров с ограниченным временем жизни результата: последние N секунд результат мигает, затем снова пунктир.",
}

@export_group("Покрытие")
@export_range(2.0, 32.0, 1.0) var sample_step: float = 8.0
@export_range(0.0, 128.0, 2.0) var auto_close_gap: float = 24.0
@export_range(0.0, 50.0, 0.5) var fade_progress: float = 0.0
@export_range(0.0, 10.0, 0.1) var hold_forget_time: float = 0.0

@export_group("Пунктир")
@export_range(2.0, 40.0, 1.0) var dash_length: float = 10.0
@export_range(2.0, 40.0, 1.0) var dash_gap: float = 8.0
@export_range(1.0, 12.0, 0.5) var dash_width: float = 3.0
@export var dash_color: Color = Color(1.0, 0.88, 0.65)
@export_range(0.05, 1.0, 0.05) var dash_alpha: float = 0.6
@export_range(0.0, 600.0, 10.0) var highlight_radius: float = 180.0
@export_range(0.2, 6.0, 0.1) var pulse_hz: float = 1.6
@export_range(0.0, 1.0, 0.05) var pulse_amount: float = 0.5

@export_group("Рисунок")
@export_range(2.0, 40.0, 1.0) var paint_thickness: float = 10.0
@export var use_ink_color: bool = true
@export var paint_color: Color = Color(0.82, 0.46, 0.14)

@export_group("Удержание")
@export_range(20.0, 1000.0, 10.0, "or_greater") var hold_speed: float = 220.0
@export_range(0.0, 1.0, 0.05) var hold_start_mult: float = 0.3
@export_range(0.0, 3.0, 0.05) var hold_accel_time: float = 0.6
@export_range(0.3, 4.0, 0.1) var hold_accel_curve: float = 1.5
@export_range(0.0, 2.0, 0.01) var hold_ink_per_px: float = 0.15
@export_range(0.0, 1.0, 0.05) var hold_move_mult: float = 0.0

@export_group("Завершение")
@export_range(0.0, 3.0, 0.05) var reveal_time: float = 0.5
@export_range(0.0, 0.3, 0.01) var done_hitstop: float = 0.06
@export_range(0.0, 20.0, 0.5) var done_shake: float = 5.0
@export_range(0.0, 1.0, 0.01) var done_shake_time: float = 0.2
@export_range(0.0, 2.0, 0.05) var flash_time: float = 0.35
@export_range(0.0, 60.0, 1.0) var flash_width: float = 14.0
@export var flash_color: Color = Color(1.0, 0.97, 0.85)

@export_group("Исчезновение")
@export_range(0.0, 5.0, 0.1) var fade_time: float = 1.5
@export_range(1.0, 20.0, 0.5) var fade_blink_hz: float = 7.0
@export_range(0.0, 1.0, 0.05) var fade_min_alpha: float = 0.35
