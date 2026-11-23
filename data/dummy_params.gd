extends Resource
## Манекен-враг (общие параметры для всех манекенов на полигоне). Файл: data/dummy_default.tres  ·  Вкладка «Враг»
## Поведение конкретного манекена можно переопределить при создании (behavior_override, contact_override).

const LABELS := {
	"behavior": "Поведение по умолчанию",
	"max_hp": "Здоровье",
	"kb_resist": "Сопротивление отбрасыванию",
	"kb_friction": "Торможение после отброса",
	"stun_time": "Оглушение после удара",
	"hit_interrupts": "Удар прерывает атаку",
	"avoid_ledges": "Не бегать в пропасть",
	"gravity": "Гравитация",
	"max_fall": "Макс. скорость падения",
	"move_speed": "Скорость патруля",
	"patrol_range": "Радиус патруля",
	"sight_range": "Дальность обнаружения",
	"sight_height": "Обнаружение по высоте (±)",
	"charge_windup": "Таран: замах (телеграф)",
	"charge_speed": "Таран: скорость",
	"charge_time": "Таран: длительность",
	"charge_recover": "Таран: окно уязвимости",
	"recover_brake": "Таран: торможение после (× скорости)",
	"punish_mult": "Множитель урона в окне уязвимости",
	"contact_damage": "Урон при касании",
	"respawn_time": "Пауза до возрождения",
	"body_width": "Ширина тела",
	"body_height": "Высота тела",
	"ledge_probe_x": "Проверка края: вперёд",
	"ledge_probe_down": "Проверка края: вниз",
	"flash_time": "Вспышка при попадании",
}
const UNITS := {
	"kb_friction": "px/с²", "stun_time": "с", "gravity": "px/с²", "max_fall": "px/с", "move_speed": "px/с",
	"patrol_range": "px", "sight_range": "px", "sight_height": "px", "charge_windup": "с", "charge_speed": "px/с",
	"charge_time": "с", "charge_recover": "с", "respawn_time": "с", "body_width": "px", "body_height": "px",
	"ledge_probe_x": "px", "ledge_probe_down": "px", "flash_time": "с",
}
const HINTS := {
	"kb_resist": "0 — отлетает полностью, 1 — не сдвигается.",
	"hit_interrupts": "Если выключено — во время замаха и тарана манекен в «броне»: урон проходит, но он не сбивается.",
	"charge_recover": "После тарана манекен стоит синим — урон умножается на «Множитель урона».",
}

@export_group("Общее")
@export_enum("Стоит", "Патруль", "Таран") var behavior: int = 0
@export_range(10.0, 1000.0, 10.0, "or_greater") var max_hp: float = 100.0
@export_range(0.0, 1.0, 0.05) var kb_resist: float = 0.0
@export_range(100.0, 4000.0, 50.0) var kb_friction: float = 1200.0
@export_range(0.0, 1.0, 0.01) var stun_time: float = 0.3
@export var hit_interrupts: bool = true
@export var avoid_ledges: bool = true
@export_range(0.0, 3000.0, 50.0) var gravity: float = 1800.0
@export_range(200.0, 2000.0, 50.0) var max_fall: float = 1200.0
@export_range(0.0, 20.0, 0.5) var respawn_time: float = 2.0
@export_range(0.0, 60.0, 1.0) var contact_damage: float = 10.0
@export_range(0.0, 0.5, 0.01) var flash_time: float = 0.12

@export_group("Тело")
@export_range(8.0, 160.0, 1.0) var body_width: float = 40.0
@export_range(8.0, 160.0, 1.0) var body_height: float = 52.0
@export_range(0.0, 80.0, 1.0) var ledge_probe_x: float = 28.0
@export_range(4.0, 120.0, 1.0) var ledge_probe_down: float = 40.0

@export_group("Патруль")
@export_range(20.0, 300.0, 5.0) var move_speed: float = 80.0
@export_range(20.0, 600.0, 10.0) var patrol_range: float = 160.0

@export_group("Таран (мини-босс)")
@export_range(100.0, 900.0, 10.0) var sight_range: float = 420.0
@export_range(20.0, 400.0, 10.0) var sight_height: float = 120.0
@export_range(0.1, 2.0, 0.05) var charge_windup: float = 0.6
@export_range(100.0, 1200.0, 10.0) var charge_speed: float = 520.0
@export_range(0.1, 2.0, 0.05) var charge_time: float = 0.7
@export_range(0.1, 3.0, 0.05) var charge_recover: float = 0.8
@export_range(0.5, 10.0, 0.5) var recover_brake: float = 4.0
@export_range(1.0, 4.0, 0.1) var punish_mult: float = 2.0
