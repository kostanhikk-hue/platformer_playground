extends RefCounted
## Вид объектов фазы 2 на холсте конструктора (по ObjectDef.kind). Формы объектов (контуры с ролью)
## рисует editor_canvas — здесь только сам объект: значок, подпись, размеры. Вернуть false — нарисует холст (v1).

const ArtLoader := preload("res://game/level/art_loader.gd")
const CardsDB := preload("res://game/components/cards_db.gd")

const RESULT_TITLES := ["декор", "тело", "платформа", "стена"]
const METHOD_TITLES := ["штрихом", "удержанием E", "штрих + E"]


static func draw(c: Node2D, ed, o: PlacedObject, def: ObjectDef, alpha: float) -> bool:
	var col := Color(def.editor_color, def.editor_color.a * alpha)
	var p := o.position
	var sz: Vector2 = ed.object_local_size(o)
	var r := Rect2(p - sz * 0.5, sz)
	var tag := func(s: String, at: Vector2, size: int = 11) -> void:
		c.text(at, s, col, size)
	match def.kind:
		"paintable":
			var art := String(ed.prop(o, "result_art", ""))
			if art != "" and ArtLoader.exists(art):
				var tex := ArtLoader.load_texture(art)
				if tex != null:
					var s: float = ed.prop(o, "art_scale", 1.0)
					var tsz := tex.get_size() * s
					var at := p + Vector2(ed.prop(o, "art_x", 0.0), ed.prop(o, "art_y", 0.0))
					c.draw_texture_rect(tex, Rect2(at - tsz * 0.5, tsz), false, Color(1, 1, 1, 0.35 * alpha))
			var res := int(ed.prop(o, "result", 1))
			var meth := int(ed.prop(o, "method", 0))
			var br: Rect2 = ed.object_rect(o)
			var extra := ""
			if not bool(ed.prop(o, "start_active", true)):
				extra = " · скрыт до связи"
			if float(ed.prop(o, "lifetime", 0.0)) > 0.0:
				extra += " · живёт %s с" % str(ed.prop(o, "lifetime", 0.0))
			tag.call("✎ %s → %s (%s)%s" % [o.uid, RESULT_TITLES[clampi(res, 0, 3)], METHOD_TITLES[clampi(meth, 0, 2)], extra], br.position + Vector2(0, -c.w(4)))
			_cross(c, p, col)
		"coverage":
			var br: Rect2 = ed.object_rect(o)
			tag.call("▒ закраска %s · пороги %s" % [o.uid, str(ed.prop(o, "thresholds", ""))], br.position + Vector2(0, -c.w(4)))
			_cross(c, p, col)
		"lever":
			c.draw_rect(Rect2(p + Vector2(-16, 4), Vector2(32, 12)), Color(0.35, 0.3, 0.27, alpha))
			var on := bool(ed.prop(o, "start_active", false))
			var tip := p + Vector2(0, 6) + Vector2.UP.rotated(deg_to_rad(35.0 if on else -35.0)) * 30.0
			c.draw_line(p + Vector2(0, 6), tip, Color(0.75, 0.6, 0.4, alpha), c.w(3))
			c.draw_circle(tip, 6.0, col)
			tag.call("рычаг" + (" (однократный)" if int(ed.prop(o, "mode", 0)) == 1 else ""), p + Vector2(-20, -30))
		"plate":
			var w: float = ed.prop(o, "width", 48.0)
			c.draw_rect(Rect2(p + Vector2(-w * 0.5, -6), Vector2(w, 6)), col)
			c.draw_rect(Rect2(p + Vector2(-w * 0.5 - 4, 0), Vector2(w + 8, 6)), Color(0.3, 0.3, 0.33, alpha))
			var who := PackedStringArray()
			for k in [["press_hero", "герой", true], ["press_enemies", "враги", false], ["press_strokes", "штрихи", false], ["press_bodies", "тела", false]]:
				if bool(ed.prop(o, k[0], k[2])):
					who.append(k[1])
			tag.call("плита: " + (", ".join(who) if not who.is_empty() else "ничто"), p + Vector2(-w * 0.5, -12))
		"door":
			var open := bool(ed.prop(o, "start_active", false))
			var dc: Color = ed.prop(o, "color", col)
			c.draw_rect(r, Color(dc, (0.3 if open else 0.85) * alpha))
			c.draw_rect(r, Color(0, 0, 0, 0.6 * alpha), false, c.w(1.5))
			tag.call("дверь" + (" (открыта)" if open else ""), r.position + Vector2(0, -c.w(4)))
		"exit":
			var locked := bool(ed.prop(o, "locked", false))
			c.draw_rect(r, Color(col, 0.15 * alpha))
			c.draw_rect(r, col if not locked else Color(0.6, 0.6, 0.65, alpha), false, c.w(2))
			tag.call("ВЫХОД" + (" 🔒 заперт" if locked else ""), r.position + Vector2(c.w(4), c.w(14)), 12)
		"checkpoint":
			var how := int(ed.prop(o, "activation", 0))
			if int(ed.prop(o, "look", 0)) == 1:
				c.draw_circle(p + Vector2(0, 2), 13.0, Color(0.82, 0.46, 0.14, 0.8 * alpha))
				for k in range(5):
					var a := deg_to_rad(-150.0 + k * 30.0) if k < 4 else deg_to_rad(-10.0)
					c.draw_line(p, p + Vector2(0, -2) + Vector2.from_angle(a) * 18.0, Color(0.82, 0.46, 0.14, 0.8 * alpha), 6.0)
			else:
				var foot := Vector2(p.x, r.end.y)
				c.draw_line(foot, foot - Vector2(0, sz.y * 0.8), Color(0.85, 0.85, 0.85, alpha), c.w(2))
				var top := foot - Vector2(0, sz.y * 0.8)
				c.draw_colored_polygon(PackedVector2Array([top, top + Vector2(26, 9), top + Vector2(0, 18)]), col)
			c.draw_rect(r, Color(col, 0.4 * alpha), false, c.w(1))
			tag.call("чекпоинт · " + ["касанием", "E", "по связи"][clampi(how, 0, 2)], r.position + Vector2(0, -c.w(4)))
		"ink_source":
			c.draw_circle(p, 14.0, col)
			tag.call("охра " + ("полностью" if float(ed.prop(o, "amount", 50.0)) < 0.0 else str(int(ed.prop(o, "amount", 50.0)))), p + Vector2(-20, -22))
		"card":
			c.draw_rect(Rect2(p - Vector2(11, 15), Vector2(22, 30)), Color(0.96, 0.9, 0.75, alpha))
			c.draw_rect(Rect2(p - Vector2(11, 15), Vector2(22, 30)), Color(0.6, 0.4, 0.2, alpha), false, c.w(1.5))
			var id := String(ed.prop(o, "card_id", ""))
			var card := CardsDB.get_card(id)
			tag.call("карточка: " + (card.get("title", id) if id != "" else "— не выбрана"), p + Vector2(-20, -22))
		"crumble":
			tag.call("ломкая · %s с" % str(ed.prop(o, "delay", 0.6)), ed.object_rect(o).position + Vector2(0, -c.w(4)))
			_cross(c, p, col)
		"breakable":
			tag.call("блок · прочность %d" % int(ed.prop(o, "hits", 3)), ed.object_rect(o).position + Vector2(0, -c.w(4)))
			_cross(c, p, col)
		"moving_platform":
			var path := String(ed.prop(o, "path_uid", ""))
			tag.call("платформа → " + (path if path != "" else "нет пути!"), ed.object_rect(o).position + Vector2(0, -c.w(4)))
			_cross(c, p, col)
		"light":
			var look := int(ed.prop(o, "look", 0))
			var rad: float = ed.prop(o, "radius", 200.0)
			var lc: Color = ed.prop(o, "color", col)
			c.draw_circle(p, rad, Color(lc, 0.05 * alpha))
			c.draw_arc(p, rad, 0, TAU, 64, Color(lc, 0.35 * alpha), c.w(1))
			if look != 2:
				c.draw_line(p + Vector2(0, 14), p + Vector2(0, -2), Color(0.42, 0.3, 0.2, alpha), 4.0)
			c.draw_circle(p + Vector2(0, -8), 7.0, Color(1.0, 0.6, 0.2, alpha))
			tag.call(("факел (переносимый)" if bool(ed.prop(o, "carryable", false)) else "факел") + ("" if bool(ed.prop(o, "start_active", true)) else " · погашен"), p + Vector2(-24, -24))
		"living_painting":
			var img := String(ed.prop(o, "image", ""))
			if img != "" and ArtLoader.exists(img):
				var tex := ArtLoader.load_texture(img)
				if tex != null:
					var tsz: Vector2 = tex.get_size() * float(ed.prop(o, "image_scale", 1.0))
					c.draw_texture_rect(tex, Rect2(p - tsz * 0.5, tsz), false, Color(1, 1, 1, alpha))
			var cond: String = ["в свете", "по связи", "когда дорисован контур"][clampi(int(ed.prop(o, "condition", 0)), 0, 2)]
			var beh: String = ["едет по пути", "манекен"][clampi(int(ed.prop(o, "awake", 0)), 0, 1)]
			tag.call("картина: оживает %s, %s" % [cond, beh], ed.object_rect(o).position + Vector2(0, -c.w(4)))
		"anim_decor":
			var fr := decor_frame(ed, o)
			if not fr.is_empty():
				var fsz: Vector2 = fr["size"]
				c.draw_texture_rect_region(fr["tex"], Rect2(p - fsz * 0.5, fsz), fr["region"], Color(1, 1, 1, alpha))
			else:
				c.draw_rect(r, Color(col, 0.3 * alpha), false, c.w(1.5))
				tag.call("декор: нет картинки", r.position + Vector2(0, -c.w(4)))
		"zone":
			var br: Rect2 = ed.object_rect(o)
			var note := String(ed.prop(o, "note", "")).replace("\n", " ")
			c.text(br.position + Vector2(c.w(4), c.w(14)), "▭ " + o.uid, col, 13)
			if note != "":
				c.text(br.position + Vector2(c.w(4), c.w(28)), note.left(48) + ("…" if note.length() > 48 else ""), Color(col, 0.7), 10)
		"marker":
			var k: float = c.w(8)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, 0), p + Vector2(0, k), p + Vector2(-k, 0)]), Color(col, 0.85))
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -k), p + Vector2(k, 0), p + Vector2(0, k), p + Vector2(-k, 0), p + Vector2(0, -k)]), Color(0, 0, 0, 0.6), c.w(1))
			c.text(p + Vector2(k + c.w(3), -c.w(3)), "◆ " + o.uid, col, 12)
			var mnote := String(ed.prop(o, "note", "")).replace("\n", " ")
			if mnote != "":
				c.text(p + Vector2(k + c.w(3), c.w(11)), mnote.left(40) + ("…" if mnote.length() > 40 else ""), Color(col, 0.7), 10)
		"atmosphere":
			c.dashed(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), Color(col, 0.6), c.w(1.5))
			tag.call("атмосфера: " + ["пыль", "искры", "песок", "лепестки"][clampi(int(ed.prop(o, "preset", 0)), 0, 3)], r.position + Vector2(c.w(4), c.w(14)))
		_:
			if o.def_id == "dummy_canvas":
				c.draw_rect(r, Color(col, 0.7 * alpha))
				var y := r.position.y + 6.0
				while y < r.end.y:
					c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.25 * alpha), 1.0)
					y += 8.0
				c.draw_rect(r, Color(0, 0, 0, 0.6 * alpha), false, c.w(1.5))
				tag.call("манекен-холст", r.position + Vector2(0, -c.w(4)))
				return true
			return false
	return true


static func _cross(c: Node2D, p: Vector2, col: Color) -> void:
	var k: float = c.w(5)
	c.draw_line(p - Vector2(k, 0), p + Vector2(k, 0), Color(col, 0.8), c.w(1))
	c.draw_line(p - Vector2(0, k), p + Vector2(0, k), Color(col, 0.8), c.w(1))


## Первый кадр анимированного декора: {tex, region, size} или {}.
static func decor_frame(ed, o: PlacedObject) -> Dictionary:
	var img := String(ed.prop(o, "image", ""))
	if img == "" or not ArtLoader.exists(img):
		return {}
	var tex := ArtLoader.load_texture(img)
	if tex == null:
		return {}
	var cols := maxi(int(ed.prop(o, "columns", 4)), 1)
	var rows := maxi(int(ed.prop(o, "rows", 1)), 1)
	var fw: float = ed.prop(o, "frame_w", 0.0)
	var fh: float = ed.prop(o, "frame_h", 0.0)
	if fw <= 0.0:
		fw = tex.get_size().x / cols
	if fh <= 0.0:
		fh = tex.get_size().y / rows
	return {"tex": tex, "region": Rect2(0, 0, fw, fh), "size": Vector2(fw, fh) * float(ed.prop(o, "scale", 1.0))}


static func decor_frame_size(ed, o: PlacedObject) -> Vector2:
	var fr := decor_frame(ed, o)
	return fr["size"] if not fr.is_empty() else Vector2.ZERO
