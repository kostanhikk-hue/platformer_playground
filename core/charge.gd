extends RefCounted
## Общий заряд удержанием для любых приёмов (линия, волна, будущие).
## Ресурс приёма должен содержать поля блока «Заряд» (см. CHARGE_FIELDS) с одинаковыми именами.
##
## Как работает: нажал — копится время удержания hold; заряд c = (hold / charge_time)^charge_curve (0..1).
## Размеры и урон растут от «при нулевом заряде» до «при полном» (× базовых): Charge.mult(p, "length", c).
##
## Расход чернил (charge_cost_mode):
##   0 «При выпуске»       — платишь при отпускании: цена × lerp(1, charge_cost_max, c).
##                           Не хватает на полный заряд — бьёт тем, что можно оплатить.
##   1 «Во время удержания» — при отпускании платишь базовую цену, а пока держишь — чернила
##                           утекают со скоростью charge_drain_rate. Заряд растёт, только пока есть чем платить.

const CHARGE_FIELDS := ["charge_enabled", "charge_time", "charge_curve", "auto_release", "charge_move_mult",
	"charge_cost_mode", "charge_cost_max", "charge_drain_rate"]

enum { COST_ON_RELEASE, COST_WHILE_HOLDING }


## Доля удержания 0..1 (без кривой) — для кольца заряда.
static func raw(p: Resource, hold: float) -> float:
	return clampf(hold / maxf(p.charge_time, 0.01), 0.0, 1.0)


## Заряд 0..1 с учётом кривой.
static func eased(p: Resource, hold: float) -> float:
	if not p.charge_enabled:
		return 0.0
	return pow(raw(p, hold), maxf(p.charge_curve, 0.01))


## Множитель величины по заряду: поля charge_<key>_min / charge_<key>_max.
static func mult(p: Resource, key: String, c: float) -> float:
	if not p.charge_enabled:
		return 1.0
	return lerpf(p.get("charge_%s_min" % key), p.get("charge_%s_max" % key), c)


## Цена при отпускании.
static func release_cost(p: Resource, base_cost: float, c: float) -> float:
	if not p.charge_enabled or p.charge_cost_mode == COST_WHILE_HOLDING:
		return base_cost
	return base_cost * lerpf(1.0, p.charge_cost_max, c)


## Урезает заряд до того, что можно оплатить (режим «при выпуске»).
static func affordable(p: Resource, base_cost: float, ink: float, c: float) -> float:
	if not p.charge_enabled or p.charge_cost_mode != COST_ON_RELEASE or p.charge_cost_max <= 1.0:
		return c
	var allowed: float = (ink / maxf(base_cost, 0.01) - 1.0) / (p.charge_cost_max - 1.0)
	return minf(c, clampf(allowed, 0.0, 1.0))


## Один кадр удержания. Возвращает {hold, ink, stalled}: новое время удержания, остаток чернил,
## и stalled = true, если в режиме «во время удержания» чернила кончились (заряд дальше не растёт).
static func tick(p: Resource, hold: float, ink: float, base_cost: float, delta: float) -> Dictionary:
	if p.charge_cost_mode != COST_WHILE_HOLDING:
		return {"hold": hold + delta, "ink": ink, "stalled": false}
	# базовая цена отложена на выпуск; утекает только то, что сверху
	var spare: float = ink - base_cost
	var need: float = p.charge_drain_rate * delta
	if raw(p, hold) >= 1.0:
		return {"hold": hold + delta, "ink": ink, "stalled": false}   # полный заряд — больше не тратим
	if spare <= 0.0 and need > 0.0:
		return {"hold": hold, "ink": ink, "stalled": true}
	var paid: float = minf(need, maxf(spare, 0.0))
	var dt: float = delta if need <= 0.0 else delta * paid / need
	return {"hold": hold + dt, "ink": ink - paid, "stalled": paid < need}
