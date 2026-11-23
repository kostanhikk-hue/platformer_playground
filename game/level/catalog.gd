extends RefCounted
## Каталог объектов: все ObjectDef из res://catalog/<эпоха>/*.tres. Загружается один раз (reload() — заново).

const LevelFiles := preload("res://game/level/level_files.gd")
const CATALOG_DIR := "res://catalog"
const PlateProps := preload("res://game/components/plate_props.gd")

static var _defs: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_defs.clear()
	for ep in LevelFiles.subdirs(CATALOG_DIR):
		for p in LevelFiles.resources_in(CATALOG_DIR.path_join(ep)):
			var d = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
			if d is ObjectDef and d.id != "":
				_migrate(d)
				_defs[d.id] = d
	_loaded = true


## Старые значения в записях каталога (как LevelData._migrate для уровней): плита pressed_by → галочки.
static func _migrate(d: ObjectDef) -> void:
	PlateProps.migrate_pressed_by(d.default_props)
	for it in d.kit:
		if it is Dictionary and it.get("props") is Dictionary:
			PlateProps.migrate_pressed_by(it["props"])


static func all() -> Dictionary:
	if not _loaded:
		reload()
	return _defs


static func get_def(def_id: String) -> ObjectDef:
	return all().get(def_id, null)


## Ресурс свойств экземпляра: значения скрипта → значения каталога (default_props) → переопределения
## экземпляра (PlacedObject.props).
static func make_props(def: ObjectDef, placed: PlacedObject) -> Resource:
	if def == null or def.props_script == null:
		return null
	var r: Resource = def.props_script.new()
	for k in def.default_props:
		if k in r:
			r.set(k, _conv(r.get(k), def.default_props[k]))
	if placed != null:
		for k in placed.props:
			if k in r:
				r.set(k, _conv(r.get(k), placed.props[k]))
	return r


## Значение свойства с учётом каталога: экземпляр → каталог → скрипт.
static func prop_value(def: ObjectDef, placed: PlacedObject, pname: String, fallback: Variant = null) -> Variant:
	if placed != null and placed.props.has(pname):
		return placed.props[pname]
	if def != null and def.default_props.has(pname):
		return def.default_props[pname]
	if def != null and def.props_script != null:
		var r: Resource = def.props_script.new()
		if pname in r:
			return r.get(pname)
	return fallback


## Массивы из .tres приходят как Array, а свойство может быть PackedStringArray — приводим.
static func _conv(current: Variant, v: Variant) -> Variant:
	if current is PackedStringArray and v is Array:
		return PackedStringArray(v)
	if current is Array and v is PackedStringArray:
		return Array(v)
	return v
