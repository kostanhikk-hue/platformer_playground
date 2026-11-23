extends "res://game/level/objects/dummy.gd"
## Манекен-холст: манекен с закрашиванием по телу (game/components/coverage.gd). Закрашен на 100 % — исчезает
## (on_full = «Уничтожить владельца»). hp_damage выкл — победить можно только закрашиванием.

const CoverageScript := preload("res://game/components/coverage.gd")
const CoverageProps := preload("res://game/components/coverage_props.gd")

var cov: Node2D
var _hp_damage := false
var _kb_mult := 0.15


func setup_object(props: Resource, ctx: Dictionary) -> void:
	super(props, ctx)
	_hp_damage = props.hp_damage if props != null else false
	_kb_mult = props.knockback_mult if props != null else 0.15
	if p == null:
		p = Params.get_res("dummy")
	var hw: float = p.body_width * 0.5
	var hh: float = p.body_height * 0.5
	var area := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	cov = CoverageScript.new()
	cov.name = "Coverage"
	var c := ctx.duplicate()
	c["shapes"] = {"area": [{"points": area, "closed": true, "uid": ""}]}
	c["owner_node"] = self
	c["placed"] = null
	c["def"] = null
	cov.setup_object(_cov_props(props), c)
	add_child(cov)


## Штрихи проходят сквозь холст (он впитывает краску, а не стоит на волне) — иначе волна подбрасывает
## манекена и закрашивает только низ. Маска тела — только «Мир», без слоя «Штрихи».
func _ready() -> void:
	super()
	collision_mask = WORLD_LAYER


func _cov_props(props: Resource) -> Resource:
	var cp := CoverageProps.new()
	cp.on_full = 1
	if props != null:
		for k in ["accept_ink", "accept_wave", "accept_melee", "paint_strength", "wash_rate", "thresholds"]:
			cp.set(k, props.get(k))
	return cp


func apply_props(props: Resource, placed = null) -> void:
	super(props, placed)
	_hp_damage = props.hp_damage
	_kb_mult = props.knockback_mult
	if cov != null:
		cov.apply_props(_cov_props(props))


func take_hit(info: Dictionary) -> bool:
	info = info.duplicate()
	info["knockback"] = (info.get("knockback", Vector2.ZERO) as Vector2) * _kb_mult
	if not _hp_damage:
		info["damage"] = 0.0
	return super(info)


func snapshot() -> Dictionary:
	var d := super()
	if cov != null:
		d["cov"] = cov.snapshot()
	return d


func restore(d: Dictionary) -> void:
	super(d)
	if cov != null and d.has("cov"):
		cov.restore(d["cov"])
	if cov != null:
		cov.visible = not gone


func debug_text() -> String:
	return super() + (" · " + cov._debug() if cov != null else "")
