extends Resource
## «Освещаемое» — галочка у любого компонента (раздел инспектора «Освещаемое»). Хранится в PlacedObject.props
## с приставкой lit_. Объект освещён, если в радиусе хотя бы одного горящего источника (с учётом линии видимости).
## Без целей — освещение включает сам объект (освещён — активен: дверь открыта, контур виден…).

const LABELS := {
	"lit_enabled": "Освещаемое",
	"lit_radius": "Область проверки: радиус",
	"lit_offset_x": "Точка проверки: вправо от центра",
	"lit_offset_y": "Точка проверки: вверх от центра",
	"lit_delay": "Задержка срабатывания",
	"lit_targets": "Цели (пусто — сам объект)",
	"lit_link_mode": "Что делать с целями",
}
const UNITS := {"lit_radius": "px", "lit_delay": "с", "lit_offset_x": "px", "lit_offset_y": "px"}
const HINTS := {
	"lit_enabled": "Объект реагирует на свет факела: события lit / unlit, связи.",
	"lit_radius": "0 — точка. Больше — освещён, если свет касается круга этого радиуса.",
	"lit_delay": "Свет должен продержаться столько, чтобы сработало (мерцание факела не дёргает объект).",
	"lit_link_mode": "Обычно «Следовать»: освещён — цель активна, свет ушёл — нет.",
}

@export_group("Освещаемое")
@export var lit_enabled: bool = false
@export_range(0.0, 200.0, 2.0, "or_greater") var lit_radius: float = 16.0
@export_range(-200.0, 200.0, 1.0, "or_greater", "or_less") var lit_offset_x: float = 0.0
@export_range(-200.0, 200.0, 1.0, "or_greater", "or_less") var lit_offset_y: float = 0.0
@export_range(0.0, 2.0, 0.05) var lit_delay: float = 0.2
@export var lit_targets: PackedStringArray = PackedStringArray()
@export_enum("Включить", "Выключить", "Переключить", "Следовать") var lit_link_mode: int = 3
