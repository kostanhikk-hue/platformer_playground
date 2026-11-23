extends RefCounted
## Строит живую сцену уровня из LevelData: цвет фона, фоны, коллизию, объекты.
## Один и тот же код для игры (level_runtime) и для «Играть отсюда» в конструкторе.
## Героя создаёт level_runtime (как плейграунд: PlayerScript.new()).
##
##   var info := LevelBuilder.build(level, root, ctx)
##   ctx: {"on_checkpoint": Callable(point), "on_exit": Callable(), "on_kill": Callable(), "kill_y": float, "runtime": Node}
##   info: {"start": Vector2 или null, "objects": {uid: Node}, "shapes": {uid: Node}, "paths": {uid: {points, closed}}}
## Каждый объект получает в setup_object(props, ctx) копию ctx с полями uid, placed, def, shapes (его формы по
## ролям, в координатах объекта: роль → [{points, closed, uid}]), paths (все пути уровня, мировые точки), level.
## Формы объектов (GeoShape.role) и пути (Kind.PATH) коллизией не становятся.

const Catalog := preload("res://game/level/catalog.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const GeometryBuilder := preload("res://game/level/geometry_builder.gd")
const BgParallax := preload("res://game/level/parallax_layer.gd")
const START_ID := "start"


static func build(level: LevelData, root: Node2D, ctx: Dictionary = {}) -> Dictionary:
	var info := {"start": null, "objects": {}, "shapes": {}, "paths": {}}

	# цвет за всеми фонами
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	bg_layer.name = "BgColor"
	var rect := ColorRect.new()
	rect.color = level.bg_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(rect)
	root.add_child(bg_layer)

	# фоны
	for b in level.backgrounds:
		if b.path == "" or not ArtLoader.exists(b.path):
			continue
		var holder := BgParallax.new()
		holder.name = b.uid
		holder.base_position = b.position
		holder.position = b.position
		holder.parallax = b.parallax
		holder.reference = level.bounds.position
		holder.z_index = clampi(LevelData.LAYER_Z[clampi(b.layer, 0, 5)] + b.z, -4000, 4000)
		var img := ArtLoader.make_node(b.path, b.region, false)
		img.scale = b.scale
		img.modulate = b.modulate
		holder.add_child(img)
		root.add_child(holder)

	# пути
	for s in level.shapes:
		if s.kind == GeoShape.Kind.PATH:
			info["paths"][s.uid] = {"points": level.shape_world_points(s), "closed": s.closed}
	ctx = ctx.duplicate()
	ctx["paths"] = info["paths"]
	ctx["level"] = level

	# объекты
	for o in level.objects:
		var def := Catalog.get_def(o.def_id)
		if def == null:
			push_warning("Уровень %s: объект %s — нет «%s» в каталоге" % [level.id, o.uid, o.def_id])
			continue
		if o.def_id == START_ID:
			if info["start"] == null:
				info["start"] = o.position
			continue
		var n := make_object(level, o, def, ctx)
		if n == null:
			continue
		root.add_child(n)
		info["objects"][o.uid] = n

	# коллизия
	var on_kill: Callable = ctx.get("on_kill", Callable())
	for s in level.shapes:
		if s.parent_uid != "" and level.find_object(s.parent_uid) == null:
			continue   # родитель удалён — проверка уровня об этом сообщает
		if s.role != "" or s.kind == GeoShape.Kind.PATH:
			continue   # форма объекта или путь — не коллизия
		var node := GeometryBuilder.build(s, level.shape_world_points(s), on_kill)
		if node != null:
			node.add_to_group("level_geometry")
			root.add_child(node)
			info["shapes"][s.uid] = node
	return info


## Один объект уровня → узел (ещё не в сцене). Используется и при сборке, и при создании объекта по ходу игры
## (результат рисуемого контура «Создать объект»). level может быть null — тогда форм нет.
static func make_object(level: LevelData, o: PlacedObject, def: ObjectDef, ctx: Dictionary) -> Node:
	if def == null or def.scene == null:
		return null
	var n: Node = def.scene.instantiate()
	n.name = o.uid
	if n is Node2D:
		n.position = o.position
		n.z_index = LevelData.LAYER_Z[clampi(o.layer, 0, 5)]
		if def.transformable:
			var sc := o.scale
			if o.flip_h:
				sc.x = -sc.x
			n.rotation_degrees = o.rotation_deg
			n.scale = sc
	if n.has_method("setup_object"):
		var c := ctx.duplicate()
		c["uid"] = o.uid
		c["placed"] = o
		c["def"] = def
		c["shapes"] = object_shapes(level, o, def)
		n.setup_object(Catalog.make_props(def, o), c)
	return n


## Формы объекта по ролям в его координатах: роль → [{points, closed, uid}].
## Если на уровне у объекта форм нет — берутся формы каталога (def.shapes).
static func object_shapes(level: LevelData, o: PlacedObject, def: ObjectDef) -> Dictionary:
	var out := {}
	var list: Array = level.role_shapes(o.uid) if level != null else []
	if list.is_empty() and def != null:
		for s in def.shapes:
			if s.role != "":
				var pts := PackedVector2Array()
				for q in s.points:
					pts.append(q + s.position)
				if not out.has(s.role):
					out[s.role] = []
				out[s.role].append({"points": pts, "closed": s.is_closed(), "uid": ""})
		return out
	for s in list:
		var wp := level.shape_world_points(s)
		var pts := PackedVector2Array()
		for q in wp:
			pts.append(q - o.position)
		if not out.has(s.role):
			out[s.role] = []
		out[s.role].append({"points": pts, "closed": s.is_closed(), "uid": s.uid})
	return out
