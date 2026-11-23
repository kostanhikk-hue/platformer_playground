extends RefCounted
## Реплики: таблица content/dialog/lines.csv — колонки id, speaker, set, moment, note, ru (+ языки справа:
## en, de…). Колонки читаются по заголовкам; старая text / text_ru — как ru.
## Здесь — только служебные данные (говорящий, набор, момент). Текст — Loc.line(id), имя — Loc.speaker_name(),
## голос — Loc.voice_path(): content/vo/<язык озвучки>/<speaker>/<id>.ogg (.wav) с откатом на content/vo/ru/.
## Таблица перечитывается при каждом запуске уровня (reload) — агент поправил реплики, F5 — новые.

const Tables := preload("res://core/loc_tables.gd")
const PATH := Tables.LINES_PATH

static var _lines: Dictionary = {}
static var _sets: Dictionary = {}     ## имя набора → [id по порядку таблицы]
static var _moments: Dictionary = {}  ## момент → [id по порядку id]
static var _loaded := false


static func reload() -> void:
	_lines.clear()
	_sets.clear()
	_moments.clear()
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var t := Tables.read_table(PATH)
	for row in t["rows"]:
		var id: String = row["key"]
		var d: Dictionary = row["cells"].duplicate()
		d["id"] = id
		_lines[id] = d
		var s: String = d.get("set", "")
		if s != "":
			if not _sets.has(s):
				_sets[s] = []
			_sets[s].append(id)
		var m: String = d.get("moment", "")
		if m != "":
			if not _moments.has(m):
				_moments[m] = []
			_moments[m].append(id)
	for m in _moments:
		_moments[m].sort()


static func _ensure() -> void:
	if not _loaded:
		reload()


## Служебные данные реплики: {id, speaker, set, moment, note, ru, en…}. Текст для показа — Loc.line(id).
static func get_line(id: String) -> Dictionary:
	_ensure()
	return _lines.get(id, {})


static func has_line(id: String) -> bool:
	_ensure()
	return _lines.has(id)


static func set_lines(set_name: String) -> Array:
	_ensure()
	return _sets.get(set_name, [])


static func has_set(set_name: String) -> bool:
	_ensure()
	return _sets.has(set_name)


## Реплики момента (колонка moment) по порядку id.
static func moment_lines(moment: String) -> Array:
	_ensure()
	return _moments.get(moment, [])


static func all_ids() -> Array:
	_ensure()
	return _lines.keys()


static func speaker_of(id: String) -> String:
	return get_line(id).get("speaker", "")


## Имя говорящего в титрах на текущем языке (speaker.<id> в content/i18n/speakers.csv).
static func speaker_title(speaker: String) -> String:
	return Loc.speaker_name(speaker)


## Путь к файлу голоса (или ""): content/vo/<язык озвучки>/<speaker>/<id>.ogg / .wav, откат на ru.
static func voice_path(id: String) -> String:
	return Loc.voice_path(id, speaker_of(id))


## Звук голоса: импортированный — load(), свежий (ещё не открыт в Godot) — прямо из файла.
static func load_voice(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStream:
			return s
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	return null
