extends RefCounted
## Карточки-научпоп: служебная таблица content/dialog/cards.csv (колонки id, image, source, vo_line).
## Тексты — в content/i18n/cards.csv по ключам card.<id>.title / where / when / text (Loc).
## Собранные карточки — в памяти на время сессии (сохранение на диск — фаза 8).

const Tables := preload("res://core/loc_tables.gd")
const PATH := "res://content/dialog/cards.csv"
const TEXT_FIELDS := ["title", "where", "when", "text"]

static var _cards: Dictionary = {}
static var _loaded := false
static var collected: Dictionary = {}   ## id → true (за сессию)


static func reload() -> void:
	_cards.clear()
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	for row in Tables.read_table(PATH)["rows"]:
		var d: Dictionary = row["cells"].duplicate()
		d["id"] = row["key"]
		_cards[row["key"]] = d


static func all() -> Dictionary:
	if not _loaded:
		reload()
	return _cards


## Запись карточки: {id, image, source, vo_line} + title / where / when / text на текущем языке
## (для конструктора; игра показывает тексты через ключи, чтобы они менялись вместе с языком).
static func get_card(id: String) -> Dictionary:
	var c: Dictionary = all().get(id, {})
	if c.is_empty():
		return c
	c = c.duplicate()
	for f in TEXT_FIELDS:
		var key := text_key(id, f)
		c[f] = Loc.t(key) if Loc.has(key) else ""
	return c


## Ключ текста карточки: card.<id>.title / where / when / text.
static func text_key(id: String, field: String) -> String:
	return "card.%s.%s" % [id, field]


static func ids() -> PackedStringArray:
	var out := PackedStringArray(all().keys())
	out.sort()
	return out
