extends RefCounted
## Проверка таблиц локализации. Запуск:
##   из меню разработки — «Проверка локализации» (editor/check_loc_view.tscn);
##   без окна, перед сборкой — godot --headless --path . --script tools/check_loc_cli.gd (код выхода 1 при ошибках).
## Ошибки: повтор ключа, пустой ru, разные подстановки в языках, ключ из кода / сцены не найден в таблицах,
## захардкоженный видимый текст (кириллица в строках game/ и core/).
## Предупреждения: превышение max_len, неиспользуемые ключи. Сводка: процент перевода по языкам и таблицам.
##
## Что не считается захардкоженным текстом (инструменты разработчика остаются на русском):
##   файл с пометкой «## loc: dev-file» в первых строках; *_props.gd (свойства для инспектора конструктора);
##   строка с комментарием «# loc: dev» (если на ней открывается скобка — до закрывающей; на строке func —
##   вся функция); словари LABELS / UNITS / HINTS; строки @export…; тела функций debug_text() и _debug();
##   вызовы push_error / push_warning / print / log_line / _log и т. п.

const Tables := preload("res://core/loc_tables.gd")

const SCAN_USAGE := ["res://game", "res://core", "res://content"]
const SCAN_HARDCODE := ["res://game", "res://core"]
const DEV_FILE_MARK := "loc: dev-file"
const DEV_LINE_MARK := "loc: dev"
const DEV_FILE_HEAD_LINES := 15
const DEV_FUNCS := ["debug_text", "_debug"]
const DEV_DICTS := ["LABELS", "UNITS", "HINTS"]
const LOG_CALLS := ["push_error(", "push_warning(", "print(", "printerr(", "print_debug(", "print_rich(", "assert(",
	"log_line(", "_log(", "_warn(", "_script_error(", "_banner(", "_need("]
## Вызовы, первый аргумент которых — ключ строки (должен быть в таблицах).
const KEY_CALLS := ["Loc.t(", "tr(", "atr(", "Loc.bind(", "Loc.ref(", "show_hint(", "Loc.has("]
const PLURAL_CALLS := ["Loc.plural("]
const LINE_CALLS := ["say(", "Loc.line("]
const MOMENT_CALLS := ["say_moment("]
const SET_CALLS := ["bark(", "hint("]
const SCENE_TEXT_PROPS := ["text", "tooltip_text", "placeholder_text", "title"]

var errors := PackedStringArray()
var warnings := PackedStringArray()
var info := PackedStringArray()

var _key_rx := RegEx.create_from_string("^[a-z][a-z0-9_]*(\\.[a-z0-9_]+)+$")
var _prefix_rx := RegEx.create_from_string("^[a-z][a-z0-9_]*(\\.[a-z0-9_]+)*\\.$")
var _pattern_rx := RegEx.create_from_string("^[a-z][a-z0-9_.]*%[sd][a-z0-9_.%]*$")
var _cyr_rx := RegEx.create_from_string("[А-Яа-яЁё]")

var _tables: Array = []
var _where := {}           ## ключ → «ui.csv:12»
var _keys := {}            ## ключи i18n-таблиц (без реплик)
var _lines := {}           ## id реплики → {set, moment}
var _prefixes := {}        ## первые части ключей таблиц
var _used := {}            ## использованные ключи
var _used_prefix := []     ## «ui.key.» — всё с этим началом использовано
var _used_rx: Array = []   ## «card.%s.title» → RegEx
var _literals := {}        ## все строковые литералы кода (для реплик, наборов, моментов)


## Запустить все проверки. Возвращает {errors, warnings, info, text}.
static func run() -> Dictionary:
	var c = load("res://tools/check_loc.gd").new()
	c._run()
	return {"errors": c.errors, "warnings": c.warnings, "info": c.info, "text": c.report()}


func _run() -> void:
	_check_tables()
	for dir in SCAN_USAGE:
		for path in _files(dir):
			_scan_file(path, dir in SCAN_HARDCODE or _under(path, SCAN_HARDCODE))
	_check_unused()


func report() -> String:
	var out := PackedStringArray()
	out.append("ПРОВЕРКА ЛОКАЛИЗАЦИИ")
	out.append_array(info)
	out.append("")
	out.append("Ошибки: %d" % errors.size())
	for e in errors:
		out.append("  ⛔ " + e)
	out.append("")
	out.append("Предупреждения: %d" % warnings.size())
	for w in warnings:
		out.append("  ⚠ " + w)
	return "\n".join(out)


# ================================================================ таблицы

func _check_tables() -> void:
	_tables = Tables.read_all()
	var all_locales := PackedStringArray()
	var sizes := PackedStringArray()
	for t in _tables:
		sizes.append("%s (%d)" % [t["path"].get_file(), t["rows"].size()])
		for l in t["locales"]:
			if not l in all_locales:
				all_locales.append(l)
	info.append("Таблицы: " + ", ".join(sizes))
	info.append("Языки: " + ", ".join(all_locales))
	info.append("Перевод:")
	for t in _tables:
		for e in t["errors"]:
			errors.append(e)
		var fname: String = t["path"].get_file()
		var is_lines: bool = t["path"] == Tables.LINES_PATH
		if not Tables.SOURCE in t["locales"]:
			errors.append("%s: нет колонки ru (исходный язык)" % fname)
		var need := {}
		var have := {}
		for row in t["rows"]:
			var key: String = row["key"]
			var at := "%s:%d" % [fname, row["line"]]
			if _where.has(key):
				errors.append("повторяется ключ «%s»: %s и %s" % [key, _where[key], at])
			else:
				_where[key] = at
			if is_lines:
				_lines[key] = {"set": row["cells"].get("set", ""), "moment": row["cells"].get("moment", "")}
			else:
				_keys[key] = true
				var dot := key.find(".")
				if dot > 0:
					_prefixes[key.substr(0, dot)] = true
			var cells: Dictionary = row["cells"]
			var ru: String = cells.get(Tables.SOURCE, "")
			if ru.strip_edges() == "":
				errors.append("%s «%s»: пустой текст в ru" % [at, key])
			var ru_ph := Tables.placeholders(ru)
			var max_len := int(cells.get("max_len", "0")) if str(cells.get("max_len", "")).is_valid_int() else 0
			for loc in t["locales"]:
				var v: String = cells.get(loc, "")
				if Tables.row_needed(key, loc):
					need[loc] = need.get(loc, 0) + 1
					if v.strip_edges() != "":
						have[loc] = have.get(loc, 0) + 1
				if v.strip_edges() == "":
					continue
				if loc != Tables.SOURCE:
					var ph := Tables.placeholders(v)
					for n in ru_ph:
						if not n in ph:
							errors.append("%s «%s»: {%s} есть в ru, нет в %s" % [at, key, n, loc])
					for n in ph:
						if not n in ru_ph:
							errors.append("%s «%s»: {%s} есть в %s, нет в ru" % [at, key, n, loc])
				if max_len > 0 and v.length() > max_len:
					warnings.append("%s «%s»: %s длиннее max_len (%d > %d): «%s»" % [at, key, loc, v.length(), max_len, v])
		var parts := PackedStringArray()
		for loc in all_locales:
			if loc == Tables.SOURCE:
				continue
			if not loc in t["locales"]:
				parts.append("%s — нет колонки" % loc)
				continue
			var n: int = need.get(loc, 0)
			var h: int = have.get(loc, 0)
			parts.append("%s %d %% (%d/%d)" % [loc, 100 if n == 0 else floori(100.0 * h / n), h, n])
		info.append("  %s: %s" % [fname, ", ".join(parts) if not parts.is_empty() else "только ru"])
	if not _where.has("ui.language.self_name"):
		warnings.append("ui.csv: нет строки ui.language.self_name — самоназвания языков будут английскими (Godot)")


# ================================================================ код и сцены

func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var ext := f.get_extension()
		if ext == "gd" or ext == "tscn":
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_files(dir.path_join(sub)))
	return out


func _under(path: String, dirs: Array) -> bool:
	for d in dirs:
		if path.begins_with(d + "/"):
			return true
	return false


func _scan_file(path: String, check_hardcode: bool) -> void:
	var src := FileAccess.get_file_as_string(path)
	if src == "":
		return
	var lines := src.split("\n")
	var short := path.trim_prefix("res://")
	if path.ends_with(".tscn"):
		_scan_scene(short, lines, check_hardcode)
		return
	var dev_file := path.get_file().ends_with("_props.gd")
	for i in range(mini(lines.size(), DEV_FILE_HEAD_LINES)):
		if lines[i].find(DEV_FILE_MARK) >= 0:
			dev_file = true
	var in_dev_func := false
	var dev_depth := 0
	for i in range(lines.size()):
		var raw: String = lines[i]
		var parsed := _parse_line(raw)
		var code: String = parsed["code"]
		var comment: String = parsed["comment"]
		var lits: Array = parsed["literals"]
		# границы функции debug_text и словарей подписей
		if raw.begins_with("func "):
			in_dev_func = comment.find(DEV_LINE_MARK) >= 0
			for fn in DEV_FUNCS:
				if raw.begins_with("func %s(" % fn):
					in_dev_func = true
		elif raw.strip_edges() != "" and not raw.begins_with("\t") and not raw.begins_with(" ") and not raw.begins_with("#"):
			in_dev_func = false
		var dev_line := dev_file or in_dev_func or comment.find(DEV_LINE_MARK) >= 0 \
			or code.strip_edges().begins_with("@export")
		# словари подписей и строки с «# loc: dev» — до закрывающей скобки
		var bare: String = parsed["bare"]
		if dev_depth > 0 or _starts_dev_dict(code) or comment.find(DEV_LINE_MARK) >= 0:
			dev_line = true
			var opened := bare.count("{") + bare.count("[") + bare.count("(")
			var closed := bare.count("}") + bare.count("]") + bare.count(")")
			dev_depth = maxi(dev_depth + opened - closed, 0)
		for call in LOG_CALLS:
			if code.find(call) >= 0:
				dev_line = true
		for lit in lits:
			_use_literal(short, i + 1, code, lit, not dev_file)
			if check_hardcode and not dev_line and _cyr_rx.search(lit["text"]) != null:
				errors.append("%s:%d: видимый текст в коде «%s» — нужен ключ (или «# loc: dev» для инструментов)" % [short, i + 1, lit["text"].left(60)])


func _starts_dev_dict(code: String) -> bool:
	for d in DEV_DICTS:
		if code.begins_with("const %s" % d) or code.begins_with("var %s" % d):
			return true
	return false


func _scan_scene(short: String, lines: PackedStringArray, check_hardcode: bool) -> void:
	for i in range(lines.size()):
		var l: String = lines[i]
		for prop in SCENE_TEXT_PROPS:
			if not l.begins_with(prop + " = \""):
				continue
			var v := l.substr(prop.length() + 4).trim_suffix("\"")
			if _is_key(v):
				_mark_used(v, "%s:%d" % [short, i + 1], true)
			elif check_hardcode and _cyr_rx.search(v) != null:
				errors.append("%s:%d: видимый текст в сцене «%s» — нужен ключ" % [short, i + 1, v.left(60)])


## Строка кода → {code (без комментария), bare (код без содержимого строк), comment, literals: [{text, start}]}.
func _parse_line(s: String) -> Dictionary:
	var lits: Array = []
	var i := 0
	var code_end := s.length()
	var comment := ""
	var bare := ""
	while i < s.length():
		var ch := s[i]
		if ch == "#":
			code_end = i
			comment = s.substr(i)
			break
		if ch == "\"" or ch == "'":
			var q := ch
			var j := i + 1
			var buf := ""
			while j < s.length() and s[j] != q:
				if s[j] == "\\" and j + 1 < s.length():
					var esc := s[j + 1]
					buf += "\n" if esc == "n" else ("\t" if esc == "t" else esc)
					j += 2
					continue
				buf += s[j]
				j += 1
			lits.append({"text": buf, "start": i})
			bare += q + q
			i = j + 1
			continue
		bare += ch
		i += 1
	return {"code": s.substr(0, code_end), "bare": bare, "comment": comment, "literals": lits}


func _is_key(v: String) -> bool:
	if _key_rx.search(v) == null:
		return false
	var first := v.split(".")[0]
	return _prefixes.has(first)


## report — сообщать об ошибках (в файлах инструментов только отмечаем использование).
func _use_literal(short: String, line: int, code: String, lit: Dictionary, report := true) -> void:
	var v: String = lit["text"]
	_literals[v] = true
	var before := code.substr(0, lit["start"])
	var call := _call_before(before) if report else ""
	var at := "%s:%d" % [short, line]
	if _prefix_rx.search(v) != null and _prefixes.has(v.split(".")[0]):
		_used_prefix.append(v)   # "ui.epoch." + id — используются все ключи с этим началом
	elif _pattern_rx.search(v) != null and _prefixes.has(v.split(".")[0]):
		var rx := "^" + v.replace(".", "\\.").replace("%s", "[a-z0-9_]+").replace("%d", "[0-9]+") + "$"
		_used_rx.append(RegEx.create_from_string(rx))   # "card.%s.title" % id
	elif call in KEY_CALLS:
		_mark_used(v, at, true)
	elif call in PLURAL_CALLS:
		var found := false
		for f in Tables.PLURAL_FORMS:
			if _keys.has(v + "." + f):
				_used[v + "." + f] = true
				found = true
		if not found:
			errors.append("%s: нет строк множественного числа «%s.one / .other…» в таблицах" % [at, v])
	elif call in LINE_CALLS:
		if not _lines.has(v):
			errors.append("%s: нет реплики «%s» в content/dialog/lines.csv" % [at, v])
	elif call in MOMENT_CALLS:
		var ok := false
		for id in _lines:
			if _lines[id]["moment"] == v:
				ok = true
				break
		if not ok:
			errors.append("%s: нет реплик момента «%s» в content/dialog/lines.csv" % [at, v])
	elif call in SET_CALLS:
		pass
	elif _is_key(v):
		_mark_used(v, at, report)


## Имя вызова прямо перед строкой: «Loc.t(», «say(»… (или "").
func _call_before(before: String) -> String:
	var b := before.strip_edges(false, true)
	if not b.ends_with("("):
		return ""
	var j := b.length() - 2
	while j >= 0 and (b[j] == "_" or b[j] == "." or b.unicode_at(j) < 128 and (b[j].is_valid_identifier() or b[j].is_valid_int())):
		j -= 1
	var name := b.substr(j + 1)
	if not name.begins_with("Loc.") and name.find(".") >= 0:
		name = name.substr(name.rfind(".") + 1)   # runtime.show_hint( → show_hint(
	return name


func _mark_used(key: String, at: String, must_exist: bool) -> void:
	_used[key] = true
	if must_exist and not _keys.has(key) and not _lines.has(key):
		errors.append("%s: ключа «%s» нет в таблицах" % [at, key])


func _check_unused() -> void:
	var unused := PackedStringArray()
	for key in _keys:
		if _is_used(key):
			continue
		unused.append(key)
	unused.sort()
	for k in unused:
		warnings.append("не используется: «%s» (%s)" % [k, _where.get(k, "?")])
	var by_group := {}
	for id in _lines:
		var d: Dictionary = _lines[id]
		if _literals.has(id) or (d["set"] != "" and _literals.has(d["set"])) or (d["moment"] != "" and _literals.has(d["moment"])):
			continue
		var g: String = d["moment"] if d["moment"] != "" else (d["set"] if d["set"] != "" else "без момента")
		by_group[g] = by_group.get(g, 0) + 1
	if not by_group.is_empty():
		var parts := PackedStringArray()
		var keys := by_group.keys()
		keys.sort()
		for g in keys:
			parts.append("%s: %d" % [g, by_group[g]])
		warnings.append("реплики, на которые нет ссылок в сценариях: " + ", ".join(parts))


func _is_used(key: String) -> bool:
	if _used.has(key):
		return true
	var sp := Tables.split_plural(key)
	if sp[0] != "" and _used.has(sp[0]):
		return true
	for p in _used_prefix:
		if key.begins_with(p):
			return true
	for rx in _used_rx:
		if rx.search(key) != null:
			return true
	return false
