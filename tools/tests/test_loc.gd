extends SceneTree
## Проверка локализации без окна (файлы проекта не меняет):
##   godot --headless --path . --script tools/tests/test_loc.gd
## Смена языка на лету, откат на ru, множественное число, подсказки с клавишами, псевдолокализация.

var _fails := 0
var _checks := 0


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loc: Node = root.get_node("Loc")
	var gi: Node = root.get_node("GameInput")
	var start_locale: String = loc.get_locale()
	print("Языки: ", loc.available_locales(true))

	# 1. языки и готовность
	var codes := []
	for l in loc.available_locales(false):
		codes.append(l["code"])
	_ok("ru" in codes and "en" in codes, "ru и en — готовые языки")
	_ok(loc.self_name("en") == "English" and loc.self_name("ru") == "Русский", "самоназвания языков")

	# 2. автоперевод Control и смена языка на лету
	loc.set_locale("ru", false)
	var lbl := Label.new()
	lbl.text = "ui.main_menu.play"
	root.add_child(lbl)
	await process_frame
	_ok(lbl.get_tree() != null and lbl.atr(lbl.text) == "Играть уровень", "Label с ключом — русский")
	loc.set_locale("en", false)
	await process_frame
	_ok(lbl.atr(lbl.text) == "Play level", "после set_locale(en) — английский")
	var bound := Label.new()
	root.add_child(bound)
	loc.bind(bound, "ui.level.not_found", {"path": "x.tres"})
	_ok(bound.text == "Level not found: x.tres", "bind с подстановкой (en): " + bound.text)
	loc.set_locale("ru", false)
	_ok(bound.text == "Уровень не найден: x.tres", "bind перестроился на ru: " + bound.text)

	# 3. откат реплики на ru
	loc.set_locale("en", false)
	var ru_text: String = loc._text["ru"].get("goddess_test_001", "")
	_ok(ru_text != "" and loc.line("goddess_test_001") == ru_text, "реплика без en показывается на русском")
	_ok(loc.speaker_name("goddess") == "Goddess", "имя говорящего en")
	_ok(loc.t("no.such.key") == "no.such.key", "нет ключа — показывается ключ")

	# 4. множественное число
	loc.set_locale("ru", false)
	var ru := []
	for n in [1, 3, 5, 11, 21, 22, 25, 1.5]:
		ru.append(loc.plural("ui.cards_count", n))
	_ok(ru == ["1 карточка", "3 карточки", "5 карточек", "11 карточек", "21 карточка", "22 карточки", "25 карточек", "1.5 карточки"], "ru: " + ", ".join(ru))
	loc.set_locale("en", false)
	var en := [loc.plural("ui.cards_count", 1), loc.plural("ui.cards_count", 5), loc.plural("ui.cards_count", 0)]
	_ok(en == ["1 card", "5 cards", "0 cards"], "en: " + ", ".join(en))

	# 5. подсказка с клавишами: устройство и переназначение
	loc.set_locale("ru", false)
	gi.set_device(gi.DEVICE_KEYBOARD)
	var hint := Label.new()
	root.add_child(hint)
	loc.bind(hint, "hint.move")
	var kb := hint.text
	_ok(kb.find("A / D") >= 0 and kb.find("Пробел / W") >= 0, "клавиатура: " + kb)
	gi.set_device(gi.DEVICE_PAD)
	_ok(hint.text.find("Левый стик") >= 0 and hint.text.find("A") >= 0 and hint.text != kb, "геймпад: " + hint.text)
	gi.set_device(gi.DEVICE_KEYBOARD)
	var old_jump: Array = InputMap.action_get_events("jump")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_Z
	gi.rebind("jump", [k])
	_ok(hint.text.find("Z — прыжок") >= 0, "после переназначения: " + hint.text)
	gi.rebind("jump", old_jump)
	loc.set_locale("en", false)
	_ok(hint.text.find("Space / W") >= 0, "en: " + hint.text)

	# 6. псевдолокализация
	loc.set_locale("ru", false)
	loc.set_pseudo(true)
	await process_frame
	var p: String = lbl.atr(lbl.text)
	_ok(p.begins_with("[") and p.length() >= int("Играть уровень".length() * 1.3), "псевдолокализация Label: " + p)
	var pb: String = bound.text
	_ok(pb.find("x.tres") >= 0 and pb.begins_with("["), "псевдолокализация с подстановкой: " + pb)
	var plain := Label.new()
	plain.text = "Захардкожено"
	root.add_child(plain)
	_ok(plain.atr(plain.text) == "Захардкожено", "текст без ключа остаётся без скобок")
	loc.set_pseudo(false)

	# 7. озвучка: пути
	_ok(loc.voice_path("no_such_line", "goddess") == "", "нет файла голоса — пусто")

	# 8. шрифт: запасной шрифт из fonts.csv подключён
	var f := load("res://art/fonts/ui_font.tres") as FontVariation
	_ok(f != null and f.fallbacks.size() >= 1, "ui_font: запасных шрифтов %d" % (f.fallbacks.size() if f else 0))
	_ok(ThemeDB.fallback_font == f or ThemeDB.get_project_theme() != null, "тема/шрифт проекта подключены")

	loc.set_locale(start_locale, false)
	print("Итого: %d проверок, ошибок %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
