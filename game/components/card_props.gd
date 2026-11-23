extends Resource
## Свойства карточки (подбор касанием).

const LABELS := {"card_id": "Карточка", "targets": "Цели связей", "link_mode": "Что делать с целями"}
const HINTS := {"card_id": "id из content/dialog/cards.csv (тексты — content/i18n/cards.csv, ключи card.<id>.title / where / when / text). Уведомление — картинка, название, «где и когда»; игра не останавливается.",
	"targets": "Срабатывают при подборе."}
const PICKS := {"card_id": "card"}

@export var card_id: String = ""
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 0
