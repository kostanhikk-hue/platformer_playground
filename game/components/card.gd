extends "res://game/components/component_base.gd"
## Карточка-научпоп: подбор касанием → уведомление в углу на card_notify_time с (вкладка «Объекты»).
## Повторный подбор той же карточки за сессию (на другом уровне) уведомление не показывает. Событие collected {card_id}.

const CardsDB := preload("res://game/components/cards_db.gd")

var _area: Area2D
var _taken := false
var _t := 0.0


func _setup(_ctx: Dictionary) -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = PLAYER_LAYER
	_area.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 36)
	cs.shape = r
	_area.add_child(cs)
	add_child(_area)


func resets_on_death() -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	_t += delta
	if _taken:
		return
	for b in _area.get_overlapping_bodies():
		if b.is_in_group("player") and not b.dead:
			_take()
			break
	queue_redraw()


func _take() -> void:
	_taken = true
	visible = false
	var id: String = props.card_id
	var first := not CardsDB.collected.has(id)
	CardsDB.collected[id] = true
	if first and runtime != null and runtime.has_method("show_card"):
		var c := CardsDB.get_card(id)
		if c.is_empty():
			c = {"id": id}   # нет в таблице — уведомление с названием ui.card.untitled
		runtime.show_card(c)
	emit_event("collected", {"card_id": id})
	links_pulse()
	links_state(true)


func _draw() -> void:
	var bob := sin(_t * 2.5) * 3.0
	var r := Rect2(-11, -15 + bob, 22, 30)
	draw_rect(r.grow(3), Color(1, 0.85, 0.4, 0.25))
	draw_rect(r, Color(0.96, 0.9, 0.75))
	draw_rect(r, Color(0.6, 0.4, 0.2), false, 2.0)
	draw_line(r.position + Vector2(4, 8), r.position + Vector2(18, 8), Color(0.6, 0.4, 0.2), 1.5)
	draw_line(r.position + Vector2(4, 14), r.position + Vector2(14, 14), Color(0.6, 0.4, 0.2), 1.5)
	_draw_debug()
