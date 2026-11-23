extends Node
## loc: dev-file — инструмент разработчика, текст не локализуется
## Реестр параметров (автозагрузка Params). Единственное место, где перечислены все наборы настроек.
## Каждый набор загружается ОДИН раз и раздаётся всем: игре, плейграундам, герою, врагам.
## Поэтому ползунок на панели меняет значение сразу везде.
##
## Новый набор параметров:
##   1. создай data/<имя>_params.gd (extends Resource, @export-переменные, LABELS/UNITS/HINTS);
##   2. добавь строку в REGISTRY;
##   3. в плейграунде допиши ключ в param_keys().
## Файл .tres создастся сам по кнопке «Сохранить в файл» (или tools/generate_data.gd).

const REGISTRY := {
	"movement": {"title": "Движ.", "script": "res://data/movement_params.gd", "file": "res://data/movement_default.tres", "presets": "res://data/presets/movement"},
	"attack": {"title": "Удар", "script": "res://data/attack_params.gd", "file": "res://data/attack_default.tres", "presets": "res://data/presets/attack"},
	"ink": {"title": "Линия", "script": "res://data/ink_params.gd", "file": "res://data/ink_default.tres", "presets": "res://data/presets/ink"},
	"wave": {"title": "Волна", "script": "res://data/wave_params.gd", "file": "res://data/wave_default.tres", "presets": "res://data/presets/wave"},
	"brush": {"title": "Кисть", "script": "res://data/brush_params.gd", "file": "res://data/brush_default.tres", "presets": "res://data/presets/brush"},
	"dummy": {"title": "Враг", "script": "res://data/dummy_params.gd", "file": "res://data/dummy_default.tres", "presets": "res://data/presets/dummy"},
	"camera": {"title": "Камера", "script": "res://data/camera_params.gd", "file": "res://data/camera_default.tres", "presets": "res://data/presets/camera"},
	"paintable": {"title": "Контур", "script": "res://data/paintable_params.gd", "file": "res://data/paintable_default.tres", "presets": "res://data/presets/paintable"},
	"coverage": {"title": "Закраска", "script": "res://data/coverage_params.gd", "file": "res://data/coverage_default.tres", "presets": ""},
	"interact": {"title": "Взаимодействие", "script": "res://data/interact_params.gd", "file": "res://data/interact_default.tres", "presets": ""},
	"light": {"title": "Свет", "script": "res://data/light_params.gd", "file": "res://data/light_default.tres", "presets": ""},
	"objects": {"title": "Объекты", "script": "res://data/objects_params.gd", "file": "res://data/objects_default.tres", "presets": ""},
	"subtitle": {"title": "Титры", "script": "res://data/subtitle_params.gd", "file": "res://data/subtitle_default.tres", "presets": ""},
	"world": {"title": "Мир", "script": "res://data/world_params.gd", "file": "res://data/world_default.tres", "presets": ""},
	"editor": {"title": "Редактор", "script": "res://data/editor_params.gd", "file": "res://data/editor_default.tres", "presets": ""},
}

var _cache := {}


## Ресурс параметров по ключу из REGISTRY. Если файла нет — значения из скрипта.
func get_res(key: String) -> Resource:
	if _cache.has(key):
		return _cache[key]
	var info: Dictionary = REGISTRY[key]
	var r: Resource
	if ResourceLoader.exists(info["file"]):
		r = load(info["file"])
	else:
		push_warning("Нет файла %s — беру значения из скрипта (сохранится кнопкой «Сохранить в файл»)" % info["file"])
		r = (load(info["script"]) as Script).new()
		r.take_over_path(info["file"])
	_cache[key] = r
	return r


## Запись для панели настроек.
func entry(key: String) -> Dictionary:
	var info: Dictionary = REGISTRY[key]
	return {"title": info["title"], "res": get_res(key), "preset_dir": info["presets"]}


var world: Resource:
	get:
		return get_res("world")
