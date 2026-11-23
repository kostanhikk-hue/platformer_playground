extends Resource
## «Линия-охра»: прямой штрих — оружие и временная платформа. Файл: data/ink_default.tres  ·  Вкладка «Линия»
## Блоки «Прицел», «Старт», «Жизнь», «Твёрдость», «Урон», «Вид» устроены так же, как у волны
## (общий код: core/aim.gd и game/ink/stroke_base.gd).

const LABELS := {
	"max_ink": "Запас чернил",
	"cost": "Цена штриха",
	"regen_rate": "Восстановление чернил",
	"regen_delay": "Задержка перед восстановлением",
	"regen_while_charging": "Восстанавливать во время заряда",
	"length": "Длина штриха",
	"thickness": "Толщина штриха",
	"draw_time": "Время рисования",
	"cooldown": "Пауза между штрихами",
	"input_buffer": "Буфер нажатия",
	"max_strokes": "Макс. штрихов одновременно",
	"charge_enabled": "Заряд: удержание, удар при отпускании",
	"charge_time": "Время полного заряда",
	"charge_curve": "Кривая заряда (1 = линейно, >1 = медленный старт)",
	"auto_release": "Бить автоматически при полном заряде",
	"charge_move_mult": "Подвижность во время заряда",
	"charge_cost_mode": "Расход чернил при заряде",
	"charge_cost_max": "Цена при полном заряде (× базовой)",
	"charge_drain_rate": "Утечка чернил при удержании",
	"charge_length_min": "Длина при нулевом заряде (× базовой)",
	"charge_length_max": "Длина при полном заряде (× базовой)",
	"charge_thick_min": "Толщина при нулевом заряде (× базовой)",
	"charge_thick_max": "Толщина при полном заряде (× базовой)",
	"charge_damage_min": "Урон при нулевом заряде (× базового)",
	"charge_damage_max": "Урон при полном заряде (× базового)",
	"charge_knock_min": "Отброс при нулевом заряде (× базового)",
	"charge_knock_max": "Отброс при полном заряде (× базового)",
	"charge_draw_min": "Время рисования при нулевом заряде (× базового)",
	"charge_draw_max": "Время рисования при полном заряде (× базового)",
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
	"lifetime": "Время жизни штриха",
	"fade_time": "Мигание перед исчезновением",
	"fade_blink_hz": "Частота мигания",
	"fade_min_alpha": "Прозрачность при мигании",
	"one_way": "Пологий штрих проходим снизу",
	"solid_angle_deg": "Сплошная стена, если круче",
	"damage": "Урон штриха",
	"damage_window": "Окно урона (с начала рисования)",
	"knockback_x": "Отбрасывание по X",
	"knockback_y": "Отбрасывание вверх",
	"hitstop": "Хитстоп при попадании",
	"hit_shake": "Тряска при попадании",
	"hit_shake_time": "Длительность тряски",
	"hit_pad_along": "Запас хитбокса вдоль штриха",
	"hit_pad_across": "Запас хитбокса поперёк",
	"color": "Цвет",
	"show_preview": "Показывать предпросмотр",
}
const UNITS := {
	"regen_rate": "/с", "charge_time": "с", "charge_drain_rate": "охры/с", "regen_delay": "с", "length": "px", "thickness": "px", "draw_time": "с",
	"lifetime": "с", "fade_time": "с", "fade_blink_hz": "Гц", "cooldown": "с", "input_buffer": "с", "start_gap": "px",
	"base_angle": "°", "aim_offset": "°", "max_aim_up": "°", "max_aim_down": "°", "snap_degrees": "°",
	"min_cursor_dist": "px", "origin_x": "px", "origin_y": "px", "solid_angle_deg": "°",
	"damage_window": "с", "knockback_x": "px/с", "knockback_y": "px/с", "hitstop": "с",
	"hit_shake": "px", "hit_shake_time": "с", "hit_pad_along": "px", "hit_pad_across": "px",
}
const HINTS := {
	"regen_while_charging": "Выключено — пока держишь заряд, охра не восстанавливается.",
	"charge_enabled": "Выключено — штрих выходит сразу по нажатию. Включено — держишь кнопку, штрих растёт (видно по предпросмотру и кольцу), отпускаешь — удар.",
	"charge_cost_mode": "При выпуске — платишь при отпускании: цена × от 1 до «Цены при полном заряде». Во время удержания — при отпускании базовая цена, а пока держишь, охра утекает; кончилась — заряд перестаёт расти.",
	"charge_cost_max": "Только для режима «При выпуске». Не хватает охры на полный заряд — бьёт тем, что можно оплатить.",
	"charge_drain_rate": "Только для режима «Во время удержания». Базовая цена всегда остаётся в запасе на сам удар.",
	"charge_curve": "Показатель степени: заряд = (время / полное)^кривая.",
	"aim_mode": "Фиксированный — всегда базовый угол в сторону взгляда. Курсор: сторона — курсор выбирает только лево/право. Курсор: сторона и угол — штрих идёт к курсору.",
	"base_angle": "Направление относительно героя: 0° — вперёд, 90° — вверх, −90° — вниз, 180° — назад. Работает во всех режимах.",
	"aim_offset": "Прибавляется к углу курсора (режим «сторона и угол»).",
	"aim_influence": "1 — точно к курсору, 0 — всегда базовый угол, 0.5 — посередине.",
	"max_aim_up": "Ограничивает только наведение курсором.",
	"min_cursor_dist": "Если курсор ближе к герою — прицел не меняется.",
	"solid_angle_deg": "Штрих круче этого угла к горизонту — сплошная стена (не проходится снизу).",
	"damage_window": "Штрих бьёт только первые N секунд жизни.",
}

@export_group("Ресурс")
@export_range(10.0, 300.0, 5.0, "or_greater") var max_ink: float = 100.0
@export_range(1.0, 100.0, 1.0) var cost: float = 25.0
@export_range(0.0, 100.0, 1.0, "or_greater") var regen_rate: float = 20.0
@export_range(0.0, 3.0, 0.05) var regen_delay: float = 0.8
@export var regen_while_charging: bool = true

@export_group("Штрих")
@export_range(40.0, 600.0, 10.0, "or_greater") var length: float = 220.0
@export_range(4.0, 40.0, 1.0, "or_greater") var thickness: float = 12.0
@export_range(0.0, 0.6, 0.01) var draw_time: float = 0.12
@export_range(0.0, 1.0, 0.05) var cooldown: float = 0.15
@export_range(0.0, 0.4, 0.01) var input_buffer: float = 0.12
@export_range(1, 8, 1, "or_greater") var max_strokes: int = 3

@export_group("Заряд (удержание)")
@export var charge_enabled: bool = false
@export_range(0.1, 3.0, 0.05) var charge_time: float = 0.8
@export_range(0.3, 3.0, 0.1) var charge_curve: float = 1.0
@export var auto_release: bool = false
@export_range(0.0, 1.0, 0.05) var charge_move_mult: float = 0.5
@export_enum("При выпуске", "Во время удержания") var charge_cost_mode: int = 0
@export_range(1.0, 4.0, 0.05) var charge_cost_max: float = 2.0
@export_range(0.0, 200.0, 5.0, "or_greater") var charge_drain_rate: float = 40.0
@export_range(0.1, 1.5, 0.05) var charge_length_min: float = 0.5
@export_range(0.5, 4.0, 0.05) var charge_length_max: float = 1.8
@export_range(0.3, 1.5, 0.05) var charge_thick_min: float = 0.8
@export_range(0.5, 3.0, 0.05) var charge_thick_max: float = 1.5
@export_range(0.0, 1.5, 0.05) var charge_damage_min: float = 0.5
@export_range(0.5, 5.0, 0.05) var charge_damage_max: float = 2.5
@export_range(0.0, 1.5, 0.05) var charge_knock_min: float = 0.6
@export_range(0.5, 4.0, 0.05) var charge_knock_max: float = 1.8
@export_range(0.1, 2.0, 0.05) var charge_draw_min: float = 1.0
@export_range(0.1, 3.0, 0.05) var charge_draw_max: float = 1.0

@export_group("Прицел")
@export_enum("Фиксированный угол", "Курсор: сторона", "Курсор: сторона и угол") var aim_mode: int = 2
@export_range(-180.0, 180.0, 1.0) var base_angle: float = 0.0
@export_range(-90.0, 90.0, 1.0) var aim_offset: float = 0.0
@export_range(0.0, 1.0, 0.05) var aim_influence: float = 1.0
@export_range(0.0, 180.0, 1.0) var max_aim_up: float = 180.0
@export_range(0.0, 180.0, 1.0) var max_aim_down: float = 180.0
@export_range(0.0, 90.0, 5.0) var snap_degrees: float = 0.0
@export_range(0.0, 60.0, 1.0) var min_cursor_dist: float = 10.0

@export_group("Старт")
@export_range(-60.0, 60.0, 1.0) var origin_x: float = 0.0
@export_range(-60.0, 60.0, 1.0) var origin_y: float = 0.0
@export_range(0.0, 80.0, 1.0) var start_gap: float = 24.0

@export_group("Жизнь")
@export_range(0.5, 20.0, 0.5, "or_greater") var lifetime: float = 5.0
@export_range(0.0, 3.0, 0.1) var fade_time: float = 1.0
@export_range(1.0, 20.0, 0.5) var fade_blink_hz: float = 7.0
@export_range(0.0, 1.0, 0.05) var fade_min_alpha: float = 0.45

@export_group("Твёрдость")
@export var one_way: bool = true
@export_range(30.0, 90.0, 1.0) var solid_angle_deg: float = 60.0

@export_group("Урон")
@export_range(0.0, 100.0, 1.0, "or_greater") var damage: float = 10.0
@export_range(0.0, 2.0, 0.05) var damage_window: float = 0.3
@export_range(0.0, 900.0, 10.0, "or_greater") var knockback_x: float = 250.0
@export_range(0.0, 900.0, 10.0, "or_greater") var knockback_y: float = 150.0
@export_range(0.0, 0.3, 0.01) var hitstop: float = 0.04
@export_range(0.0, 20.0, 0.5) var hit_shake: float = 0.0
@export_range(0.0, 0.5, 0.01) var hit_shake_time: float = 0.12
@export_range(0.0, 40.0, 1.0) var hit_pad_along: float = 12.0
@export_range(0.0, 40.0, 1.0) var hit_pad_across: float = 16.0

@export_group("Вид")
@export var color: Color = Color(0.82, 0.46, 0.14)
@export var show_preview: bool = true
