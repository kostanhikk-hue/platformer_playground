class_name PlacedObject
extends Resource
## Объект, поставленный на уровень: ссылка на ObjectDef каталога + положение + переопределённые свойства.

@export var uid: String = ""
@export var def_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var rotation_deg: float = 0.0
@export var scale: Vector2 = Vector2.ONE
@export var flip_h: bool = false
@export var layer: int = 3
## Свойства, отличные от каталога (имя → значение). Остальное берётся из props_script объекта.
@export var props: Dictionary = {}
