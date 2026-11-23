extends Resource
## Свойства манекена-холста: манекен + закрашивание по телу. Закрашен на 100 % — исчезает.

const LABELS := {"behavior": "Поведение", "contact_damage": "Урон касанием", "facing": "Смотрит",
	"path_uid": "Путь (для «По пути»)", "hp_damage": "Урон по здоровью", "accept_ink": "Закрашивает линия",
	"accept_wave": "Закрашивает волна", "accept_melee": "Закрашивает удар", "paint_strength": "Сила закрашивания",
	"wash_rate": "Отмывание", "thresholds": "Пороги событий, %", "reset_on_death": "Откат при смерти героя",
	"knockback_mult": "Отброс при попадании (× обычного)"}
const UNITS := {"paint_strength": "×", "wash_rate": "%/с"}
const HINTS := {
	"hp_damage": "Выключено — удары не отнимают здоровье: победить можно только закрашиванием (заготовка боссов).",
	"wash_rate": "Сколько процентов краски в секунду манекен «стряхивает».",
	"contact_damage": "−1 — как на вкладке «Враг». 0 — безопасен.",
	"knockback_mult": "Холст почти не отлетает от штрихов, иначе его трудно закрасить: волна подбрасывает манекена, и он улетает из-под кисти. 1 — как обычный манекен.",
}
const PICKS := {"path_uid": "path"}

@export_group("Манекен")
@export_enum("Стоит", "Патруль", "Таран", "По пути") var behavior: int = 1
@export_range(-1.0, 60.0, 1.0, "or_greater") var contact_damage: float = -1.0
@export_enum("Вправо", "Влево") var facing: int = 0
@export var path_uid: String = ""
@export var hp_damage: bool = false
@export_range(0.0, 1.0, 0.05) var knockback_mult: float = 0.15
@export_group("Закрашивание")
@export var accept_ink: bool = true
@export var accept_wave: bool = true
@export var accept_melee: bool = true
@export_range(0.2, 4.0, 0.05, "or_greater") var paint_strength: float = 2.0
@export_range(0.0, 50.0, 0.5, "or_greater") var wash_rate: float = 4.0
@export var thresholds: String = "25, 50, 100"
@export var reset_on_death: bool = true
