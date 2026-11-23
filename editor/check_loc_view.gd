extends Control
## Меню разработки → «Проверка локализации»: отчёт tools/check_loc.gd. Esc — назад в меню разработки.

const CheckLoc := preload("res://tools/check_loc.gd")
const DEV_MENU := "res://editor/launcher.tscn"

var _out: TextEdit
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 12
	box.offset_right = -16
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := Label.new()
	title.text = "ПРОВЕРКА ЛОКАЛИЗАЦИИ"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	head.add_child(title)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_status)
	var again := Button.new()
	again.text = "Проверить снова (F9 — перечитать таблицы в игре)"
	again.pressed.connect(_check)
	head.add_child(again)
	var back := Button.new()
	back.text = "← Меню разработки (Esc)"
	back.pressed.connect(_back)
	head.add_child(back)
	_out = TextEdit.new()
	_out.editable = false
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_out.add_theme_font_size_override("font_size", 13)
	box.add_child(_out)
	_check()


func _check() -> void:
	var r := CheckLoc.run()
	_out.text = r["text"]
	_status.text = "ошибок: %d · предупреждений: %d" % [r["errors"].size(), r["warnings"].size()]
	_status.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if not r["errors"].is_empty() else Color(0.6, 1, 0.6))


func _back() -> void:
	get_tree().change_scene_to_file(DEV_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_back()
