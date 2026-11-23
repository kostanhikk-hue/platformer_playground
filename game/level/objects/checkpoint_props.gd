extends Resource
## Свойства чекпоинта. Положение объекта — центр героя при возрождении.

const LABELS := {"activation": "Как активируется", "heal_full": "Лечить полностью", "refill_ink": "Пополнять охру",
	"look": "Вид", "start_active": "Активен с начала"}
const HINTS := {
	"activation": "Касанием — герой проходит через него. Взаимодействием — E рядом. По связи — включается другим объектом: так делается «ладонь» (рисуемый контур → цель: чекпоинт).",
	"heal_full": "При активации герой полностью лечится.",
	"refill_ink": "При активации запас охры заполняется.",
}

@export_enum("Касанием", "Взаимодействием", "По связи (дорисовкой)") var activation: int = 0
@export var heal_full: bool = true
@export var refill_ink: bool = true
@export_enum("Флажок", "Ладонь") var look: int = 0
@export var start_active: bool = false
