extends RefCounted
## loc: dev-file — сообщения об ошибках таблиц, видимого игроку текста нет
## Чтение таблиц локализации (без состояния). Ими пользуются автозагрузка Loc (core/loc.gd) и проверка
## tools/check_loc.gd. Таблицы:
##   content/i18n/*.csv        — ui, hints, speakers, cards… (любой новый .csv в папке подхватится сам);
##   content/dialog/lines.csv  — реплики (ключ — колонка id).
## Колонки читаются по заголовкам: код языка (ru, en, de, pt_BR, zh_CN…) — перевод, остальные — служебные.
## Старая колонка text (text_ru) читается как ru. Строки, у которых первая ячейка начинается с #, пропускаются.

const I18N_DIR := "res://content/i18n"
const LINES_PATH := "res://content/dialog/lines.csv"
const FONTS_FILE := "fonts.csv"        ## настройки шрифтов, не таблица строк
const UI_TABLE := "ui"                 ## по ней считается готовность языка
const SOURCE := "ru"                   ## исходный язык
## Служебные колонки: всё, что не перевод. Колонка с другим именем считается языком, если похожа на код языка.
const SERVICE := ["key", "id", "context", "max_len", "speaker", "set", "moment", "note", "image", "source", "vo_line",
	"locale", "role", "path", "chapter", "kind", "emotion", "priority", "cooldown", "audio"]
const LEGACY_SOURCE := ["text", "text_ru"]
## Окончания ключей множественного числа (CLDR).
const PLURAL_FORMS := ["zero", "one", "two", "few", "many", "other"]

static var _locale_rx: RegEx
static var _ph_rx: RegEx


## Похоже ли имя колонки на код языка: ru, en, de, pt_BR, zh_CN, zh_Hans, fil.
static func is_locale_column(h: String) -> bool:
	if h in SERVICE or h in LEGACY_SOURCE:
		return false
	if _locale_rx == null:
		_locale_rx = RegEx.create_from_string("^[a-z]{2,3}(_[A-Z]{2}|_[A-Z][a-z]{3})?$")
	return _locale_rx.search(h) != null


## Все таблицы строк: [путь, …] (сначала content/i18n по алфавиту, потом реплики).
static func table_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var files := DirAccess.get_files_at(I18N_DIR)
	files.sort()
	for f in files:
		# в сборке рядом лежат .import; сами CSV с importer="keep" копируются как есть
		if f.get_extension().to_lower() == "csv" and f != FONTS_FILE:
			out.append(I18N_DIR.path_join(f))
	if FileAccess.file_exists(LINES_PATH):
		out.append(LINES_PATH)
	return out


## Одна таблица: {path, name, header, locales, rows: [{key, line, cells}], errors}.
## line — номер строки в файле (для отчётов), cells — колонка → значение (у служебных колонок без пробелов по краям).
static func read_table(path: String) -> Dictionary:
	var t := {"path": path, "name": path.get_file().get_basename(), "header": PackedStringArray(),
		"locales": PackedStringArray(), "rows": [], "errors": PackedStringArray()}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		t["errors"].append("не открывается: %s" % path)
		return t
	var head := f.get_csv_line()
	var cols := PackedStringArray()
	for i in range(head.size()):
		var h := head[i].strip_edges()
		if i == 0:
			h = h.trim_prefix("﻿")   # Excel сохраняет UTF-8 с BOM
		if h in LEGACY_SOURCE:
			h = SOURCE
		cols.append(h)
	t["header"] = cols
	var key_col := cols.find("key")
	if key_col < 0:
		key_col = cols.find("id")
	if key_col < 0:
		t["errors"].append("%s: нет колонки key или id" % path)
		return t
	for h in cols:
		if is_locale_column(h) and not h in t["locales"]:
			t["locales"].append(h)
	var line := 1
	while not f.eof_reached():
		var row := f.get_csv_line()
		line += 1
		if row.size() <= key_col:
			continue
		var key := row[key_col].strip_edges()
		if key == "" or key.begins_with("#"):
			continue
		var cells := {}
		for i in range(mini(cols.size(), row.size())):
			if cols[i] == "":
				continue
			# пробелы по краям перевода значимы (разделитель « / »), у служебных колонок — нет
			cells[cols[i]] = row[i] if cols[i] in t["locales"] else row[i].strip_edges()
		t["rows"].append({"key": key, "line": line, "cells": cells})
	return t


## Все таблицы строк.
static func read_all() -> Array:
	var out: Array = []
	for p in table_paths():
		out.append(read_table(p))
	return out


## Шрифты: [{locale, role, path}] из content/i18n/fonts.csv. role: main — основной для языка, fallback — запасной.
## locale "*" — для всех языков.
static func read_fonts() -> Array:
	var out: Array = []
	var p := I18N_DIR.path_join(FONTS_FILE)
	if not FileAccess.file_exists(p):
		return out
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return out
	var head := f.get_csv_line()
	for i in range(head.size()):
		head[i] = head[i].strip_edges().trim_prefix("﻿")
	while not f.eof_reached():
		var row := f.get_csv_line()
		var d := {}
		for i in range(mini(head.size(), row.size())):
			d[head[i]] = row[i].strip_edges()
		var loc: String = d.get("locale", "")
		if loc == "" or loc.begins_with("#") or d.get("path", "") == "":
			continue
		out.append({"locale": loc, "role": d.get("role", "fallback"), "path": d["path"]})
	return out


## Имена подстановок в строке: "{count} из {name}" → ["count", "name"] (по порядку, без повторов).
static func placeholders(s: String) -> PackedStringArray:
	if _ph_rx == null:
		_ph_rx = RegEx.create_from_string("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	var out := PackedStringArray()
	for m in _ph_rx.search_all(s):
		var n := m.get_string(1)
		if not n in out:
			out.append(n)
	return out


static func placeholder_regex() -> RegEx:
	placeholders("")
	return _ph_rx


# ------------------------------------------------------------ множественное число (CLDR)

## Форма множественного числа для языка: one / few / many / other (CLDR, cardinal).
## Заложены ru и en; языки без правила получают other. Новый язык — ветка в match здесь и в plural_forms_of.
static func plural_category(locale: String, n: float) -> String:
	var lang := locale.split("_")[0]
	var is_int := is_equal_approx(n, roundf(n))
	var i := absi(roundi(n))
	match lang:
		"ru":
			if not is_int:
				return "other"
			var m10 := i % 10
			var m100 := i % 100
			if m10 == 1 and m100 != 11:
				return "one"
			if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
				return "few"
			return "many"
		"en":
			return "one" if is_int and i == 1 else "other"
		_:
			return "other"


## Какие формы есть у языка (для подсчёта готовости: пустая few у английского — не пропуск).
static func plural_forms_of(locale: String) -> PackedStringArray:
	var lang := locale.split("_")[0]
	match lang:
		"ru":
			return PackedStringArray(["one", "few", "many", "other"])
		"en":
			return PackedStringArray(["one", "other"])
		_:
			return PackedStringArray(["other"])


## Ключ формы множественного числа ("ui.cards_count.few") → ["ui.cards_count", "few"], иначе ["", ""].
static func split_plural(key: String) -> PackedStringArray:
	var dot := key.rfind(".")
	if dot > 0 and key.substr(dot + 1) in PLURAL_FORMS:
		return PackedStringArray([key.substr(0, dot), key.substr(dot + 1)])
	return PackedStringArray(["", ""])


## Нужна ли эта строка в языке (форма множественного числа, которой у языка нет, — не нужна).
static func row_needed(key: String, locale: String) -> bool:
	var sp := split_plural(key)
	if sp[0] == "":
		return true
	return sp[1] in plural_forms_of(locale)
