extends RefCounted
## Освещённость точки: есть ли рядом горящий источник света (группа "light_source").
## Источник отвечает сам: light_reaches(точка, радиус_цели) — с учётом своего радиуса механики и линии видимости.

static func is_lit(from: Node, point: Vector2, target_radius: float = 0.0) -> bool:
	if from == null or not from.is_inside_tree():
		return false
	for l in from.get_tree().get_nodes_in_group("light_source"):
		if l.has_method("light_reaches") and l.light_reaches(point, target_radius):
			return true
	return false
