extends Resource
## «Свет» — факелы, освещаемое, ожившие картины. Файл: data/light_default.tres  ·  Вкладка «Свет»
## Радиус, цвет и мерцание конкретного факела — в инспекторе. Код: game/components/light_source.gd, lit.gd, living_painting.gd

const LABELS := {
	"carry_blocks_skills": "Со светом в руках нельзя бить и рисовать",
	"carry_offset_x": "Несомый свет: вперёд от героя",
	"carry_offset_y": "Несомый свет: вверх от героя",
	"carry_follow_speed": "Несомый свет: скорость следования",
	"carry_move_mult": "Подвижность героя со светом",
	"drop_probe": "Положить: искать пол в пределах",
	"lit_check_hz": "Проверка освещённости: раз в секунду",
	"light_softness": "Мягкость края света",
	"awaken_flash_time": "Оживание: вспышка",
	"awaken_shake": "Оживание: дрожь",
	"awaken_shake_time": "Оживание: длительность дрожи",
	"awaken_tint": "Оживание: оттенок ожившего",
	"frozen_tint": "Оттенок замершего",
}
const UNITS := {"carry_offset_x": "px", "carry_offset_y": "px", "carry_follow_speed": "/с", "drop_probe": "px",
	"lit_check_hz": "Гц", "awaken_flash_time": "с", "awaken_shake": "px", "awaken_shake_time": "с"}
const HINTS := {
	"carry_blocks_skills": "Вкл — пока герой несёт факел, удар, линия и волна недоступны.",
	"carry_follow_speed": "Насколько быстро свет догоняет точку у героя (больше — жёстче).",
	"lit_check_hz": "Освещённость считается не каждый кадр, а с этой частотой (лучи видимости недешёвые).",
	"light_softness": "0 — резкий круг света, 1 — плавное затухание к краю.",
}

@export_group("Перенос")
@export var carry_blocks_skills: bool = true
@export_range(-60.0, 60.0, 1.0) var carry_offset_x: float = 16.0
@export_range(-60.0, 80.0, 1.0) var carry_offset_y: float = 14.0
@export_range(1.0, 40.0, 0.5) var carry_follow_speed: float = 14.0
@export_range(0.0, 1.0, 0.05) var carry_move_mult: float = 0.9
@export_range(16.0, 600.0, 8.0) var drop_probe: float = 200.0

@export_group("Освещённость")
@export_range(2.0, 60.0, 1.0) var lit_check_hz: float = 20.0
@export_range(0.0, 1.0, 0.05) var light_softness: float = 0.7

@export_group("Ожившая картина")
@export_range(0.0, 1.0, 0.01) var awaken_flash_time: float = 0.25
@export_range(0.0, 12.0, 0.5) var awaken_shake: float = 3.0
@export_range(0.0, 1.0, 0.01) var awaken_shake_time: float = 0.25
@export var awaken_tint: Color = Color(1.0, 0.92, 0.75)
@export var frozen_tint: Color = Color(0.75, 0.68, 0.6)
