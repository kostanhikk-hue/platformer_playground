extends RefCounted
## Проверка уровня. Возвращает список проблем: {"error": bool, "text": String, "uid": String, "pos": Vector2}.
## Уровень с ошибками всё равно сохраняется (чтобы не терять работу), но игра о них предупреждает.

const Geometry := preload("res://core/geometry.gd")
const Catalog := preload("res://game/level/catalog.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")
const Lines := preload("res://game/dialog/lines_db.gd")

static func run(level: LevelData, ep: Resource) -> Array:
	var out: Array = []
	var center := level.bounds.get_center()

	# старт
	var starts := level.objects.filter(func(o): return o.def_id == "start")
	if starts.is_empty():
		out.append(_p(true, "Нет «Старта героя»", "", center))
	elif starts.size() > 1:
		for s in starts:
			out.append(_p(true, "«Старт героя» больше одного (%d)" % starts.size(), s.uid, s.position))

	# повтор uid
	var seen := {}
	for arr in [level.backgrounds, level.shapes, level.objects]:
		for r in arr:
			if seen.has(r.uid):
				out.append(_p(true, "Повтор uid «%s»" % r.uid, r.uid, _pos_of(level, r)))
			seen[r.uid] = true

	# контуры
	for s in level.shapes:
		var wp := level.shape_world_points(s)
		var pos := Geometry.bbox(wp).get_center()
		if s.points.size() < s.min_points():
			out.append(_p(true, "Контур %s: мало точек (%d, нужно %d)" % [s.uid, s.points.size(), s.min_points()], s.uid, pos))
		if s.parent_uid != "" and level.find_object(s.parent_uid) == null:
			out.append(_p(true, "Контур %s привязан к несуществующему объекту «%s»" % [s.uid, s.parent_uid], s.uid, pos))
		if s.kind != GeoShape.Kind.PATH and s.is_closed() and Geometry.self_intersects(wp, true):
			if s.role != "":
				out.append(_p(true, "Форма %s объекта %s самопересекается — тело по ней не построится" % [s.uid, s.parent_uid], s.uid, pos))
			else:
				out.append(_p(true, "Контур %s самопересекается — в игре не будет создан" % s.uid, s.uid, pos))
		if not level.bounds.encloses(Geometry.bbox(wp)):
			out.append(_p(false, "Контур %s выходит за границы уровня" % s.uid, s.uid, pos))

	# объекты
	var has_exit := false
	for o in level.objects:
		var def := Catalog.get_def(o.def_id)
		if def == null:
			out.append(_p(true, "Объект %s: «%s» нет в каталоге" % [o.uid, o.def_id], o.uid, o.position))
			continue
		if o.def_id == "exit":
			has_exit = true
		var img: String = o.props.get("image", def.image)
		if def.transformable and img != "":
			_check_image(out, img, o.uid, o.position)
		if not level.bounds.has_point(o.position):
			out.append(_p(false, "Объект %s за границами уровня" % o.uid, o.uid, o.position))
		_check_links(out, level, o, def)

	# фоны
	for b in level.backgrounds:
		_check_image(out, b.path, b.uid, b.position)

	if not has_exit:
		out.append(_p(false, "Нет «Выхода»", "", center))

	_check_script(out, level)

	# старт над пустотой
	if starts.size() >= 1:
		var st: PlacedObject = starts[0]
		var reach: float = ep.start_void_tiles * LevelData.T if ep != null else 10.0 * LevelData.T
		if not _floor_below(level, st.position, reach):
			out.append(_p(false, "«Старт» висит над пустотой (пола нет ближе %d T)" % int(reach / LevelData.T), st.uid, st.position))
	return out


## Связи и ссылки (фаза 2): цели существуют и умеют включаться, путь — это путь, у компонента есть его форма.
static func _check_links(out: Array, level: LevelData, o: PlacedObject, def: ObjectDef) -> void:
	if def.props_script == null:
		return
	var consts: Dictionary = def.props_script.get_script_constant_map()
	for field in ["targets", "lit_targets"]:
		var t = Catalog.prop_value(def, o, field, PackedStringArray())
		if field == "lit_targets" and not bool(Catalog.prop_value(def, o, "lit_enabled", false)):
			continue
		if not (t is Array or t is PackedStringArray):
			continue
		for u in t:
			var target := level.find_object(String(u))
			if target == null:
				out.append(_p(true, "%s: связь на несуществующий объект «%s»" % [o.uid, u], o.uid, o.position))
				continue
			var td := Catalog.get_def(target.def_id)
			if td == null or not td.has_tag("activatable"):
				out.append(_p(true, "%s: связь на «%s» (%s) — этот объект не умеет включаться" % [o.uid, u, td.title if td != null else target.def_id], o.uid, o.position))
	var picks: Dictionary = consts.get("PICKS", {})
	for pname in picks:
		var v := String(Catalog.prop_value(def, o, pname, ""))
		if v == "":
			continue
		match picks[pname]:
			"path":
				var s := level.find_shape(v)
				if s == null or s.kind != GeoShape.Kind.PATH:
					out.append(_p(true, "%s: путь «%s» не найден" % [o.uid, v], o.uid, o.position))
			"object":
				if level.find_object(v) == null:
					out.append(_p(true, "%s: ссылка на несуществующий объект «%s»" % [o.uid, v], o.uid, o.position))
			"def":
				if Catalog.get_def(v) == null:
					out.append(_p(true, "%s: в каталоге нет «%s»" % [o.uid, v], o.uid, o.position))
			"image":
				if not ArtLoader.exists(v):
					out.append(_p(true, "%s: файл картинки не найден (%s)" % [o.uid, v], o.uid, o.position))
	match def.kind:
		"paintable":
			if level.role_shapes(o.uid, "outline").is_empty() and def.shapes.is_empty():
				out.append(_p(true, "%s: у рисуемого контура нет формы" % o.uid, o.uid, o.position))
		"coverage":
			var a := level.role_shapes(o.uid, "area")
			if not a.is_empty() and not a[0].is_closed():
				out.append(_p(true, "%s: область закраски должна быть замкнутой" % o.uid, o.uid, o.position))
		"moving_platform":
			if String(Catalog.prop_value(def, o, "path_uid", "")) == "":
				out.append(_p(false, "%s: у движущейся платформы не выбран путь" % o.uid, o.uid, o.position))
	if o.def_id == "dummy" and int(Catalog.prop_value(def, o, "behavior", 0)) == 3 and String(Catalog.prop_value(def, o, "path_uid", "")) == "":
		out.append(_p(false, "%s: поведение «По пути», но путь не выбран" % o.uid, o.uid, o.position))


## Сценарий уровня (фаза 4): компилируется ли; id в вызовах zone / marker / obj / activate / camera_show…
## и строки вида "t_…" / "m_…" есть в уровне; реплики и наборы есть в таблице; пресеты существуют.
static func _check_script(out: Array, level: LevelData) -> void:
	var path := LevelData.path_for(level.epoch, level.id).get_basename() + ".gd"
	if not FileAccess.file_exists(path):
		return
	var center := level.bounds.get_center()
	var name := path.get_file()
	var sc = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (sc is Script) or not sc.can_instantiate():
		out.append(_p(true, "Сценарий %s: ошибка в коде — в игре уровень пойдёт без сценария (подробности в выводе Godot)" % name, "", center))
	var src := FileAccess.get_file_as_string(path)
	var code := PackedStringArray()
	for line in src.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("#"):
			continue
		var hash_i := line.find(" #")
		if hash_i >= 0 and line.substr(hash_i).count("\"") == 0:
			line = line.substr(0, hash_i)
		code.append(line)
	var text := "\n".join(code)
	Lines.reload()
	var uids := {}
	var kinds := {}
	for o in level.objects:
		uids[o.uid] = true
		var d := Catalog.get_def(o.def_id)
		kinds[o.uid] = d.kind if d != null else ""
	var seen := {}
	var rx := RegEx.create_from_string("\\b(zone|marker|obj|activate|toggle|camera_show|camera_lock|in_zone|pos_of)\\(\\s*\"([^\"]+)\"")
	for m in rx.search_all(text):
		var fn := m.get_string(1)
		var id := m.get_string(2)
		seen[id] = true
		if not uids.has(id):
			out.append(_p(true, "Сценарий %s: %s(\"%s\") — такого id нет в уровне" % [name, fn, id], "", center))
		elif fn in ["zone", "camera_lock", "in_zone"] and kinds[id] != "zone":
			out.append(_p(true, "Сценарий %s: %s(\"%s\") — это не триггер-зона" % [name, fn, id], id, center))
		elif fn == "marker" and kinds[id] != "marker":
			out.append(_p(false, "Сценарий %s: marker(\"%s\") — это не метка" % [name, id], id, center))
	var rx_id := RegEx.create_from_string("\"((?:t|m)_[A-Za-z0-9_]+)\"")
	for m in rx_id.search_all(text):
		var id := m.get_string(1)
		if not seen.has(id) and not uids.has(id):
			seen[id] = true
			out.append(_p(true, "Сценарий %s: «%s» — такой зоны или метки нет в уровне" % [name, id], "", center))
	var no_voice: Array = []
	var rx_say := RegEx.create_from_string("\\bsay\\(\\s*\"([^\"]+)\"")
	for m in rx_say.search_all(text):
		var id := m.get_string(1)
		if not Lines.has_line(id):
			out.append(_p(true, "Сценарий %s: реплики «%s» нет в content/dialog/lines.csv" % [name, id], "", center))
		elif Lines.voice_path(id) == "" and not no_voice.has(id):
			no_voice.append(id)
	var rx_set := RegEx.create_from_string("\\b(bark|hint)\\(\\s*\"([^\"]+)\"")
	for m in rx_set.search_all(text):
		var s := m.get_string(2)
		if not Lines.has_set(s):
			out.append(_p(true, "Сценарий %s: %s(\"%s\") — такого набора нет в lines.csv (колонка set)" % [name, m.get_string(1), s], "", center))
		else:
			for id in Lines.set_lines(s):
				if Lines.voice_path(id) == "" and not no_voice.has(id):
					no_voice.append(id)
	if not no_voice.is_empty():
		out.append(_p(false, "Без голоса реплик: %d (%s%s) — титры держатся по скорости чтения. Голос: content/vo/<говорящий>/<id>.ogg" % [no_voice.size(), ", ".join(no_voice.slice(0, 3)), "…" if no_voice.size() > 3 else ""], "", center))
	var rx_pre := RegEx.create_from_string("\\bapply_preset\\(\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"")
	for m in rx_pre.search_all(text):
		if _preset_exists(m.get_string(1), m.get_string(2)) == "":
			out.append(_p(true, "Сценарий %s: нет пресета «%s» в наборе %s" % [name, m.get_string(2), m.get_string(1)], "", center))


static func _preset_exists(set_key: String, preset: String) -> String:
	var dir: String = Params.REGISTRY.get(set_key, {}).get("presets", "")
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return ""
	var want := preset.strip_edges().to_lower().replace(" ", "_")
	var rx := RegEx.create_from_string("^\\d+_")
	for f in DirAccess.get_files_at(dir):
		var fname := f.trim_suffix(".remap")
		var base := fname.get_basename().to_lower()
		if fname.ends_with(".tres") and (base == want or rx.sub(base, "") == want):
			return dir.path_join(fname)
	return ""


static func _p(err: bool, text: String, uid: String, pos: Vector2) -> Dictionary:
	return {"error": err, "text": text, "uid": uid, "pos": pos}


static func _check_image(out: Array, path: String, uid: String, pos: Vector2) -> void:
	if path == "" or not ArtLoader.exists(path):
		out.append(_p(true, "%s: файл картинки не найден (%s)" % [uid, path], uid, pos))
	elif not ArtLoader.is_imported(path):
		out.append(_p(false, "%s: картинка не импортирована — откройте проект в Godot перед сборкой (%s)" % [uid, path.get_file()], uid, pos))


static func _pos_of(level: LevelData, r: Resource) -> Vector2:
	if r is GeoShape:
		return Geometry.bbox(level.shape_world_points(r)).get_center()
	return r.position


## Луч вниз от точки: есть ли твёрдый контур ближе reach.
static func _floor_below(level: LevelData, from: Vector2, reach: float) -> bool:
	var to := from + Vector2(0, reach)
	for s in level.shapes:
		if s.kind == GeoShape.Kind.KILL or s.kind == GeoShape.Kind.PATH or s.role != "":
			continue
		var wp := level.shape_world_points(s)
		var n := wp.size()
		var edges := n if s.is_closed() else n - 1
		for i in range(edges):
			if Geometry2D.segment_intersects_segment(from, to, wp[i], wp[(i + 1) % n]) != null:
				return true
		if s.is_closed() and n >= 3 and Geometry2D.is_point_in_polygon(from, wp):
			return true
	return false
