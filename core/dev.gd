extends RefCounted
## Признак dev-сборки. Пункты разработки (плейграунды, конструктор, панель параметров) видны только здесь.
## true — при запуске из редактора Godot или в экспорте с тегом «dev» (пресет экспорта «Dev»).

static func enabled() -> bool:
	return OS.has_feature("editor") or OS.has_feature("dev")
