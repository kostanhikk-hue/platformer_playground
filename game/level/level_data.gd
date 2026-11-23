class_name LevelData
extends Resource
## Уровень целиком: границы, фоны, контуры коллизии, объекты. Файл: res://content/levels/<эпоха>/<id>.tres.
## Ресурсы частей лежат рядом (по ТЗ — «в level_data.gd», но Godot сохраняет в .tres только ресурсы
## с собственным файлом скрипта): geo_shape.gd, placed_object.gd, background_layer.gd.
## Здесь же — общие для игры и конструктора функции: преобразования объектов и контуров, поиск по uid.

const FORMAT_VERSION := 1
const PlateProps := preload("res://game/components/plate_props.gd")
const EPOCHS := ["common", "cave", "egypt", "greece"]
const EPOCH_TITLES := ["Общее", "Пещера", "Египет", "Греция"]  # loc: dev — подписи конструктора; в игре — ключи ui.epoch.*
const LEVELS_DIR := "res://content/levels"
const T := 32.0

## Слои: порядок рисования снизу вверх. Геймплей — там, где герой (z = 0).
const LAYER_TITLES := ["Дальний фон", "Картина-основа", "Задний декор", "Геймплей", "Передний план", "Служебный"]  # loc: dev — конструктор
const LAYER_Z := [-400, -300, -200, 0, 200, 300]
enum Layer { FAR, BASE, BACK_DECOR, GAMEPLAY, FRONT, SERVICE }

@export var format_version: int = FORMAT_VERSION
@export var id: String = "new_level"
@export var title: String = "Новый уровень"
@export var epoch: String = "common"
@export var bounds: Rect2 = Rect2(0, 0, 60 * 32, 20 * 32)
@export var kill_y: float = 940.0
@export var bg_color: Color = Color(0.09, 0.1, 0.14)
@export var backgrounds: Array[BackgroundLayer] = []
@export var shapes: Array[GeoShape] = []
@export var objects: Array[PlacedObject] = []
## Камера конструктора, видимость слоёв и т. п. Игра это поле не читает.
@export var editor_state: Dictionary = {}
## Ошибки, найденные проверкой при последнем сохранении (игра показывает предупреждение). Добавлено к ТЗ.
@export var known_errors: PackedStringArray = PackedStringArray()
## Темнота уровня (фаза 2): CanvasModulate этим цветом. Выключена — свет только отмечает радиус.
@export var darkness_enabled: bool = false
@export var darkness_color: Color = Color(0.16, 0.14, 0.2)
## Пресет кисти уровня (путь к data/presets/brush/*.tres). Пусто — текущие значения вкладки «Кисть».
@export var brush_preset: String = ""


static func path_for(epoch_name: String, level_id: String) -> String:
	return "%s/%s/%s.tres" % [LEVELS_DIR, epoch_name, level_id]


## Загрузка с миграцией старых версий формата.
static func load_level(path: String) -> LevelData:
	var r = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (r is LevelData):
		return null
	_migrate(r)
	return r


static func _migrate(level: LevelData) -> void:
	# format_version 1 — текущая. Здесь появятся шаги миграции при смене формата.
	# Шаги по содержимому (без смены версии — по старому имени свойства, поэтому их можно повторять):
	#   плита: pressed_by (0 герой / 1 враг / 2 любое тело) → галочки press_hero / press_enemies / press_strokes / press_bodies.
	for o in level.objects:
		PlateProps.migrate_pressed_by(o.props)
	level.format_version = FORMAT_VERSION


func find_object(obj_uid: String) -> PlacedObject:
	for o in objects:
		if o.uid == obj_uid:
			return o
	return null


func find_shape(shape_uid: String) -> GeoShape:
	for s in shapes:
		if s.uid == shape_uid:
			return s
	return null


func find_any(any_uid: String) -> Resource:
	var r: Resource = find_object(any_uid)
	if r == null:
		r = find_shape(any_uid)
	if r == null:
		for b in backgrounds:
			if b.uid == any_uid:
				return b
	return r


func shapes_of(obj_uid: String) -> Array:
	return shapes.filter(func(s): return s.parent_uid == obj_uid)


## Формы объекта с заданной ролью ("" — все формы-роли).
func role_shapes(obj_uid: String, role_name: String = "") -> Array:
	return shapes.filter(func(s): return s.parent_uid == obj_uid and s.role != "" and (role_name == "" or s.role == role_name))


func paths() -> Array:
	return shapes.filter(func(s): return s.kind == GeoShape.Kind.PATH)


func all_uids() -> Dictionary:
	var d := {}
	for a in [backgrounds, shapes, objects]:
		for r in a:
			d[r.uid] = true
	return d


## Новый uid вида <тип>_<номер>, уникальный в уровне.
func next_uid(prefix: String) -> String:
	var used := all_uids()
	var n := 1
	for u in used:
		if u.begins_with(prefix + "_"):
			var tail: String = u.substr(prefix.length() + 1)
			if tail.is_valid_int():
				n = maxi(n, int(tail) + 1)
	while used.has("%s_%d" % [prefix, n]):
		n += 1
	return "%s_%d" % [prefix, n]


static func object_xform(o: PlacedObject) -> Transform2D:
	var sc := o.scale
	if o.flip_h:
		sc.x = -sc.x
	return Transform2D(deg_to_rad(o.rotation_deg), sc, 0.0, o.position)


## Преобразование «локальные точки контура → мир» (с учётом арт-объекта-родителя).
func shape_xform(s: GeoShape) -> Transform2D:
	var xf := Transform2D(0.0, s.position)
	if s.parent_uid != "":
		var parent := find_object(s.parent_uid)
		if parent != null:
			xf = object_xform(parent) * xf
	return xf


func shape_world_points(s: GeoShape) -> PackedVector2Array:
	return shape_xform(s) * s.points
