extends Node
## Локализация (автозагрузка Loc). Читает таблицы content/i18n/*.csv и content/dialog/lines.csv
## (core/loc_tables.gd), для каждого языка регистрирует Translation в TranslationServer — поэтому
## Label / Button с ключом в text («ui.main_menu.play») переводятся сами и обновляются при смене языка.
##
##   Loc.t("ui.level.not_found", {"path": p})   перевод с подстановками {name}
##   Loc.plural("ui.cards_count", n)              множественное число (key.one / few / many / other)
##   Loc.line("cave_01_010") · Loc.speaker_name("goddess") · Loc.voice_path(id, speaker)
##   Loc.bind(label, key, args)                   текст из кода, который сам перестраивается при смене языка
##   Loc.ref(key, args)                           перевод как значение подстановки (вычисляется при показе)
##   сигнал locale_changed                        для всего, что рисует текст само (draw_string)
##
## Откат: выбранный язык → ru → сам ключ (в dev — предупреждение, один раз на ключ).
## Подстановка, которой нет в args, но которая совпадает с действием ввода ({jump}, {move}, {interact}),
## заменяется текущими клавишами из GameInput (клавиатура или геймпад — по последнему устройству).
## Dev: F9 — перечитать таблицы, F10 — псевдолокализация. Заметка: «Технология/Локализация — техника».

signal locale_changed

const Tables := preload("res://core/loc_tables.gd")
const Dev := preload("res://core/dev.gd")

const SOURCE := "ru"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "language"
const VO_DIR := "res://content/vo"
const VOICE_EXT := ["ogg", "wav"]
const SELF_NAME_KEY := "ui.language.self_name"
const UI_FONT_PATH := "res://art/fonts/ui_font.tres"
const RELOAD_KEY := KEY_F9
const PSEUDO_KEY := KEY_F10

var _text := {}            ## язык → {ключ → строка} (только непустые)
var _locales := PackedStringArray()      ## языки с колонкой в ui.csv
var _percent := {}         ## язык → процент перевода ui.csv
var _keys := {}            ## ключ → true (все ключи всех таблиц)
var _prefixes := {}        ## первые части ключей с точкой: ui, hint, speaker, card…
var _translations: Array[Translation] = []
var _locale := SOURCE
var _voice := SOURCE
var _pseudo := false
var _warned := {}
var _bound := {}           ## instance_id → true: узлы, привязанные через bind()
var _fonts: Array = []
var _ui_font: FontVariation
var _base_font: Font
var _base_fallbacks: Array[Font] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_font = load(UI_FONT_PATH) as FontVariation if ResourceLoader.exists(UI_FONT_PATH) else null
	if _ui_font != null:
		_base_font = _ui_font.base_font
		_base_fallbacks = _ui_font.fallbacks.duplicate()
	_load()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var saved: String = cfg.get_value(SETTINGS_SECTION, "text", "")
	_locale = saved if _usable(saved) else system_locale()
	var saved_voice: String = cfg.get_value(SETTINGS_SECTION, "voice", "")
	_voice = saved_voice if saved_voice in voice_codes() else _default_voice(_locale)
	_apply(false)
	if GameInput.has_signal("input_changed"):
		GameInput.input_changed.connect(_refresh_bound)


func _exit_tree() -> void:
	# Translation-объекты убираем сами: иначе движок освобождает их после скриптов
	for tr_obj in _translations:
		TranslationServer.remove_translation(tr_obj)
	_translations.clear()


# ================================================================ язык текста и озвучки

func get_locale() -> String:
	return _locale


## Сменить язык текста: сохраняется в user://settings.cfg (save = false — не сохранять, для тестов),
## весь текст обновляется сразу.
func set_locale(code: String, save := true) -> void:
	if not code in _locales:
		push_warning("Loc: нет языка «%s» (колонки в content/i18n/ui.csv)" % code)
		code = SOURCE
	_locale = code
	if save:
		_save("text", code)
	_apply(true)


func get_voice_locale() -> String:
	return _voice


## Язык озвучки — отдельно от текста. Папка content/vo/<язык>/; ru есть всегда.
func set_voice_locale(code: String, save := true) -> void:
	if not code in voice_codes():
		code = SOURCE
	_voice = code
	if save:
		_save("voice", code)


## Языки для меню: [{code, name, percent, ready}]. Готов — переведено 100 % ui.csv.
## include_unready — показать и недоделанные (в настройках это включено только в dev).
func available_locales(include_unready := false) -> Array:
	var out: Array = []
	for c in _sorted(_locales):
		var ready: bool = _percent.get(c, 0) >= 100
		if ready or include_unready:
			out.append({"code": c, "name": self_name(c), "percent": _percent.get(c, 0), "ready": ready})
	return out


## Языки озвучки: ru + папки content/vo/<код языка>/. [{code, name}]
func voice_locales() -> Array:
	var out: Array = []
	for c in voice_codes():
		out.append({"code": c, "name": self_name(c)})
	return out


func voice_codes() -> PackedStringArray:
	var out := PackedStringArray([SOURCE])
	if not DirAccess.dir_exists_absolute(VO_DIR):
		return out
	for d in DirAccess.get_directories_at(VO_DIR):
		if Tables.is_locale_column(d) and not d in out:
			out.append(d)
	return _sorted(out)


## Самоназвание языка: строка ui.language.self_name в его же колонке (или название из Godot).
func self_name(code: String) -> String:
	var s: String = _text.get(code, {}).get(SELF_NAME_KEY, "")
	return s if s != "" else TranslationServer.get_locale_name(code)


## Процент перевода ui.csv для языка (0–100).
func percent(code: String) -> int:
	return _percent.get(code, 0)


## Язык при первом запуске: язык системы, если он есть среди готовых, иначе ru.
func system_locale() -> String:
	var ready := PackedStringArray()
	for l in available_locales(false):
		ready.append(l["code"])
	var full := OS.get_locale()
	if full in ready:
		return full
	var lang := OS.get_locale_language()
	if lang in ready:
		return lang
	for c in ready:
		if c.split("_")[0] == lang:
			return c
	return SOURCE


func _usable(code: String) -> bool:
	if code == "" or not code in _locales:
		return false
	return _percent.get(code, 0) >= 100 or Dev.enabled()


func _default_voice(text_locale: String) -> String:
	return text_locale if text_locale in voice_codes() else SOURCE


func _save(field: String, value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, field, value)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Loc: не удалось сохранить %s (код %d)" % [SETTINGS_PATH, err])


func _sorted(codes: PackedStringArray) -> PackedStringArray:
	var rest := Array(codes)
	rest.erase(SOURCE)
	rest.sort()
	var out := PackedStringArray()
	if SOURCE in codes:
		out.append(SOURCE)
	out.append_array(PackedStringArray(rest))
	return out


# ================================================================ перевод

## Есть ли ключ хоть в одном языке.
func has(key: String) -> bool:
	return _keys.has(key)


## Перевод с подстановками: Loc.t("ui.card.new", {"title": Loc.ref("card.x.title")}).
## Значение подстановки может быть Callable — тогда оно вычисляется при каждом показе.
func t(key: String, args: Dictionary = {}) -> String:
	var s := _lookup(key)
	if s == key and not has(key):
		return key   # непереведённое видно сразу: ключ без скобок псевдолокализации
	return _format(_pseudo_wrap(s), args)


## Множественное число: ищет key.one / key.few / key.many / key.other по правилам языка, {count} = n.
func plural(key: String, n: float, args: Dictionary = {}) -> String:
	var a := args.duplicate()
	if not a.has("count"):
		a["count"] = n if not is_equal_approx(n, roundf(n)) else roundi(n)
	for loc in [_locale, SOURCE]:
		var form := Tables.plural_category(loc, n)
		var d: Dictionary = _text.get(loc, {})
		var s: String = d.get("%s.%s" % [key, form], d.get(key + ".other", ""))
		if s != "":
			if loc != _locale:
				_warn(key, "нет перевода на %s — показан русский" % _locale)
			return _format(_pseudo_wrap(s), a)
		if loc == SOURCE:
			break
	_warn(key, "нет строки в таблицах (формы %s.one / .other…)" % key)
	return key


## Текст реплики на текущем языке (с откатом на ru).
func line(id: String) -> String:
	return t(id)


## Имя говорящего: speaker.<id> в content/i18n/speakers.csv.
func speaker_name(speaker: String) -> String:
	return t("speaker." + speaker)


## Перевод как значение подстановки: вычисляется при каждом показе (смена языка, клавиш).
func ref(key: String, args: Dictionary = {}) -> Callable:
	return func() -> String: return t(key, args)


func _lookup(key: String) -> String:
	var s: String = _text.get(_locale, {}).get(key, "")
	if s != "":
		return s
	s = _text.get(SOURCE, {}).get(key, "")
	if s != "":
		if _locale != SOURCE:
			_warn(key, "нет перевода на %s — показан русский" % _locale)
		return s
	_warn(key, "строки нет в таблицах — показан ключ")
	return key


## Подстановки {name}: из args (Callable вызывается), иначе — клавиши действия ввода, иначе как есть.
func _format(s: String, args: Dictionary) -> String:
	if s.find("{") < 0:
		return s
	var rx := Tables.placeholder_regex()
	var out := ""
	var pos := 0
	for m in rx.search_all(s):
		out += s.substr(pos, m.get_start() - pos)
		var n := m.get_string(1)
		if args.has(n):
			var v = args[n]
			out += str(v.call() if v is Callable else v)
		elif GameInput.has_method("is_hint_action") and GameInput.is_hint_action(n):
			out += GameInput.keys_text(n)
		else:
			out += m.get_string()
		pos = m.get_end()
	return out + s.substr(pos)


## Псевдолокализация (встроенная в Godot, настройки — Project Settings → Internationalization →
## Pseudolocalization). Подстановки {name} защищаем: Godot пропускает только %s.
func _pseudo_wrap(s: String) -> String:
	if not _pseudo:
		return s
	var names := []
	var rx := Tables.placeholder_regex()
	var tmp := s.replace("%", "%%")
	for m in rx.search_all(s):
		names.append(m.get_string())
	tmp = rx.sub(tmp, "%s", true)
	var p := TranslationServer.pseudolocalize(tmp)
	for n in names:
		var i := p.find("%s")
		if i < 0:
			break
		p = p.substr(0, i) + n + p.substr(i + 2)
	return p.replace("%%", "%")


func _warn(key: String, what: String) -> void:
	if not Dev.enabled():
		return
	var k := key + "|" + _locale
	if _warned.has(k):
		return
	_warned[k] = true
	var msg := "Loc: «%s» — %s" % [key, what]
	push_warning(msg)
	var ev := get_node_or_null("/root/Events")
	if ev != null:
		ev.log_line("loc", msg)


# ================================================================ текст из кода

## Привязать текст узла (Label, Button, RichTextLabel…) к ключу: перестраивается сам при смене языка,
## перечитывании таблиц (F9) и смене клавиш / устройства ввода. Повторный bind заменяет ключ.
func bind(node: Node, key: String, args: Dictionary = {}) -> void:
	if node == null:
		return
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set_meta("loc_key", key)
	node.set_meta("loc_args", args)
	_bound[node.get_instance_id()] = true
	node.set("text", t(key, args))


func unbind(node: Node) -> void:
	if node != null:
		_bound.erase(node.get_instance_id())


func _refresh_bound() -> void:
	for id in _bound.keys():
		var n = instance_from_id(id)
		if n == null or not is_instance_valid(n) or not (n is Node) or not n.has_meta("loc_key"):
			_bound.erase(id)
			continue
		n.set("text", t(n.get_meta("loc_key"), n.get_meta("loc_args", {})))


# ================================================================ озвучка

## Путь к голосу реплики: content/vo/<голос>/<speaker>/<id>.ogg (.wav) → content/vo/ru/… → "".
## Пусто — титр держится по скорости чтения.
func voice_path(line_id: String, speaker: String) -> String:
	var langs := [_voice] if _voice == SOURCE else [_voice, SOURCE]
	for v in langs:
		for ext in VOICE_EXT:
			var p := "%s/%s/%s/%s.%s" % [VO_DIR, v, speaker, line_id, ext]
			if ResourceLoader.exists(p) or FileAccess.file_exists(p):
				return p
	return ""


# ================================================================ загрузка

## Перечитать таблицы (F9 в dev): можно править CSV при запущенной игре.
func reload() -> void:
	_load()
	if not _locale in _locales:
		_locale = SOURCE
	_apply(true)
	print("Loc: таблицы перечитаны — %d ключей, языки: %s" % [_keys.size(), ", ".join(_locales)])


func _load() -> void:
	_text.clear()
	_keys.clear()
	_prefixes.clear()
	_warned.clear()
	_percent.clear()
	_locales = PackedStringArray()
	for tbl in Tables.read_all():
		for e in tbl["errors"]:
			push_warning("Loc: " + e)
		for loc in tbl["locales"]:
			if not _text.has(loc):
				_text[loc] = {}
		for row in tbl["rows"]:
			var key: String = row["key"]
			_keys[key] = true
			var dot := key.find(".")
			if dot > 0:
				_prefixes[key.substr(0, dot)] = true
			for loc in tbl["locales"]:
				var v: String = row["cells"].get(loc, "")
				if v != "":
					_text[loc][key] = v
		if tbl["name"] == Tables.UI_TABLE:
			for loc in tbl["locales"]:
				_locales.append(loc)
				var need := 0
				var have := 0
				for row in tbl["rows"]:
					if not Tables.row_needed(row["key"], loc):
						continue
					need += 1
					if row["cells"].get(loc, "") != "":
						have += 1
				_percent[loc] = 100 if need == 0 else floori(100.0 * have / need)
	if not SOURCE in _locales:
		_locales.insert(0, SOURCE)
		_percent[SOURCE] = 100
	_fonts = Tables.read_fonts()


## Пересобрать Translation-объекты, шрифт, обновить текст на экране.
func _apply(notify: bool) -> void:
	for tr_obj in _translations:
		TranslationServer.remove_translation(tr_obj)
	_translations.clear()
	for loc in _locales:
		var tr_obj := Translation.new()
		tr_obj.locale = loc
		for key in _keys:
			if key.find(".") < 0:
				continue   # реплики (id без точки) — только через Loc.line, не автоперевод Control
			var s: String = _text.get(loc, {}).get(key, "")
			if s == "":
				s = _text.get(SOURCE, {}).get(key, "")
			if s != "":
				tr_obj.add_message(key, _pseudo_wrap(s))
		TranslationServer.add_translation(tr_obj)
		_translations.append(tr_obj)
	TranslationServer.set_locale(_locale)
	_apply_font()
	if notify:
		if is_inside_tree():
			get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
		_refresh_bound()
		locale_changed.emit()


## Шрифт интерфейса — art/fonts/ui_font.tres (FontVariation; его используют тема и все надписи).
## content/i18n/fonts.csv: main — основной шрифт для языка (вместо Noto Sans), fallback — запасной
## (для букв, которых нет в основном); locale «*» — для всех языков.
func _apply_font() -> void:
	if _ui_font == null:
		return
	var main: Font = _base_font
	var fb: Array[Font] = _base_fallbacks.duplicate()
	for row in _fonts:
		if row["locale"] != "*" and row["locale"] != _locale and row["locale"] != _locale.split("_")[0]:
			continue
		if not ResourceLoader.exists(row["path"]):
			push_warning("Loc: нет шрифта %s (content/i18n/fonts.csv)" % row["path"])
			continue
		var f := load(row["path"]) as Font
		if f == null:
			continue
		if row["role"] == "main":
			main = f
		elif not f in fb:
			fb.append(f)
	if _ui_font.base_font != main:
		_ui_font.base_font = main
	if _ui_font.fallbacks != fb:
		_ui_font.fallbacks = fb


# ================================================================ dev: F9, F10

func is_pseudo() -> bool:
	return _pseudo


## Псевдолокализация: длиннее на ~40 %, диакритика, скобки по краям. Непереведённое (захардкоженное
## и ключи без строки) остаётся без скобок.
func set_pseudo(on: bool) -> void:
	_pseudo = on
	_apply(true)
	print("Loc: псевдолокализация ", "вкл" if on else "выкл")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or not Dev.enabled():
		return
	if event.keycode == RELOAD_KEY:
		reload()
		get_viewport().set_input_as_handled()
	elif event.keycode == PSEUDO_KEY:
		set_pseudo(not _pseudo)
		get_viewport().set_input_as_handled()
