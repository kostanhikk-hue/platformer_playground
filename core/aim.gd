extends RefCounted
## Общий прицел для всего, что рисует кисть (линия, волна, будущие приёмы).
## Ресурс параметров должен содержать поля из блока «Прицел» (см. AIM_FIELDS) —
## их можно скопировать из data/ink_params.gd или data/wave_params.gd.
##
## Угол считается ОТНОСИТЕЛЬНО ГЕРОЯ: 0° = горизонтально вперёд (куда смотрит герой),
## +90° = вверх, −90° = вниз, 180° = назад. При повороте героя всё зеркалится.
##
## Использование:  var aim := Aim.resolve(params, self, facing)
##   aim.side  — сторона (1 вправо, −1 влево)
##   aim.angle — итоговый угол в градусах (относительно героя)
##   aim.dir   — единичный вектор в мире

const AIM_FIELDS := ["aim_mode", "base_angle", "aim_offset", "aim_influence", "max_aim_up", "max_aim_down", "snap_degrees", "min_cursor_dist"]

enum { MODE_FIXED, MODE_SIDE, MODE_FULL }


static func resolve(p: Resource, who: Node2D, facing: int) -> Dictionary:
	var side := facing
	var angle: float = p.base_angle
	if p.aim_mode != MODE_FIXED:
		var to := who.get_global_mouse_position() - who.global_position
		if to.length() >= p.min_cursor_dist:
			if absf(to.x) > 0.5:
				side = 1 if to.x > 0.0 else -1
			if p.aim_mode == MODE_FULL:
				var cursor := rad_to_deg(atan2(-to.y, absf(to.x)))
				angle = lerpf(p.base_angle, cursor + p.aim_offset, p.aim_influence)
				# пределы ограничивают только наведение курсором; базовый угол задаётся как есть
				angle = clampf(angle, -p.max_aim_down, p.max_aim_up)
	if p.snap_degrees > 0.5:
		angle = roundf(angle / p.snap_degrees) * p.snap_degrees
	return {"side": side, "angle": angle, "dir": dir_of(angle, side)}


## Вектор по углу относительно героя и стороне.
static func dir_of(angle_deg: float, side: int) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(cos(a) * side, -sin(a))
