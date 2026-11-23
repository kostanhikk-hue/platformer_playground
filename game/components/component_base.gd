extends Node2D
## Основа всех интерактивных объектов уровня (фаза 2). Наследник получает:
##   uid, ссылку на уровень (runtime), свои свойства (props) и формы (shapes по ролям);
##   emit_event(имя, данные) → шина Events;
##   активацию: set_active(on) / is_active() / toggle_active(); свойство экземпляра start_active;
##   связи: targets + link_mode (Включить / Выключить / Переключить / Следовать) — links_pulse(), links_state(on);
##   снимки: snapshot() / restore(data) — откат при смерти к последнему чекпоинту (reset_on_death);
##   «Освещаемое» — галочка в инспекторе у любого компонента (свойства lit_*), события lit / unlit;
##   debug_text() — текст для HUD и подписи при включённых хитбоксах.
##
## Наследник переопределяет по необходимости:
##   _apply()                     — применить props (вызывается при создании и при правке в режиме игры);
##   _on_active(on)               — что значит «активен» для этого объекта;
##   _snap() / _restore(d)        — своё состояние для снимка;
##   _debug() -> String           — своя строка отладки;
##   interact_point(), can_interact(), on_interact_pressed/held/released — для объектов с «Взаимодействием»
##                                  (объект должен быть в группе "interactive").
## Свойства экземпляра, которые понимает база (если они есть в props_script объекта):
##   start_active: bool, reset_on_death: bool, targets: PackedStringArray, link_mode: int.

enum Link { ENABLE, DISABLE, TOGGLE, FOLLOW }
const LINK_TITLES := ["Включить", "Выключить", "Переключить", "Следовать"]  # loc: dev — инспектор конструктора
const LitProps := preload("res://game/components/lit_props.gd")
const LightQuery := preload("res://game/components/light_query.gd")
const Layers := preload("res://core/layers.gd")
const WORLD_LAYER := Layers.WORLD
const ENEMY_LAYER := Layers.ENEMY
const PLAYER_LAYER := Layers.PLAYER
const STROKES_LAYER := Layers.STROKES

var uid := ""
var runtime: Node = null          ## level_runtime (или null, если объект создан вне уровня)
var props: Resource
var placed: PlacedObject
var def: ObjectDef
var shapes: Dictionary = {}       ## роль → [{points: PackedVector2Array (локально), closed: bool}]
var active := true
var lit: Resource                 ## свойства «Освещаемое» (LitProps)
var is_lit := false
## Подсвечен менеджером взаимодействия (герой рядом, можно нажать E).
var highlighted := false
var _lit_t := 0.0
var _lit_pending := false
var _lit_check_t := 0.0
var _ready_done := false


## Вызывается level_builder до добавления в сцену. ctx: uid, runtime, placed, def, shapes, …
func setup_object(p: Resource, ctx: Dictionary) -> void:
	props = p
	uid = ctx.get("uid", name)
	runtime = ctx.get("runtime", null)
	placed = ctx.get("placed", null)
	def = ctx.get("def", null)
	shapes = ctx.get("shapes", {})
	lit = LitProps.new()
	if def != null:
		_load_lit(def.default_props)
	if placed != null:
		_load_lit(placed.props)
	active = bool(_prop("start_active", true))
	_setup(ctx)


func _load_lit(d: Dictionary) -> void:
	for k in d:
		if (k as String).begins_with("lit_") and k in lit:
			var v = d[k]
			if lit.get(k) is PackedStringArray and v is Array:
				v = PackedStringArray(v)
			lit.set(k, v)


func _ready() -> void:
	add_to_group("component")
	_apply()
	_on_active(active)
	_ready_done = true


## Применить новые свойства экземпляра (конструктор во время «Играть отсюда»).
func apply_props(p: Resource, placed_now: PlacedObject = null) -> void:
	props = p
	if placed_now != null:
		placed = placed_now
		lit = LitProps.new()
		if def != null:
			_load_lit(def.default_props)
		_load_lit(placed.props)
	_apply()
	_on_active(active)
	queue_redraw()


func _prop(pname: String, fallback: Variant = null) -> Variant:
	if props != null and pname in props:
		return props.get(pname)
	return fallback


# ------------------------------------------------------------ события

func emit_event(event_name: String, data: Dictionary = {}) -> void:
	Events.emit_event(uid, event_name, data)


# ------------------------------------------------------------ активация

func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_on_active(on)
	_active_event(on)
	queue_redraw()


## Событие при смене активности. По умолчанию activated / deactivated; двери переопределяют (opened / closed).
func _active_event(on: bool) -> void:
	emit_event("activated" if on else "deactivated")


func is_active() -> bool:
	return active


func toggle_active() -> void:
	set_active(not active)


# ------------------------------------------------------------ связи

func _targets() -> PackedStringArray:
	var t = _prop("targets", PackedStringArray())
	if t is Array:
		return PackedStringArray(t)
	return t if t is PackedStringArray else PackedStringArray()


## Источник «сработал» (рычаг дёрнули, контур дорисован, блок разрушен…): режимы Включить / Выключить / Переключить.
func links_pulse() -> void:
	_links_pulse(_targets(), int(_prop("link_mode", Link.ENABLE)))


## Состояние источника (плита нажата, свет есть): режим «Следовать».
func links_state(on: bool) -> void:
	_links_state(_targets(), int(_prop("link_mode", Link.ENABLE)), on)


func _links_pulse(targets: PackedStringArray, mode: int) -> void:
	for t in targets:
		var n = _find(t)
		if n == null:
			continue
		match mode:
			Link.ENABLE:
				n.set_active(true)
			Link.DISABLE:
				n.set_active(false)
			Link.TOGGLE:
				n.set_active(not n.is_active())


func _links_state(targets: PackedStringArray, mode: int, on: bool) -> void:
	if mode != Link.FOLLOW:
		return
	for t in targets:
		var n = _find(t)
		if n != null:
			n.set_active(on)


func _find(target_uid: String):
	if target_uid == uid:
		return self
	if runtime != null and runtime.has_method("get_component"):
		var n = runtime.get_component(target_uid)
		if n != null and n.has_method("set_active"):
			return n
	return null


# ------------------------------------------------------------ снимки

func resets_on_death() -> bool:
	return bool(_prop("reset_on_death", true))


func snapshot() -> Dictionary:
	var d := {"active": active}
	d.merge(_snap(), true)
	return d


func restore(d: Dictionary) -> void:
	var a: bool = d.get("active", active)
	if a != active:
		active = a
		_on_active(a)
	_restore(d)
	queue_redraw()


# ------------------------------------------------------------ «Освещаемое»

func _physics_process(delta: float) -> void:
	if lit == null or not lit.lit_enabled:
		return
	_lit_check_t -= delta
	if _lit_check_t <= 0.0:
		_lit_check_t = 1.0 / maxf(Params.get_res("light").lit_check_hz, 1.0)
		var now := lit_check()
		if now != _lit_pending:
			_lit_pending = now
			_lit_t = 0.0
	if _lit_pending != is_lit:
		_lit_t += delta
		if _lit_t >= lit.lit_delay:
			is_lit = _lit_pending
			emit_event("lit" if is_lit else "unlit")
			var targets: PackedStringArray = lit.lit_targets
			if targets.is_empty():
				# без целей — освещение управляет самим объектом (освещён — активен)
				set_active(is_lit)
			else:
				if is_lit:
					_links_pulse(targets, lit.lit_link_mode)
				_links_state(targets, lit.lit_link_mode, is_lit)


## Освещён ли объект сейчас (точка проверки — центр + смещение, радиус lit_radius).
func lit_check() -> bool:
	return LightQuery.is_lit(self, global_position + Vector2(lit.lit_offset_x, -lit.lit_offset_y), lit.lit_radius)


# ------------------------------------------------------------ отладка

func debug_text() -> String:
	var s := "%s: %s" % [uid, "вкл" if active else "выкл"]
	var extra := _debug()
	if extra != "":
		s += " · " + extra
	if lit != null and lit.lit_enabled:
		s += " · свет: " + ("есть" if is_lit else "нет")
	return s


func _draw_debug() -> void:
	if not Fx.debug_hitboxes:
		return
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-40, -_debug_height()), debug_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 0.6, 0.9))


func _debug_height() -> float:
	return 40.0


# ------------------------------------------------------------ переопределяется

func _setup(_ctx: Dictionary) -> void:
	pass

func _apply() -> void:
	pass

func _on_active(_on: bool) -> void:
	pass

func _snap() -> Dictionary:
	return {}

func _restore(_d: Dictionary) -> void:
	pass

func _debug() -> String:
	return ""


## Взаимодействие (для объектов в группе "interactive"). Расстояние считает game/components/interaction.gd.
func interact_point(_from: Vector2) -> Vector2:
	return global_position

func can_interact(_player: Node) -> bool:
	return active

## false — значок серый (например, кончилась охра).
func interact_ready(_player: Node) -> bool:
	return true

func on_interact_pressed(_player: Node) -> void:
	pass

func on_interact_held(_player: Node, _delta: float) -> void:
	pass

func on_interact_released(_player: Node) -> void:
	pass
