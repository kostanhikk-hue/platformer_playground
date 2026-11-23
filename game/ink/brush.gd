extends RefCounted
## Рисовалка «кистью»: превращает ломаную в набор щетинок с шумом. Только визуал.
## build() вызывается один раз при создании штриха (случайность фиксируется),
## draw() — каждый кадр из _draw() штриха.
##   var data := Brush.build(points, thickness, brush_params, rng)
##   Brush.draw(self, data, revealed_length, color)

const BrushParams := preload("res://data/brush_params.gd")


static func build(pts: PackedVector2Array, thickness: float, b: BrushParams, rng: RandomNumberGenerator) -> Dictionary:
	# 1. уплотняем ломаную, считаем длину и нормали
	var dense := PackedVector2Array()
	var cum := PackedFloat32Array()
	var run := 0.0
	dense.append(pts[0])
	cum.append(0.0)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var c := pts[i]
		var seg := a.distance_to(c)
		var steps := clampi(int(ceil(seg / maxf(b.step, 1.0))), 1, 2000)
		for s in range(1, steps + 1):
			dense.append(a.lerp(c, float(s) / steps))
			run += seg / steps
			cum.append(run)
	var total := maxf(run, 1.0)
	var nrm := PackedVector2Array()
	nrm.resize(dense.size())
	for i in range(dense.size()):
		var t := (dense[mini(i + 1, dense.size() - 1)] - dense[maxi(i - 1, 0)]).normalized()
		nrm[i] = Vector2(-t.y, t.x)

	# 2. щетинки
	var strands: Array = []
	if b.underlay:
		strands.append(_strand(dense, cum, nrm, total, 0.0, thickness * b.underlay_width, b.wobble * b.underlay_wobble, b, rng, true))
	var n := clampi(b.strands, 0, 64)   # защита: больше 64 щетинок — заметные тормоза
	for k in range(n):
		var lateral := 0.0 if n == 1 else lerpf(-0.5, 0.5, (k + 0.5) / n) * thickness * b.spread
		var width := thickness / n * b.strand_width
		strands.append(_strand(dense, cum, nrm, total, lateral, width, b.wobble, b, rng, false))
	return {"cum": cum, "total": total, "strands": strands}


static func _strand(dense: PackedVector2Array, cum: PackedFloat32Array, nrm: PackedVector2Array, total: float,
		lateral: float, width: float, wobble: float, b: BrushParams, rng: RandomNumberGenerator, under: bool) -> Dictionary:
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var ph3 := rng.randf() * TAU
	var ph4 := rng.randf() * TAU
	var pts := PackedVector2Array()
	var ws := PackedFloat32Array()
	pts.resize(dense.size())
	ws.resize(dense.size())
	for i in range(dense.size()):
		var l := cum[i]
		var noise := 0.6 * sin(l * 0.045 * b.wobble_freq + ph1) + 0.4 * sin(l * 0.12 * b.wobble_freq + ph2)
		pts[i] = dense[i] + nrm[i] * (lateral + noise * wobble)
		var wn := 0.6 * sin(l * 0.03 * b.width_freq + ph3) + 0.4 * sin(l * 0.09 * b.width_freq + ph4)
		var taper := 1.0 - b.taper * smoothstep(b.taper_start, 1.0, l / total)
		ws[i] = maxf(width * (1.0 + b.width_var * wn) * taper, b.min_width)
	return {
		"pts": pts,
		"w": ws,
		"bright": 1.0 + (rng.randf() * 2.0 - 1.0) * b.color_var,
		"start": 0.0 if under else total * rng.randf() * b.ragged * b.ragged_start,
		"end": total if under else total * (1.0 - rng.randf() * b.ragged),
		"under": under,
		"dark": b.underlay_dark,
		"alpha": b.opacity,
	}


## reveal — сколько длины штриха уже «нарисовано» (для анимации роста). 1e9 — весь штрих.
static func draw(canvas: CanvasItem, data: Dictionary, reveal: float, col: Color) -> void:
	var cum: PackedFloat32Array = data["cum"]
	for s in data["strands"]:
		var pts: PackedVector2Array = s["pts"]
		var ws: PackedFloat32Array = s["w"]
		var k: float = s["dark"] if s["under"] else s["bright"]
		var c := Color(clampf(col.r * k, 0.0, 1.0), clampf(col.g * k, 0.0, 1.0), clampf(col.b * k, 0.0, 1.0), s["alpha"])
		var s_start: float = s["start"]
		var s_end: float = s["end"]
		for i in range(pts.size() - 1):
			if cum[i + 1] > reveal or cum[i + 1] > s_end:
				break
			if cum[i] < s_start:
				continue
			canvas.draw_line(pts[i], pts[i + 1], c, ws[i])
