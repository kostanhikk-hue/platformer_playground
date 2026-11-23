extends Resource
## Свойства подписи.

const LABELS := {"text": "Текст", "font_size": "Размер шрифта", "show_in_game": "Видна в игре"}
const UNITS := {"font_size": "px"}
const HINTS := {"show_in_game": "Выключено — заметка только для себя, видна в конструкторе."}

@export var text: String = "Заметка"
@export_range(8, 96, 1) var font_size: int = 16
@export var show_in_game: bool = false
@export var color: Color = Color(1, 1, 1, 0.8)
