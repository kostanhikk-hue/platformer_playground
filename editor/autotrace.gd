extends RefCounted
## Автообводка арт-объекта по прозрачности. Результат — точки в координатах картинки (пиксели, 0..size);
## конструктор переводит их в координаты объекта (центр картинки = 0,0).

const Geometry := preload("res://core/geometry.gd")


## Силуэт → замкнутые многоугольники (Godot: BitMap.opaque_to_polygons).
static func bodies(img: Image, threshold: float, epsilon: float) -> Array:
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, threshold)
	var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), maxf(epsilon, 0.1))
	var out: Array = []
	for p in polys:
		if p.size() >= 3:
			out.append(p)
	return out


## Верхняя кромка: для каждой колонки — самый верхний непрозрачный пиксель.
## Колонки без пикселей разрывают кромку на куски. Каждый кусок упрощается с допуском epsilon.
static func top_edges(img: Image, threshold: float, epsilon: float, min_run: float) -> Array:
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, threshold)
	var w := img.get_width()
	var h := img.get_height()
	var out: Array = []
	var run := PackedVector2Array()
	for x in range(w):
		var top := -1
		for y in range(h):
			if bm.get_bit(x, y):
				top = y
				break
		if top < 0:
			_flush(out, run, epsilon, min_run)
			run = PackedVector2Array()
		else:
			if run.is_empty():
				run.append(Vector2(x, top))
			run.append(Vector2(x + 1, top))
	_flush(out, run, epsilon, min_run)
	return out


static func _flush(out: Array, run: PackedVector2Array, epsilon: float, min_run: float) -> void:
	if run.size() < 2:
		return
	if run[run.size() - 1].x - run[0].x < min_run:
		return
	var s := Geometry.simplify(run, maxf(epsilon, 0.1), false)
	if s.size() >= 2:
		out.append(s)
