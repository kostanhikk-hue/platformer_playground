extends Resource
## Мир и отладка. Файл: data/world_default.tres  ·  Вкладка «Мир»
## Глобальные правила, общие для всех существ, и отладочные переключатели плейграунда.

const LABELS := {
	"kill_y": "Высота смерти (падение ниже)",
	"time_scale": "Замедление времени",
	"hitstop_scale": "Скорость времени во время хитстопа",
	"show_hitboxes": "Показывать хитбоксы",
	"show_trail": "Траектория героя",
	"trail_points": "Длина траектории (точек)",
	"show_velocity": "Стрелка скорости героя",
}
const UNITS := {"kill_y": "px", "time_scale": "×", "hitstop_scale": "×"}
const HINTS := {
	"kill_y": "Упавший ниже этой координаты Y герой возвращается на старт, враг — на свою точку.",
	"time_scale": "При малых значениях картинка дёргается — замедляются сами физические тики.",
	"hitstop_scale": "0.02 — почти стоп-кадр, 0.3 — заметное замедление.",
}

@export_group("Правила")
@export_range(0.0, 3000.0, 10.0, "or_greater") var kill_y: float = 900.0
@export_range(0.0, 0.5, 0.01) var hitstop_scale: float = 0.02

@export_group("Отладка")
@export_range(0.1, 1.0, 0.05) var time_scale: float = 1.0
@export var show_hitboxes: bool = true
@export var show_trail: bool = true
@export_range(20, 1000, 10) var trail_points: int = 260
@export var show_velocity: bool = true
