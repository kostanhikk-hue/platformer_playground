extends Resource
## «Волна»: изогнутый штрих от земли. Одновременно пандус (по нему бегают), оружие (подбрасывает врагов)
## и стена (крутая часть останавливает рывок). Размер можно «заряжать» удержанием кнопки.
## Файл: data/wave_default.tres  ·  Вкладка «Волна»
##
## Геометрия: волна строится в своей системе координат —
##   ось «вперёд» = направление прицела (угол относительно героя, блок «Прицел»),
##   ось «подъём»  = перпендикуляр к ней (вверх; «Подъём в обратную сторону» — вниз).
## Кривая — суперэллипс: «Длина» вдоль оси вперёд, «Высота» вдоль оси подъёма.

const LABELS := {
	"reach": "Длина",
	"height": "Высота подъёма",
	"curve_power": "Изгиб (1 = прямая, 2 = дуга, 4 = «угол»)",
	"curve_invert": "Изгиб наоборот (сначала круто, потом полого)",
	"curve_from": "Кривая: начало (доля)",
	"curve_to": "Кривая: конец (доля)",
	"curve_steps": "Точность кривой (сегментов)",
	"keep_upright": "Держать выпуклостью вверх",
	"lift_flip": "Подъём в обратную сторону",
	"wall_extra": "Вертикальный штрих сверху",
	"wall_to_ground": "Стена доходит до основания",
	"thickness": "Толщина штриха",
	"shape_random": "Случайность формы (каждый взмах)",
	"aim_mode": "Режим прицела",
	"base_angle": "Базовый угол",
	"aim_offset": "Смещение от курсора",
	"aim_influence": "Сила курсора",
	"max_aim_up": "Предел вверх",
	"max_aim_down": "Предел вниз",
	"snap_degrees": "Привязка угла (0 = выкл.)",
	"min_cursor_dist": "Мёртвая зона курсора",
	"origin_x": "Старт: вперёд от центра",
	"origin_y": "Старт: вверх от центра",
	"start_gap": "Отступ начала вдоль направления",
	"snap_to_ground": "Прижимать старт к земле",
	"snap_up": "Поиск земли: выше старта",
	"snap_down": "Поиск земли: ниже старта",
	"input_buffer": "Буфер нажатия",
	"windup": "Замах после отпускания",
	"sweep_time": "Время взмаха (рост волны)",
	"recovery": "Восстановление после взмаха",
	"cooldown": "Пауза до следующей волны",
	"cast_move_mult": "Подвижность во время взмаха",
	"spawn_shake": "Тряска при появлении",
	"spawn_shake_time": "Длительность тряски при появлении",
	"charge_enabled": "Заряд: удержание, удар при отпускании",
	"charge_time": "Время полного заряда",
	"charge_curve": "Кривая заряда (1 = линейно, >1 = медленный старт)",
	"auto_release": "Бить автоматически при полном заряде",
	"charge_move_mult": "Подвижность во время заряда",
	"charge_cost_mode": "Расход чернил при заряде",
	"charge_drain_rate": "Утечка чернил при удержании",
	"charge_knock_min": "Отброс при нулевом заряде (× базового)",
	"charge_knock_max": "Отброс при полном заряде (× базового)",
	"charge_reach_min": "Длина при нулевом заряде (× базовой)",
	"charge_reach_max": "Длина при полном заряде (× базовой)",
	"charge_height_min": "Высота при нулевом заряде (× базовой)",
	"charge_height_max": "Высота при полном заряде (× базовой)",
	"charge_wall_min": "Верх. штрих при нулевом заряде (× базового)",
	"charge_wall_max": "Верх. штрих при полном заряде (× базового)",
	"charge_thick_min": "Толщина при нулевом заряде (× базовой)",
	"charge_thick_max": "Толщина при полном заряде (× базовой)",
	"charge_damage_min": "Урон при нулевом заряде (× базового)",
	"charge_damage_max": "Урон при полном заряде (× базового)",
	"charge_cost_max": "Цена при полном заряде (× базовой)",
	"lifetime": "Время жизни",
	"fade_time": "Мигание перед исчезновением",
	"fade_blink_hz": "Частота мигания",
	"fade_min_alpha": "Прозрачность при мигании",
	"max_waves": "Макс. волн одновременно",
	"ink_cost": "Цена в охре (базовая)",
	"one_way": "Пологая часть проходима снизу",
	"solid_angle_deg": "Сплошная часть начинается с угла",
	"damage": "Урон (базовый)",
	"damage_window": "Окно урона (с начала взмаха)",
	"knockback_x": "Отбрасывание вдоль волны",
	"knockback_y": "Подброс от волны",
	"hitstop": "Хитстоп при попадании",
	"hit_shake": "Тряска камеры при попадании",
	"hit_shake_time": "Длительность тряски",
	"hit_pad_along": "Запас хитбокса вдоль",
	"hit_pad_across": "Запас хитбокса поперёк",
	"color": "Цвет",
	"pillar_color": "Цвет вертикальной стены",
	"show_preview": "Показывать предпросмотр",
}
const UNITS := {
	"reach": "px", "height": "px", "wall_extra": "px", "thickness": "px", "shape_random": "±",
	"base_angle": "°", "aim_offset": "°", "max_aim_up": "°", "max_aim_down": "°", "snap_degrees": "°",
	"min_cursor_dist": "px", "origin_x": "px", "origin_y": "px", "start_gap": "px",
	"snap_up": "px", "snap_down": "px", "input_buffer": "с", "windup": "с", "sweep_time": "с",
	"recovery": "с", "cooldown": "с", "spawn_shake": "px", "spawn_shake_time": "с",
	"charge_time": "с", "charge_drain_rate": "охры/с", "lifetime": "с", "fade_time": "с", "fade_blink_hz": "Гц", "ink_cost": "охры",
	"solid_angle_deg": "°", "damage_window": "с", "knockback_x": "px/с", "knockback_y": "px/с",
	"hitstop": "с", "hit_shake": "px", "hit_shake_time": "с", "hit_pad_along": "px", "hit_pad_across": "px",
}
const HINTS := {
	"base_angle": "Начальное направление волны относительно героя: 0° — вдоль земли вперёд, 45° — по диагонали вверх, 90° — вверх, −30° — вниз под склон, 180° — назад. В режиме «Фиксированный» и «Курсор: сторона» волна всегда идёт под этим углом.",
	"aim_mode": "Фиксированный — базовый угол в сторону взгляда. Курсор: сторона — курсор выбирает лево/право, угол = базовый. Курсор: сторона и угол — курсор ещё и поворачивает волну (с учётом «Силы курсора» и пределов).",
	"aim_influence": "1 — волна точно следует курсору, 0 — курсор не влияет на угол, 0.5 — посередине между базовым углом и курсором.",
	"aim_offset": "Прибавляется к углу курсора. Например +20° — волна всегда чуть выше курсора.",
	"max_aim_up": "Ограничивает только наведение курсором; базовый угол задаётся как есть.",
	"curve_power": "1 — прямой пандус; 2 — дуга (четверть эллипса); больше — почти прямой угол: длинный пологий участок и резкая стена.",
	"curve_invert": "Обычно: сначала полого (пандус), в конце круто (стена). Наоборот: сначала круто вверх, потом полого — как навес.",
	"curve_from": "Отрезает начало кривой. 0.3 — волна начинается сразу с середины изгиба.",
	"curve_to": "Отрезает конец кривой. 0.7 — без верхней крутой части.",
	"keep_upright": "Вся форма поворачивается на угол прицела. При углах больше 90° (назад) она перевернулась бы — эта галочка разворачивает подъём обратно вверх. Выключи, если нужен честный жёсткий поворот.",
	"lift_flip": "Волна выгибается вниз от направления, а не вверх. Пригодится для потолка и «свисающих» форм.",
	"origin_y": "−20 — уровень ног при росте 40 px.",
	"snap_to_ground": "Луч ищет землю под точкой старта; если нашёл — волна начинается ровно от поверхности.",
	"solid_angle_deg": "Участки круче этого угла к горизонту — сплошные (стена). Пологие можно проходить снизу, если включено «проходима снизу».",
	"charge_cost_mode": "При выпуске — платишь при отпускании: цена × от 1 до «Цены при полном заряде». Во время удержания — при отпускании базовая цена, а пока держишь, охра утекает; кончилась — заряд перестаёт расти.",
	"charge_drain_rate": "Только для режима «Во время удержания». Базовая цена всегда остаётся в запасе на сам удар.",
	"charge_curve": "Показатель степени: заряд = (время / полное)^кривая.",
}

@export_group("Форма")
@export_range(80.0, 600.0, 10.0, "or_greater") var reach: float = 280.0
@export_range(0.0, 500.0, 10.0, "or_greater") var height: float = 170.0
@export_range(1.0, 4.0, 0.1, "or_greater") var curve_power: float = 2.5
@export var curve_invert: bool = false
@export_range(0.0, 0.95, 0.05) var curve_from: float = 0.0
@export_range(0.05, 1.0, 0.05) var curve_to: float = 1.0
@export_range(2, 48, 1) var curve_steps: int = 16
@export var keep_upright: bool = true
@export var lift_flip: bool = false
@export_range(0.0, 250.0, 10.0, "or_greater") var wall_extra: float = 40.0
@export var wall_to_ground: bool = true
@export_range(6.0, 40.0, 1.0, "or_greater") var thickness: float = 16.0
@export_range(0.0, 0.3, 0.01) var shape_random: float = 0.0

@export_group("Прицел")
@export_enum("Фиксированный угол", "Курсор: сторона", "Курсор: сторона и угол") var aim_mode: int = 2
@export_range(-180.0, 180.0, 1.0) var base_angle: float = 0.0
@export_range(-90.0, 90.0, 1.0) var aim_offset: float = 0.0
@export_range(0.0, 1.0, 0.05) var aim_influence: float = 1.0
@export_range(0.0, 180.0, 1.0) var max_aim_up: float = 70.0
@export_range(0.0, 180.0, 1.0) var max_aim_down: float = 0.0
@export_range(0.0, 90.0, 5.0) var snap_degrees: float = 0.0
@export_range(0.0, 60.0, 1.0) var min_cursor_dist: float = 8.0

@export_group("Старт")
@export_range(-60.0, 60.0, 1.0) var origin_x: float = 0.0
@export_range(-60.0, 60.0, 1.0) var origin_y: float = -20.0
@export_range(0.0, 80.0, 1.0) var start_gap: float = 20.0
@export var snap_to_ground: bool = true
@export_range(0.0, 60.0, 1.0) var snap_up: float = 14.0
@export_range(0.0, 200.0, 5.0) var snap_down: float = 70.0

@export_group("Взмах")
@export_range(0.0, 0.4, 0.01) var input_buffer: float = 0.15
@export_range(0.0, 0.4, 0.01) var windup: float = 0.06
@export_range(0.0, 0.6, 0.01) var sweep_time: float = 0.18
@export_range(0.0, 1.0, 0.01) var recovery: float = 0.25
@export_range(0.0, 3.0, 0.05) var cooldown: float = 0.5
@export_range(0.0, 1.0, 0.05) var cast_move_mult: float = 0.7
@export_range(0.0, 10.0, 0.5) var spawn_shake: float = 2.0
@export_range(0.0, 0.5, 0.01) var spawn_shake_time: float = 0.1

@export_group("Заряд (удержание)")
@export var charge_enabled: bool = true
@export_range(0.1, 3.0, 0.05) var charge_time: float = 0.8
@export_range(0.3, 3.0, 0.1) var charge_curve: float = 1.0
@export var auto_release: bool = false
@export_range(0.0, 1.0, 0.05) var charge_move_mult: float = 0.5
@export_enum("При выпуске", "Во время удержания") var charge_cost_mode: int = 0
@export_range(0.0, 200.0, 5.0, "or_greater") var charge_drain_rate: float = 40.0
@export_range(0.1, 1.5, 0.05) var charge_reach_min: float = 0.6
@export_range(0.5, 4.0, 0.05) var charge_reach_max: float = 1.6
@export_range(0.1, 1.5, 0.05) var charge_height_min: float = 0.5
@export_range(0.5, 4.0, 0.05) var charge_height_max: float = 1.8
@export_range(0.0, 1.5, 0.05) var charge_wall_min: float = 0.5
@export_range(0.5, 4.0, 0.05) var charge_wall_max: float = 1.8
@export_range(0.3, 1.5, 0.05) var charge_thick_min: float = 0.8
@export_range(0.5, 3.0, 0.05) var charge_thick_max: float = 1.5
@export_range(0.1, 1.5, 0.05) var charge_damage_min: float = 0.6
@export_range(0.5, 5.0, 0.05) var charge_damage_max: float = 2.0
@export_range(0.0, 1.5, 0.05) var charge_knock_min: float = 1.0
@export_range(0.5, 4.0, 0.05) var charge_knock_max: float = 1.0
@export_range(1.0, 4.0, 0.05) var charge_cost_max: float = 1.8

@export_group("Жизнь и цена")
@export_range(0.5, 20.0, 0.5, "or_greater") var lifetime: float = 4.0
@export_range(0.0, 3.0, 0.1) var fade_time: float = 0.8
@export_range(1.0, 20.0, 0.5) var fade_blink_hz: float = 7.0
@export_range(0.0, 1.0, 0.05) var fade_min_alpha: float = 0.45
@export_range(1, 4, 1, "or_greater") var max_waves: int = 2
@export_range(0.0, 100.0, 1.0) var ink_cost: float = 30.0

@export_group("Твёрдость")
@export var one_way: bool = true
@export_range(30.0, 90.0, 1.0) var solid_angle_deg: float = 60.0

@export_group("Урон")
@export_range(0.0, 100.0, 1.0, "or_greater") var damage: float = 15.0
@export_range(0.0, 1.5, 0.05) var damage_window: float = 0.35
@export_range(0.0, 900.0, 10.0, "or_greater") var knockback_x: float = 260.0
@export_range(0.0, 1200.0, 10.0, "or_greater") var knockback_y: float = 520.0
@export_range(0.0, 0.3, 0.01) var hitstop: float = 0.06
@export_range(0.0, 20.0, 0.5) var hit_shake: float = 5.0
@export_range(0.0, 0.5, 0.01) var hit_shake_time: float = 0.12
@export_range(0.0, 40.0, 1.0) var hit_pad_along: float = 8.0
@export_range(0.0, 40.0, 1.0) var hit_pad_across: float = 14.0

@export_group("Вид")
@export var color: Color = Color(0.9, 0.24, 0.18)
@export var pillar_color: Color = Color(0.78, 0.2, 0.15)
@export var show_preview: bool = true
