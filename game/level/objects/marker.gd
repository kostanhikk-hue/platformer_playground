extends Node2D
## Метка: точка для сценария уровня (marker(id) → её положение). В игре невидима
## (при включённых хитбоксах — крестик с id).

var uid := ""


func setup_object(_props: Resource, ctx: Dictionary) -> void:
	uid = ctx.get("uid", name)


func _process(_delta: float) -> void:
	if Fx.debug_hitboxes:
		queue_redraw()


func _draw() -> void:
	if not Fx.debug_hitboxes:
		return
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color(0.6, 0.9, 1.0, 0.8), 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color(0.6, 0.9, 1.0, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(6, -6), uid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.9, 1.0, 0.8))
