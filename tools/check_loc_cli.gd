extends SceneTree
## Проверка локализации без окна — для проверки перед сборкой:
##   godot --headless --path . --script tools/check_loc_cli.gd
## Печатает отчёт; код выхода 1, если есть ошибки (предупреждения сборку не останавливают).

const CheckLoc := preload("res://tools/check_loc.gd")


func _initialize() -> void:
	var r := CheckLoc.run()
	print(r["text"])
	quit(1 if not r["errors"].is_empty() else 0)
