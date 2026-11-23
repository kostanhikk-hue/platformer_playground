class_name GeoShape
extends Resource
## Один контур коллизии уровня. Строится в игре game/level/geometry_builder.gd.
## points — в локальных координатах контура (относительно position);
## если parent_uid не пуст — всё это в координатах арт-объекта (двигается, масштабируется и отражается с ним).

## PATH — путь для движущихся объектов (без коллизии); может быть замкнутым (closed).
enum Kind { BODY, PLATFORM, WALL, RECT, KILL, PATH }
enum Mat { NORMAL, ICE }

const KIND_NAMES := ["body", "platform", "wall", "rect", "kill", "path"]
const KIND_TITLES := ["Тело", "Платформа", "Стена", "Блок", "Смерть", "Путь"]  # loc: dev — конструктор
const MIN_POINTS := [3, 2, 2, 4, 3, 2]

## Роли форм объектов (контур с parent_uid объекта и непустой role — не коллизия, а форма компонента).
const ROLE_TITLES := {"outline": "Рисуемый контур", "area": "Область закраски", "weak": "Уязвимое место",  # loc: dev — конструктор
	"form": "Форма", "zone": "Зона"}

@export var uid: String = ""
@export var kind: Kind = Kind.BODY
@export var points: PackedVector2Array = PackedVector2Array()
@export var closed: bool = true
@export var position: Vector2 = Vector2.ZERO
@export var parent_uid: String = ""
@export var material: Mat = Mat.NORMAL
@export var thickness: float = 12.0
@export var one_way: bool = true
@export var solid_angle_deg: float = 60.0
@export var visible_in_game: bool = false
@export var color: Color = Color(0.55, 0.85, 0.55)
## Форма объекта: "" — обычный контур коллизии; иначе роль (см. ROLE_TITLES) — контур принадлежит объекту
## parent_uid, в игре коллизия по нему не строится, его читает компонент объекта. Добавлено в фазе 2.
@export var role: String = ""


static func kind_is_closed(k: int) -> bool:
	return k == Kind.BODY or k == Kind.RECT or k == Kind.KILL


## Замкнут ли этот контур (у пути — по полю closed, у остальных — по виду).
func is_closed() -> bool:
	if kind == Kind.PATH:
		return closed
	return kind_is_closed(kind)


func is_role() -> bool:
	return role != ""


func min_points() -> int:
	if kind == Kind.PATH and closed:
		return 3
	return MIN_POINTS[kind]
