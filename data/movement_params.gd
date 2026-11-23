extends Resource
## Движение героя. Файл: data/movement_default.tres  ·  Вкладка «Движ.»
## Гравитация и скорость прыжка не задаются напрямую — они выводятся из высоты прыжка и времени до вершины:
##   g = 2·h / t²,  v0 = 2·h / t

const LABELS := {
	"run_speed": "Макс. скорость бега",
	"ground_accel": "Разгон на земле",
	"ground_decel": "Торможение на земле",
	"turn_mult": "Разворот (множитель)",
	"air_accel": "Разгон в воздухе",
	"air_decel": "Торможение в воздухе",
	"ice_friction": "Сцепление на льду",
	"jump_height": "Высота прыжка",
	"time_to_apex": "Время до вершины",
	"fall_mult": "Гравитация при падении",
	"cut_mult": "Гравитация при отпускании кнопки",
	"apex_threshold": "Зона зависания у вершины",
	"apex_mult": "Гравитация в зоне зависания",
	"max_fall": "Макс. скорость падения",
	"coyote_time": "Coyote time",
	"jump_buffer": "Jump buffer",
	"air_jumps": "Доп. прыжки в воздухе",
	"wall_enabled": "Прыжки от стен включены",
	"wall_slide_speed": "Скорость скольжения по стене",
	"wall_jump_x": "Отскок от стены",
	"wall_jump_lock": "Блок управления после отскока",
	"max_slope_deg": "Макс. угол склона (стоять можно)",
	"body_width": "Ширина тела",
	"body_height": "Высота тела",
}
const UNITS := {
	"run_speed": "px/с", "ground_accel": "px/с²", "ground_decel": "px/с²", "air_accel": "px/с²",
	"air_decel": "px/с²", "jump_height": "px", "time_to_apex": "с", "apex_threshold": "px/с",
	"max_fall": "px/с", "coyote_time": "с", "jump_buffer": "с", "wall_slide_speed": "px/с",
	"wall_jump_x": "px/с", "wall_jump_lock": "с", "max_slope_deg": "°", "body_width": "px", "body_height": "px",
}
const HINTS := {
	"turn_mult": "Во сколько раз быстрее разгон, когда жмёшь против текущей скорости.",
	"ice_friction": "Множитель разгона/торможения на блоках с меткой ice. Меньше — скользче.",
	"cut_mult": "Если отпустить прыжок на подъёме — гравитация умножается на это. Даёт прыжок переменной высоты.",
	"apex_threshold": "Если |скорость Y| меньше этого и прыжок зажат — герой «зависает» у вершины.",
	"coyote_time": "Сколько можно прыгнуть после схода с края.",
	"jump_buffer": "Нажатие прыжка чуть раньше приземления запоминается на это время.",
	"wall_jump_lock": "После отскока от стены ввод по горизонтали игнорируется — чтобы не прилипнуть обратно.",
	"body_width": "Коллизия героя. Влияет на то, куда он пролезает.",
}

@export_group("Горизонталь")
@export_range(100.0, 700.0, 5.0, "or_greater") var run_speed: float = 320.0
@export_range(200.0, 6000.0, 50.0, "or_greater") var ground_accel: float = 2400.0
@export_range(200.0, 6000.0, 50.0, "or_greater") var ground_decel: float = 2800.0
@export_range(0.5, 4.0, 0.1) var turn_mult: float = 2.0
@export_range(0.0, 6000.0, 50.0, "or_greater") var air_accel: float = 1600.0
@export_range(0.0, 6000.0, 50.0, "or_greater") var air_decel: float = 800.0
@export_range(0.01, 1.0, 0.01) var ice_friction: float = 0.08

@export_group("Прыжок")
@export_range(40.0, 300.0, 5.0, "or_greater") var jump_height: float = 130.0
@export_range(0.15, 0.8, 0.01) var time_to_apex: float = 0.38
@export_range(0.5, 3.5, 0.05) var fall_mult: float = 1.5
@export_range(1.0, 6.0, 0.1) var cut_mult: float = 3.0
@export_range(0.0, 250.0, 5.0) var apex_threshold: float = 40.0
@export_range(0.1, 1.0, 0.05) var apex_mult: float = 0.6
@export_range(300.0, 1500.0, 25.0, "or_greater") var max_fall: float = 900.0

@export_group("Поблажки для игрока")
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
@export_range(0.0, 0.3, 0.01) var jump_buffer: float = 0.12
@export_range(0, 3, 1, "or_greater") var air_jumps: int = 0

@export_group("Стены и склоны")
@export var wall_enabled: bool = true
@export_range(20.0, 400.0, 10.0) var wall_slide_speed: float = 90.0
@export_range(100.0, 600.0, 10.0) var wall_jump_x: float = 300.0
@export_range(0.0, 0.5, 0.01) var wall_jump_lock: float = 0.15
@export_range(20.0, 80.0, 1.0) var max_slope_deg: float = 50.0

@export_group("Тело")
@export_range(8.0, 64.0, 1.0) var body_width: float = 24.0
@export_range(16.0, 96.0, 1.0) var body_height: float = 40.0
