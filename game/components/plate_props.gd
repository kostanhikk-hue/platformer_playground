extends Resource
## Свойства нажимной плиты. «Что нажимает» — галочки (до них было одно поле pressed_by: 0 герой / 1 враг /
## 2 любое тело; старые уровни переводятся в галочки при загрузке — migrate_pressed_by, вызывает LevelData).

const LABELS := {"press_hero": "Нажимает: герой", "press_enemies": "Нажимает: враги", "press_strokes": "Нажимает: штрихи",
	"press_bodies": "Нажимает: другие тела", "width": "Ширина", "release_delay": "Задержка отпускания",
	"targets": "Цели связей", "link_mode": "Что делать с целями", "reset_on_death": "Откат при смерти героя"}
const UNITS := {"width": "px", "release_delay": "с"}
const HINTS := {
	"press_strokes": "Линия, волна и результат рисуемого контура со слоем «штрихи». Линия через плиту держит её нажатой, пока не исчезнет.",
	"press_bodies": "Остальные твёрдые объекты: двери, платформы, результат контура со слоем «мир»… (кроме блоков уровня).",
	"release_delay": "Плита остаётся нажатой столько секунд после того, как с неё сошли.",
	"link_mode": "Обычно «Следовать»: стоишь — дверь открыта, сошёл — закрыта.",
}

@export var press_hero: bool = true
@export var press_enemies: bool = false
@export var press_strokes: bool = false
@export var press_bodies: bool = false
@export_range(16.0, 256.0, 4.0, "or_greater") var width: float = 48.0
@export_range(0.0, 5.0, 0.05) var release_delay: float = 0.0
@export var targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var link_mode: int = 3
@export var reset_on_death: bool = true


## Старое поле pressed_by (0 — герой, 1 — враг, 2 — любое тело) → галочки. Меняет словарь свойств на месте;
## без pressed_by ничего не делает. «Любое тело» = все четыре галочки (раньше штрихи были в слое «Мир»).
static func migrate_pressed_by(d: Dictionary) -> void:
	if not d.has("pressed_by"):
		return
	var v := int(d["pressed_by"])
	d.erase("pressed_by")
	d["press_hero"] = v == 0 or v >= 2
	d["press_enemies"] = v >= 1
	d["press_strokes"] = v >= 2
	d["press_bodies"] = v >= 2
