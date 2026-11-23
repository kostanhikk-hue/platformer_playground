extends Resource
## Простые интерактивные объекты: рычаг, плита, дверь, ломкая и движущаяся платформа, чекпоинт, карточки.
## Файл: data/objects_default.tres  ·  Вкладка «Объекты». То, что отличается у экземпляра, — в инспекторе конструктора.

const LABELS := {
	"lever_anim_time": "Рычаг: время поворота",
	"plate_depth": "Плита: насколько проседает",
	"crumble_shake": "Ломкая: дрожь перед обрушением",
	"crumble_fall_speed": "Ломкая: скорость падения обломков",
	"crumble_fade": "Ломкая: обломки исчезают за",
	"crush_mode": "Если платформа зажала героя",
	"crush_frames": "Зажат дольше — срабатывает",
	"crush_push": "Выталкивание: искать свободное место в пределах",
	"block_flash": "Разрушаемый блок: вспышка при ударе",
	"block_shake": "Разрушаемый блок: тряска при разрушении",
	"ink_pickup_flash": "Источник охры: вспышка при подборе",
	"checkpoint_glow": "Чекпоинт: свечение активного",
	"card_notify_time": "Карточка: уведомление держится",
	"card_notify_width": "Карточка: ширина уведомления",
}
const UNITS := {"lever_anim_time": "с", "plate_depth": "px", "crumble_shake": "px", "crumble_fall_speed": "px/с",
	"crumble_fade": "с", "crush_frames": "кадров", "crush_push": "px", "block_flash": "с", "block_shake": "px",
	"ink_pickup_flash": "с", "checkpoint_glow": "px", "card_notify_time": "с", "card_notify_width": "px"}
const HINTS := {
	"crush_mode": "Вытолкнуть — герой переносится в ближайшее свободное место. Погибнуть — как при падении в пропасть (возврат на чекпоинт).",
	"crush_frames": "Герой считается зажатым, если пересекается с твёрдым столько физических кадров подряд.",
}

@export_group("Рычаг и плита")
@export_range(0.0, 1.0, 0.01) var lever_anim_time: float = 0.15
@export_range(0.0, 16.0, 0.5) var plate_depth: float = 5.0

@export_group("Ломкая платформа")
@export_range(0.0, 10.0, 0.5) var crumble_shake: float = 2.5
@export_range(0.0, 1500.0, 10.0) var crumble_fall_speed: float = 500.0
@export_range(0.0, 3.0, 0.05) var crumble_fade: float = 0.5

@export_group("Движущаяся платформа")
@export_enum("Вытолкнуть", "Погибнуть") var crush_mode: int = 0
@export_range(1, 30, 1) var crush_frames: int = 3
@export_range(8.0, 200.0, 4.0) var crush_push: float = 64.0

@export_group("Прочее")
@export_range(0.0, 0.5, 0.01) var block_flash: float = 0.1
@export_range(0.0, 20.0, 0.5) var block_shake: float = 4.0
@export_range(0.0, 1.0, 0.01) var ink_pickup_flash: float = 0.3
@export_range(0.0, 40.0, 1.0) var checkpoint_glow: float = 14.0
@export_range(0.5, 10.0, 0.1) var card_notify_time: float = 3.0
@export_range(160.0, 600.0, 10.0) var card_notify_width: float = 340.0
