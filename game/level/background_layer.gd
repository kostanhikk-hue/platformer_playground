class_name BackgroundLayer
extends Resource
## Картинка-фон. position — левый верхний угол (при parallax = 1 картинка стоит в мире как поставлена;
## при другом parallax совпадает с поставленной, когда левый верхний угол кадра — в углу границ уровня).

@export var uid: String = ""
@export var path: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var scale: Vector2 = Vector2.ONE
@export var parallax: Vector2 = Vector2.ONE
## Кадрирование в пикселях картинки. Пустой прямоугольник — вся картинка.
@export var region: Rect2 = Rect2()
@export var modulate: Color = Color.WHITE
@export var z: int = 0
@export var locked: bool = false
## Слой конструктора (0 — дальний фон, 1 — картина-основа, 2 — задний декор, 3 — геймплей, 4 — передний план).
## Добавлено к формату из ТЗ: фону нужен слой, чтобы порядок и замки слоёв работали.
@export var layer: int = 1
