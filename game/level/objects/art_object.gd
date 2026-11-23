extends Node2D
## Арт-объект: картинка (центр — в положении объекта). Его контуры коллизии строит level_builder.

const ArtLoader := preload("res://game/level/art_loader.gd")

var _props: Resource


func setup_object(props: Resource, _ctx: Dictionary) -> void:
	_props = props


func _ready() -> void:
	if _props == null or _props.image == "":
		return
	var n := ArtLoader.make_node(_props.image, Rect2(), true)
	n.modulate = _props.modulate
	add_child(n)
