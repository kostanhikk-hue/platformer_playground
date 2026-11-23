extends RefCounted
## Движение по пути (мировые точки): туда-обратно / по кругу / один раз, пауза в точках, плавный разгон.
## Общий код движущейся платформы и ожившей картины.
##   var f := PathFollow.new(); f.setup(points, closed, mode)
##   var ev := f.step(delta, speed, pause, ease)  → [["point", i], ["end"]]; f.pos() — текущая точка.

enum Mode { PINGPONG, LOOP, ONCE }

var pts := PackedVector2Array()
var closed := false
var mode := Mode.PINGPONG
var i := 0          ## откуда едем
var dirn := 1       ## +1 / −1 по индексам
var u := 0.0        ## доля текущего отрезка
var wait := 0.0
var finished := false


func setup(points: PackedVector2Array, is_closed: bool, m: int) -> void:
	pts = points
	closed = is_closed and points.size() >= 3
	mode = m
	if closed and mode == Mode.PINGPONG:
		mode = Mode.LOOP   # у замкнутого пути концов нет — едем по кругу
	i = 0
	dirn = 1
	u = 0.0
	wait = 0.0
	finished = pts.size() < 2


func _next_index() -> int:
	var n := pts.size()
	var j := i + dirn
	if closed:
		return (j + n) % n
	return clampi(j, 0, n - 1)


func pos(ease_amt: float = 0.0) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	if finished or pts.size() < 2:
		return pts[clampi(i, 0, pts.size() - 1)]
	var a := pts[i]
	var b := pts[_next_index()]
	var e := lerpf(u, smoothstep(0.0, 1.0, u), clampf(ease_amt, 0.0, 1.0))
	return a.lerp(b, e)


## Развернуться на месте: дальше ехать по пути в обратную сторону (положение не меняется).
func reverse() -> void:
	if finished or pts.size() < 2:
		return
	i = _next_index()
	dirn = -dirn
	u = 1.0 - u   # плавность (smoothstep) симметрична — точка та же


func step(delta: float, speed: float, pause: float, ease_amt: float) -> Array:
	var out: Array = []
	if finished or pts.size() < 2:
		return out
	if wait > 0.0:
		wait -= delta
		return out
	var guard := 0
	var left := delta
	while left > 0.0 and guard < 8 and not finished:
		guard += 1
		var a := pts[i]
		var b := pts[_next_index()]
		var l := a.distance_to(b)
		var tt := l / maxf(speed, 0.01)
		if tt <= 0.0001:
			u = 1.0
		else:
			var du := left / tt
			if u + du < 1.0:
				u += du
				left = 0.0
				break
			left -= (1.0 - u) * tt
			u = 1.0
		# доехали до точки
		i = _next_index()
		u = 0.0
		out.append(["point", i])
		var n := pts.size()
		var at_end := not closed and (i == n - 1 and dirn > 0 or i == 0 and dirn < 0)
		if closed and i == 0:
			out.append(["end"])
		if at_end:
			out.append(["end"])
			if mode == Mode.ONCE:
				finished = true
				break
			dirn = -dirn
		if pause > 0.0:
			wait = pause
			break
	return out
