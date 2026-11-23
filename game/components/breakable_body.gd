extends StaticBody2D
## Тело разрушаемого блока: передаёт попадания компоненту (интерфейс цели — атаки ищут цели в слое «Враги»).

var owner_component: Node


func take_hit(info: Dictionary) -> bool:
	return owner_component != null and owner_component.take_hit(info)


func contact_damage_amount() -> float:
	return 0.0
