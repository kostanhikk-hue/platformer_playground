extends Resource
## Камера героя. Файл: data/camera_default.tres  ·  Вкладка «Камера»
## Камера — дочерний узел героя (game/player/player.gd), тряску вызывает Fx.shake().

const LABELS := {
	"offset_x": "Смещение вперёд",
	"offset_y": "Смещение вверх",
	"follow_facing": "Смещение вперёд зеркалится по взгляду",
	"look_speed": "Скорость перевода взгляда",
	"zoom": "Масштаб",
	"smoothing": "Плавное следование",
	"smoothing_speed": "Скорость следования",
	"limit_bottom": "Нижняя граница камеры",
	"shake_mult": "Сила всех трясок (×)",
}
const UNITS := {"offset_x": "px", "offset_y": "px", "limit_bottom": "px", "zoom": "×", "look_speed": "/с"}
const HINTS := {
	"follow_facing": "Выключено — камера всегда смотрит вправо на «Смещение вперёд». Включено — смещение разворачивается вместе с героем.",
	"look_speed": "Как быстро камера перекатывается на другую сторону при развороте (только если смещение зеркалится).",
	"shake_mult": "Общий множитель всех трясок: 0 — выключить тряску совсем.",
}

@export_group("Положение")
@export_range(-400.0, 400.0, 5.0) var offset_x: float = 120.0
@export_range(-300.0, 300.0, 5.0) var offset_y: float = 70.0
@export var follow_facing: bool = false
@export_range(0.5, 20.0, 0.5) var look_speed: float = 4.0
@export_range(0.25, 3.0, 0.05) var zoom: float = 1.0

@export_group("Следование")
@export var smoothing: bool = true
@export_range(1.0, 30.0, 0.5) var smoothing_speed: float = 8.0
@export_range(0.0, 3000.0, 10.0, "or_greater") var limit_bottom: float = 760.0

@export_group("Тряска")
@export_range(0.0, 3.0, 0.05) var shake_mult: float = 1.0
