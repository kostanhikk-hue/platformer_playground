extends "res://game/enemy/enemy_dummy.gd"
## Манекен, поставленный конструктором: тот же враг, свойства — через behavior_override и contact_override.
## Поведение «По пути» — ходит по точкам пути path_uid (инструмент «Путь» конструктора).

var _reset_on_death := true


func setup_object(props: Resource, ctx: Dictionary) -> void:
	if props != null:
		behavior_override = props.behavior
		contact_override = props.contact_damage
		dir = -1 if props.facing == 1 else 1
		charge_dir = dir
		_reset_on_death = props.reset_on_death
		var path: Dictionary = ctx.get("paths", {}).get(props.path_uid, {})
		if not path.is_empty():
			path_points = path["points"]
			path_closed = path["closed"]
	kill_y = ctx.get("kill_y", NAN)


func apply_props(props: Resource, _placed = null) -> void:
	if props != null:
		behavior_override = props.behavior
		contact_override = props.contact_damage
		_reset_on_death = props.reset_on_death


func resets_on_death() -> bool:
	return _reset_on_death
