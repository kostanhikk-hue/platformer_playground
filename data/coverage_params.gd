extends Resource
## «Закрашивание» — общие параметры. Файл: data/coverage_default.tres  ·  Вкладка «Закраска»
## Что закрашивать и пороги — у конкретной области в инспекторе конструктора. Код: game/components/coverage.gd

const LABELS := {
	"cell_size": "Размер ячейки",
	"melee_pad": "Удар закрашивает с запасом",
	"use_stroke_color": "Цвет — как у штриха",
	"paint_color": "Цвет закраски (если не как у штриха)",
	"melee_color": "Цвет закраски ударом",
	"paint_alpha": "Непрозрачность закраски",
	"blob_size": "Пятно (× ячейки)",
	"blob_jitter": "Разброс пятен (шум кисти)",
	"show_area": "Показывать границу области",
	"area_alpha": "Граница области: прозрачность",
}
const UNITS := {"cell_size": "px", "melee_pad": "px"}
const HINTS := {
	"cell_size": "Область делится на ячейки этого размера. Процент = закрашенные / все. Меньше — точнее и дороже.",
	"blob_jitter": "Случайный сдвиг и размер пятен — чтобы закраска выглядела как мазки, а не сетка.",
	"show_area": "Тонкий пунктир по краю закрашиваемой области (видно, что её можно закрасить).",
}

@export_group("Сетка")
@export_range(3.0, 32.0, 1.0) var cell_size: float = 8.0
@export_range(0.0, 40.0, 1.0) var melee_pad: float = 4.0

@export_group("Вид")
@export var use_stroke_color: bool = true
@export var paint_color: Color = Color(0.82, 0.46, 0.14)
@export var melee_color: Color = Color(0.95, 0.75, 0.35)
@export_range(0.1, 1.0, 0.05) var paint_alpha: float = 0.85
@export_range(0.5, 3.0, 0.05) var blob_size: float = 1.3
@export_range(0.0, 1.0, 0.05) var blob_jitter: float = 0.4
@export var show_area: bool = true
@export_range(0.0, 1.0, 0.05) var area_alpha: float = 0.35
