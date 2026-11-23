extends Resource
## Свойства манекена на уровне (поверх общих параметров вкладки «Враг»).

const LABELS := {"behavior": "Поведение", "contact_damage": "Урон касанием", "facing": "Смотрит",
	"path_uid": "Путь (для «По пути»)", "reset_on_death": "Откат при смерти героя"}
const HINTS := {
	"contact_damage": "−1 — как на вкладке «Враг» (contact_damage). 0 — безопасен.",
	"path_uid": "uid пути (инструмент «Путь», L). Манекен ходит по его точкам вместо радиуса патруля.",
	"reset_on_death": "Герой умер — манекен возвращается к состоянию на последнем чекпоинте (жив/мёртв, место).",
}
## Поля-ссылки: конструктор добавляет к ним пипетку «выбрать на холсте» (path — пути, object — объекты).
const PICKS := {"path_uid": "path"}

@export_enum("Стоит", "Патруль", "Таран", "По пути") var behavior: int = 0
@export_range(-1.0, 60.0, 1.0, "or_greater") var contact_damage: float = -1.0
@export_enum("Вправо", "Влево") var facing: int = 0
@export var path_uid: String = ""
@export var reset_on_death: bool = true
