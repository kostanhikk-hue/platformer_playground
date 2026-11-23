extends Node2D
## Фон с параллаксом. При parallax = 1 стоит в мире как поставлен.
## Иначе сдвигается так, что совпадает с поставленным, когда левый верхний угол кадра — в reference
## (у уровня это левый верхний угол границ), и уходит со скоростью parallax относительно мира.

var base_position := Vector2.ZERO
var parallax := Vector2.ONE
var reference := Vector2.ZERO
var enabled := true


func _process(_delta: float) -> void:
	if not enabled or parallax == Vector2.ONE:
		position = base_position
		return
	var view_tl := get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO
	position = base_position + (view_tl - reference) * (Vector2.ONE - parallax)
