extends "res://game/components/component_base.gd"
## Анимированный декор: лист кадров (колонки × строки), частота, петля. Только вид.

const ArtLoader := preload("res://game/level/art_loader.gd")

var _tex: Texture2D
var _path := ""
var _frame := 0
var _t := 0.0


func resets_on_death() -> bool:
	return false


func _apply() -> void:
	if props.image != _path:
		_path = props.image
		_tex = ArtLoader.load_texture(_path) if _path != "" and ArtLoader.exists(_path) else null
	if props.random_start:
		_frame = randi() % maxi(_count(), 1)
	queue_redraw()


func _count() -> int:
	var all := maxi(props.columns, 1) * maxi(props.rows, 1)
	return all if props.frames <= 0 else mini(props.frames, all)


func frame_rect(i: int) -> Rect2:
	if _tex == null:
		return Rect2()
	var cols := maxi(props.columns, 1)
	var rws := maxi(props.rows, 1)
	var sz := _tex.get_size()
	var fw: float = props.frame_w if props.frame_w > 0.0 else sz.x / cols
	var fh: float = props.frame_h if props.frame_h > 0.0 else sz.y / rws
	return Rect2(Vector2(i % cols, i / cols) * Vector2(fw, fh), Vector2(fw, fh))


func _process(delta: float) -> void:
	if _tex == null:
		return
	_t += delta
	var dt := 1.0 / maxf(props.fps, 0.1)
	while _t >= dt:
		_t -= dt
		var n := _count()
		if _frame + 1 >= n:
			_frame = 0 if props.loop else n - 1
		else:
			_frame += 1
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		draw_rect(Rect2(-16, -16, 32, 32), Color(1, 0.4, 0.4, 0.4), false, 1.0)
		return
	var r := frame_rect(_frame)
	var sz: Vector2 = r.size * props.scale
	draw_texture_rect_region(_tex, Rect2(-sz * 0.5, sz), r, props.modulate)
