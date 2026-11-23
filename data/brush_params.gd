extends Resource
## «Кисть»: внешний вид всех штрихов (линия-охра и волна). Только визуал — на коллизию и урон не влияет.
## Каждый штрих рисуется несколькими «щетинками» со своей дрожью, толщиной и концом.
## Файл: data/brush_default.tres  ·  Вкладка «Кисть»  ·  Код: game/ink/brush.gd

const LABELS := {
	"strands": "Щетинок в штрихе",
	"spread": "Разброс щетинок по ширине",
	"strand_width": "Толщина щетинки",
	"opacity": "Непрозрачность",
	"color_var": "Разброс яркости щетинок",
	"underlay": "Тёмная подложка",
	"underlay_width": "Ширина подложки (× толщины)",
	"underlay_dark": "Яркость подложки",
	"underlay_wobble": "Дрожь подложки (× дрожи)",
	"wobble": "Дрожь линии",
	"wobble_freq": "Частота дрожи",
	"width_var": "Разброс толщины вдоль штриха",
	"width_freq": "Частота разброса толщины",
	"taper": "Сужение к концу",
	"taper_start": "Сужение начинается с (доля длины)",
	"ragged": "Рваный конец щетинок",
	"ragged_start": "Рваное начало (× рваного конца)",
	"min_width": "Мин. толщина щетинки",
	"step": "Шаг детализации",
}
const UNITS := {"wobble": "px", "min_width": "px", "step": "px"}
const HINTS := {
	"spread": "1 — щетинки занимают всю толщину штриха; больше — выходят за край.",
	"strand_width": "Множитель: толщина штриха / число щетинок × это.",
	"step": "Через сколько пикселей ставится точка кисти. Меньше — плавнее и дороже.",
	"ragged": "Каждая щетинка обрывается случайно раньше конца — до этой доли длины.",
}

@export_group("Щетина")
@export_range(1, 12, 1, "or_greater") var strands: int = 6
@export_range(0.5, 1.6, 0.05) var spread: float = 1.0
@export_range(0.5, 3.0, 0.05) var strand_width: float = 1.4
@export_range(0.1, 1.0, 0.05) var opacity: float = 0.95
@export_range(0.0, 0.4, 0.01) var color_var: float = 0.15

@export_group("Подложка")
@export var underlay: bool = true
@export_range(0.3, 1.5, 0.05) var underlay_width: float = 0.95
@export_range(0.0, 1.0, 0.05) var underlay_dark: float = 0.33
@export_range(0.0, 1.0, 0.05) var underlay_wobble: float = 0.4

@export_group("Неровность")
@export_range(0.0, 20.0, 0.5) var wobble: float = 3.0
@export_range(0.2, 4.0, 0.1) var wobble_freq: float = 1.0
@export_range(0.0, 0.9, 0.05) var width_var: float = 0.35
@export_range(0.2, 4.0, 0.1) var width_freq: float = 1.0
@export_range(0.0, 1.0, 0.05) var taper: float = 0.5
@export_range(0.0, 1.0, 0.05) var taper_start: float = 0.6
@export_range(0.0, 0.4, 0.01) var ragged: float = 0.12
@export_range(0.0, 1.0, 0.05) var ragged_start: float = 0.4
@export_range(0.1, 3.0, 0.1) var min_width: float = 0.8
@export_range(2.0, 20.0, 1.0) var step: float = 6.0
