extends "res://game/components/component_base.gd"
## Разрушаемый блок: твёрдый (слой «Мир») и цель атак (слой «Враги»), интерфейс цели — take_hit / contact_damage_amount.
## После hits попаданий разрушается (событие destroyed, срабатывают связи), через restore_time — снова (0 — нет).

const GeometryBuilder := preload("res://game/level/geometry_builder.gd")

var _body: StaticBody2D
var _form := PackedVector2Array()
var _hp := 3
var _broken := false
var _t := 0.0
var _flash := 0.0
var _debris: Array = []


func _setup(_ctx: Dictionary) -> void:
	var list: Array = shapes.get("form", [])
	if not list.is_empty() and list[0]["closed"]:
		_form = list[0]["points"]
	else:
		_form = PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])
	_body = StaticBody2D.new()
	_body.collision_layer = WORLD_LAYER | ENEMY_LAYER
	_body.collision_mask = 0
	_body.set_script(preload("res://game/components/breakable_body.gd"))
	_body.set("owner_component", self)
	GeometryBuilder.fill_polygon(_body, _form)
	add_child(_body)


func _apply() -> void:
	if not _broken:
		_hp = maxi(props.hits, 1)


func take_hit(info: Dictionary) -> bool:
	if _broken:
		return false
	var kind: String = info.get("kind", "")
	var ok: bool = (kind == "melee" and props.by_melee) or (kind == "ink" and props.by_ink) or (kind == "wave" and props.by_wave)
	if not ok:
		return false
	_hp -= 1
	_flash = Params.get_res("objects").block_flash
	if _hp <= 0:
		_break()
	queue_redraw()
	return true


func _break() -> void:
	_broken = true
	_t = props.restore_time
	_set_solid(false)
	_debris.clear()
	var c := Vector2.ZERO
	for q in _form:
		c += q
	c /= maxf(_form.size(), 1)
	for k in range(10):
		_debris.append({"p": c + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "v": Vector2(randf_range(-160, 160), randf_range(-320, -80)), "s": randf_range(4, 10)})
	Fx.shake(Params.get_res("objects").block_shake, 0.15)
	emit_event("destroyed")
	links_pulse()
	links_state(true)


func _set_solid(on: bool) -> void:
	_body.collision_layer = (WORLD_LAYER | ENEMY_LAYER) if on else 0


func _physics_process(delta: float) -> void:
	super(delta)
	_flash = maxf(_flash - delta, 0.0)
	for d in _debris:
		d["v"].y += 1400.0 * delta
		d["p"] += d["v"] * delta
	if _broken and props.restore_time > 0.0:
		_t -= delta
		if _t <= 0.0:
			_broken = false
			_hp = maxi(props.hits, 1)
			_set_solid(true)
			links_state(false)
	queue_redraw()


func _snap() -> Dictionary:
	return {"hp": _hp, "broken": _broken, "t": _t}


func _restore(d: Dictionary) -> void:
	_hp = d.get("hp", props.hits)
	_broken = d.get("broken", false)
	_t = d.get("t", 0.0)
	_debris.clear()
	_set_solid(not _broken)


func _draw() -> void:
	if not _broken:
		var col: Color = props.color
		if _flash > 0.0:
			col = Color.WHITE
		draw_colored_polygon(_form, col)
		var o := _form.duplicate()
		o.append(_form[0])
		draw_polyline(o, Color(0, 0, 0, 0.6), 2.0)
		# трещины по мере повреждения
		var dmg := 1.0 - float(_hp) / maxf(props.hits, 1)
		if dmg > 0.0:
			var r := Rect2(_form[0], Vector2.ZERO)
			for q in _form:
				r = r.expand(q)
			var c := r.get_center()
			for k in range(int(dmg * 6.0) + 1):
				var a := TAU * k / 6.0 + 0.4
				draw_line(c, c + Vector2.from_angle(a) * r.size.length() * 0.3 * dmg, Color(0, 0, 0, 0.5), 1.5)
	for d in _debris:
		draw_rect(Rect2(d["p"], Vector2(d["s"], d["s"])), Color(props.color, 0.8))
	_draw_debug()


func _debug() -> String:
	return "разрушен" if _broken else "прочность %d/%d" % [_hp, props.hits]
