extends Node2D
## Подпись. В игре видна, только если включено «Видна в игре».

var _props: Resource


func setup_object(props: Resource, _ctx: Dictionary) -> void:
	_props = props


func _ready() -> void:
	if _props == null or not _props.show_in_game:
		visible = false
		return
	var l := Label.new()
	l.text = _props.text
	l.add_theme_font_size_override("font_size", _props.font_size)
	l.add_theme_color_override("font_color", _props.color)
	add_child(l)
