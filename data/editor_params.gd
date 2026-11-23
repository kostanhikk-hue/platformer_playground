extends Resource
## Настройки конструктора уровней. Файл: data/editor_default.tres  ·  Вкладка «Редактор»
## Игра этот набор не читает — только конструктор (editor/). Значения по умолчанию для новых контуров
## (толщина, угол стены, проходимость снизу) берутся отсюда, чтобы их можно было подобрать ползунками.

const LABELS := {
	"zoom_min": "Мин. масштаб",
	"zoom_max": "Макс. масштаб",
	"zoom_step": "Шаг масштаба (колесо)",
	"grid_coarse_zoom": "Крупная сетка при масштабе меньше",
	"grid_coarse_every": "Крупная сетка: каждая N-я линия",
	"grid_alpha": "Яркость сетки",
	"handle_size": "Размер ручек",
	"first_point_size": "Размер первой точки",
	"line_width": "Толщина линий контуров",
	"hatch_spacing": "Шаг штриховки",
	"fill_alpha": "Прозрачность заливки тел",
	"lasso_step": "Шаг лассо",
	"merge_dist": "Слияние близких точек",
	"snap_radius": "Радиус магнита",
	"angle_snap_deg": "Шаг привязки угла (Shift)",
	"grid_snap_div": "Шаг привязки к сетке",
	"magnet_default": "Магнит включён при старте",
	"double_click_time": "Двойной клик",
	"default_thickness": "Толщина новых платформ и стен",
	"default_solid_angle": "Угол стены для новых платформ",
	"default_one_way": "Новые платформы проходимы снизу",
	"steep_wall_deg": "Склон круче — уже стена (не подсвечивать)",
	"body_color": "Цвет тел",
	"platform_color": "Цвет платформ",
	"wall_color": "Цвет стен",
	"block_color": "Цвет блоков",
	"kill_color": "Цвет смертельных зон",
	"ice_color": "Оттенок льда",
	"steep_color": "Слишком крутой склон",
	"error_color": "Ошибка контура",
	"select_color": "Выделение",
	"rotate_step": "Шаг поворота (R)",
	"nudge_small": "Сдвиг стрелками",
	"nudge_big": "Сдвиг Shift+стрелки",
	"simplify_tolerance": "Допуск «Упростить»",
	"trace_epsilon": "Точность автообводки",
	"alpha_threshold": "Порог прозрачности",
	"top_edge_min_run": "Мин. ширина верхней кромки",
	"paste_offset": "Смещение копии (Ctrl+D)",
	"undo_depth": "Глубина отмены",
	"undo_merge_time": "Склейка правок одного поля",
	"autosave_interval": "Автосохранение каждые",
	"new_level_w": "Ширина нового уровня",
	"new_level_h": "Высота нового уровня",
	"new_kill_margin": "kill_y нового уровня: ниже границ на",
	"start_void_tiles": "«Старт над пустотой»: искать пол в пределах",
	"thumb_size": "Размер миниатюр",
	"show_hero_ghost": "Силуэт героя при подгонке фона",
}
const UNITS := {
	"zoom_min": "×", "zoom_max": "×", "zoom_step": "×", "grid_coarse_zoom": "×",
	"handle_size": "px экр.", "first_point_size": "px экр.", "line_width": "px экр.", "hatch_spacing": "px экр.",
	"lasso_step": "px", "merge_dist": "px", "snap_radius": "px экр.", "angle_snap_deg": "°", "double_click_time": "с",
	"default_thickness": "px", "default_solid_angle": "°", "steep_wall_deg": "°",
	"rotate_step": "°", "nudge_small": "px", "nudge_big": "px", "simplify_tolerance": "px", "trace_epsilon": "px",
	"top_edge_min_run": "px", "paste_offset": "px", "undo_depth": "шагов", "undo_merge_time": "с",
	"autosave_interval": "с", "new_level_w": "T", "new_level_h": "T", "new_kill_margin": "px", "start_void_tiles": "T",
	"thumb_size": "px",
}
const HINTS := {
	"grid_coarse_zoom": "Если масштаб меньше — рисуется только каждая N-я линия сетки, чтобы не рябило.",
	"lasso_step": "Зажатая ЛКМ при рисовании контура ставит точки автоматически через это расстояние.",
	"merge_dist": "Точки ближе этого расстояния друг к другу сливаются в одну.",
	"snap_radius": "Курсор прилипает к точке или ребру соседнего контура в этом радиусе (экранные пиксели).",
	"grid_snap_div": "Шаг привязки к сетке: тайл T = 32 px, половина или четверть тайла.",
	"default_solid_angle": "Участки платформы круче этого угла — стена (не проходится снизу). Как у штрихов кисти.",
	"steep_wall_deg": "Участки круче «Макс. угла склона» героя подсвечиваются оранжевым (герой съезжает). Круче этого угла — уже стена, не подсвечиваются.",
	"trace_epsilon": "Допуск упрощения при автообводке по прозрачности: больше — меньше точек.",
	"alpha_threshold": "Пиксели прозрачнее порога считаются пустыми при автообводке.",
	"top_edge_min_run": "Кусочки верхней кромки уже этой ширины отбрасываются.",
	"undo_merge_time": "Серия правок одного поля инспектора быстрее этого интервала — один шаг отмены.",
	"start_void_tiles": "Проверка уровня: если под стартом нет коллизии ближе этого — предупреждение.",
}

@export_group("Холст")
@export_range(0.05, 1.0, 0.05) var zoom_min: float = 0.1
@export_range(1.0, 16.0, 0.5) var zoom_max: float = 8.0
@export_range(1.02, 2.0, 0.01) var zoom_step: float = 1.15
@export_range(0.05, 1.0, 0.05) var grid_coarse_zoom: float = 0.35
@export_range(2, 10, 1) var grid_coarse_every: int = 4
@export_range(0.0, 1.0, 0.01) var grid_alpha: float = 0.12

@export_group("Отображение")
@export_range(3.0, 24.0, 1.0) var handle_size: float = 8.0
@export_range(4.0, 32.0, 1.0) var first_point_size: float = 14.0
@export_range(1.0, 6.0, 0.5) var line_width: float = 2.0
@export_range(3.0, 40.0, 1.0) var hatch_spacing: float = 10.0
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.18
@export var body_color: Color = Color(0.55, 0.85, 0.55)
@export var platform_color: Color = Color(0.95, 0.85, 0.35)
@export var wall_color: Color = Color(0.75, 0.6, 1.0)
@export var block_color: Color = Color(0.3, 0.33, 0.4)
@export var kill_color: Color = Color(1.0, 0.25, 0.25)
@export var ice_color: Color = Color(0.45, 0.8, 1.0)
@export var steep_color: Color = Color(1.0, 0.55, 0.1)
@export var error_color: Color = Color(1.0, 0.1, 0.2)
@export var select_color: Color = Color(0.3, 0.75, 1.0)
@export var show_hero_ghost: bool = true

@export_group("Рисование и привязки")
@export_range(2.0, 64.0, 1.0) var lasso_step: float = 16.0
@export_range(0.0, 10.0, 0.5) var merge_dist: float = 2.0
@export_range(0.0, 40.0, 1.0) var snap_radius: float = 10.0
@export_range(1.0, 90.0, 1.0) var angle_snap_deg: float = 15.0
@export_enum("T", "T/2", "T/4") var grid_snap_div: int = 0
@export var magnet_default: bool = true
@export_range(0.1, 1.0, 0.05) var double_click_time: float = 0.35

@export_group("Новые контуры")
@export_range(1.0, 64.0, 1.0) var default_thickness: float = 12.0
@export_range(30.0, 90.0, 1.0) var default_solid_angle: float = 60.0
@export var default_one_way: bool = true
@export_range(45.0, 90.0, 1.0) var steep_wall_deg: float = 85.0

@export_group("Правка")
@export_range(1.0, 90.0, 1.0) var rotate_step: float = 15.0
@export_range(0.25, 8.0, 0.25) var nudge_small: float = 1.0
@export_range(4.0, 128.0, 1.0) var nudge_big: float = 32.0
@export_range(0.25, 32.0, 0.25) var simplify_tolerance: float = 3.0
@export_range(0.25, 16.0, 0.25) var trace_epsilon: float = 2.0
@export_range(0.01, 0.99, 0.01) var alpha_threshold: float = 0.5
@export_range(0.0, 128.0, 1.0) var top_edge_min_run: float = 8.0
@export_range(0.0, 128.0, 4.0) var paste_offset: float = 32.0

@export_group("История и файлы")
@export_range(50, 2000, 10, "or_greater") var undo_depth: int = 200
@export_range(0.0, 3.0, 0.05) var undo_merge_time: float = 1.0
@export_range(10.0, 600.0, 10.0, "or_greater") var autosave_interval: float = 120.0
@export_range(32, 256, 8) var thumb_size: int = 64

@export_group("Новый уровень и проверка")
@export_range(10, 400, 1, "or_greater") var new_level_w: int = 60
@export_range(5, 200, 1, "or_greater") var new_level_h: int = 20
@export_range(0.0, 2000.0, 10.0) var new_kill_margin: float = 300.0
@export_range(1.0, 50.0, 1.0) var start_void_tiles: float = 10.0
