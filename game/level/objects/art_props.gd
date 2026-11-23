extends Resource
## Свойства арт-объекта: картинка и оттенок. Масштаб, поворот и отражение — у самого объекта на уровне.

const LABELS := {"image": "Картинка", "modulate": "Оттенок"}
const HINTS := {"image": "Путь к картинке в res://art/…"}

@export var image: String = ""
@export var modulate: Color = Color.WHITE
