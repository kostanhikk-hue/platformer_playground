extends Resource
## «Взаимодействие» (клавиша E / правый бампер). Файл: data/interact_default.tres  ·  Вкладка «Взаимодействие»
## Код: game/components/interaction.gd

const LABELS := {
	"interact_radius": "Радиус взаимодействия",
	"icon_offset_y": "Значок: высота над объектом",
	"icon_size": "Значок: размер",
	"icon_color": "Значок: цвет",
	"icon_off_color": "Значок: цвет, если нельзя (нет охры)",
	"highlight_color": "Подсветка объекта",
	"key_text": "Значок: подпись клавиши",
}
const UNITS := {"interact_radius": "px", "icon_offset_y": "px", "icon_size": "px"}
const HINTS := {
	"interact_radius": "Ближайший интерактивный объект в этом радиусе от центра героя подсвечивается и реагирует на «Взаимодействие».",
	"key_text": "Пусто — текущая клавиша действия «Взаимодействие» (клавиатура или геймпад, по последнему устройству). Свой текст — показывается как есть.",
}

@export_group("Взаимодействие")
@export_range(16.0, 300.0, 2.0, "or_greater") var interact_radius: float = 64.0

@export_group("Значок")
@export_range(0.0, 200.0, 2.0) var icon_offset_y: float = 46.0
@export_range(8.0, 64.0, 1.0) var icon_size: float = 22.0
@export var icon_color: Color = Color(1.0, 0.9, 0.55)
@export var icon_off_color: Color = Color(0.55, 0.55, 0.55)
@export var highlight_color: Color = Color(1.0, 0.95, 0.7, 0.8)
@export var key_text: String = ""
