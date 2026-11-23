extends Resource
## Ближняя атака героя и получение урона. Файл: data/attack_default.tres  ·  Вкладка «Удар»
## Тайминги задаются в секундах; HUD показывает их же в кадрах (60 fps).
## Фазы удара: замах → активная фаза (хитбокс бьёт) → восстановление → пауза.

const LABELS := {
	"windup": "Замах (до удара)",
	"active": "Активная фаза (хитбокс включён)",
	"recovery": "Восстановление",
	"cooldown": "Пауза до следующего удара",
	"buffer": "Буфер нажатия",
	"damage": "Урон",
	"reach_x": "Хитбокс: длина",
	"reach_y": "Хитбокс: высота",
	"offset_x": "Хитбокс: отступ от тела",
	"offset_y": "Хитбокс: сдвиг по вертикали",
	"knockback_x": "Отбрасывание цели (вперёд)",
	"knockback_y": "Отбрасывание цели (вверх)",
	"hitstop": "Хитстоп при попадании",
	"hit_shake": "Тряска камеры при попадании",
	"hit_shake_time": "Длительность тряски при попадании",
	"self_recoil": "Отдача героя назад",
	"lunge_speed": "Рывок вперёд при ударе",
	"move_mult": "Подвижность во время удара",
	"allow_air": "Можно бить в воздухе",
	"jump_cancel": "Прыжок отменяет восстановление",
	"max_hp": "Здоровье героя",
	"invuln_time": "Неуязвимость после урона",
	"hurt_stun": "Оглушение после урона",
	"hurt_knockback_x": "Отброс героя по X",
	"hurt_knockback_y": "Отброс героя вверх",
	"hurt_hitstop": "Хитстоп при получении урона",
	"hurt_shake": "Тряска при получении урона",
	"hurt_shake_time": "Длительность тряски при уроне",
	"respawn_delay": "Пауза до возрождения",
}
const UNITS := {
	"windup": "с", "active": "с", "recovery": "с", "cooldown": "с", "buffer": "с",
	"reach_x": "px", "reach_y": "px", "offset_x": "px", "offset_y": "px",
	"knockback_x": "px/с", "knockback_y": "px/с", "hitstop": "с", "hit_shake": "px", "hit_shake_time": "с",
	"self_recoil": "px/с", "lunge_speed": "px/с", "invuln_time": "с", "hurt_stun": "с",
	"hurt_knockback_x": "px/с", "hurt_knockback_y": "px/с", "hurt_hitstop": "с",
	"hurt_shake": "px", "hurt_shake_time": "с", "respawn_delay": "с",
}
const HINTS := {
	"buffer": "Нажатие удара во время предыдущего запоминается на это время.",
	"offset_x": "Расстояние от центра героя до ближнего края хитбокса.",
	"move_mult": "Множитель скорости бега, пока идёт удар. 0 — стоит на месте.",
	"jump_cancel": "Во время восстановления можно прыгнуть — удар прервётся.",
}

@export_group("Тайминги")
@export_range(0.0, 0.5, 0.01) var windup: float = 0.08
@export_range(0.01, 0.4, 0.01) var active: float = 0.08
@export_range(0.0, 0.8, 0.01) var recovery: float = 0.18
@export_range(0.0, 0.5, 0.01) var cooldown: float = 0.05
@export_range(0.0, 0.4, 0.01) var buffer: float = 0.12

@export_group("Хитбокс")
@export_range(16.0, 160.0, 2.0, "or_greater") var reach_x: float = 56.0
@export_range(16.0, 160.0, 2.0, "or_greater") var reach_y: float = 44.0
@export_range(-20.0, 60.0, 1.0) var offset_x: float = 12.0
@export_range(-60.0, 60.0, 1.0) var offset_y: float = -2.0

@export_group("Эффект удара")
@export_range(1.0, 100.0, 1.0, "or_greater") var damage: float = 10.0
@export_range(0.0, 900.0, 10.0, "or_greater") var knockback_x: float = 320.0
@export_range(0.0, 900.0, 10.0, "or_greater") var knockback_y: float = 140.0
@export_range(0.0, 0.3, 0.01) var hitstop: float = 0.07
@export_range(0.0, 20.0, 0.5) var hit_shake: float = 4.0
@export_range(0.0, 0.5, 0.01) var hit_shake_time: float = 0.12
@export_range(0.0, 500.0, 10.0) var self_recoil: float = 60.0

@export_group("Движение при ударе")
@export_range(0.0, 600.0, 10.0) var lunge_speed: float = 140.0
@export_range(0.0, 1.0, 0.05) var move_mult: float = 0.3
@export var allow_air: bool = true
@export var jump_cancel: bool = true

@export_group("Получение урона")
@export_range(10.0, 300.0, 5.0, "or_greater") var max_hp: float = 100.0
@export_range(0.0, 3.0, 0.05) var invuln_time: float = 1.0
@export_range(0.0, 1.0, 0.01) var hurt_stun: float = 0.25
@export_range(0.0, 800.0, 10.0) var hurt_knockback_x: float = 300.0
@export_range(0.0, 800.0, 10.0) var hurt_knockback_y: float = 220.0
@export_range(0.0, 0.3, 0.01) var hurt_hitstop: float = 0.08
@export_range(0.0, 20.0, 0.5) var hurt_shake: float = 6.0
@export_range(0.0, 0.5, 0.01) var hurt_shake_time: float = 0.2
@export_range(0.2, 5.0, 0.1) var respawn_delay: float = 1.0
