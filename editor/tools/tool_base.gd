extends RefCounted
## Общий интерфейс инструмента конструктора. Один инструмент — один скрипт.
##   activate() / deactivate()     — выбран / снят;
##   input(event)                  — мышь на холсте;
##   key(event) -> bool            — клавиши (true — обработано, общие горячие клавиши не срабатывают);
##   draw_overlay(canvas)          — нарисовать своё поверх холста (в мировых координатах);
##   title(), hint()               — для строки состояния.

const EdInput := preload("res://editor/editor_input.gd")
const Commands := preload("res://editor/commands.gd")
const Geometry := preload("res://core/geometry.gd")

var ed


func _init(editor) -> void:
	ed = editor


func activate() -> void:
	pass


func deactivate() -> void:
	pass


func input(_event: InputEvent) -> void:
	pass


func key(_event: InputEvent) -> bool:
	return false


func draw_overlay(_c: Node2D) -> void:
	pass


func title() -> String:
	return ""


func hint() -> String:
	return ""
