class_name ObjectDef
extends Resource
## Запись каталога (catalog/<эпоха>/<id>.tres): что можно поставить на уровень.
## Арт-объект из палитры дополнительно хранит картинку и свои контуры (shapes, в координатах объекта).

## Категории палитры — в этом порядке.
const CATEGORIES := ["Рисуемое", "Интерактив", "Платформы", "Свет", "Враги", "Подборы", "Геометрия",  # loc: dev — палитра конструктора
	"Арт-объекты", "Декор", "Атмосфера", "Служебное"]

@export var id: String = ""
@export var title: String = ""
@export var category: String = ""
@export var epoch: String = "common"
@export var scene: PackedScene
## Иконка палитры. Пусто — уменьшенная картинка объекта (или цветной значок).
@export var icon: Texture2D
## Одна строка — показывается при наведении в палитре.
@export var description: String = ""
## Скрипт ресурса свойств экземпляра (по нему строится инспектор). null — свойств нет.
@export var props_script: Script
## Значения свойств по умолчанию для новых экземпляров (поверх значений скрипта props_script).
## Пишется кнопкой «Сохранить как значения каталога» в инспекторе.
@export var default_props: Dictionary = {}
## Метки: interactive, paintable, light_source, activatable, enemy, link_source, path_user…
@export var tags: PackedStringArray = PackedStringArray()
## Вид компонента (для конструктора: как рисовать и проверять). Пусто — объект v1.
@export var kind: String = ""
## Приставка uid новых экземпляров (зоны — t_1, метки — m_1). Пусто — id записи.
@export var uid_prefix: String = ""
## Ставить на пол: при постановке объект опускается до ближайшего пола под курсором.
@export var snap_to_floor: bool = false
## Готовый набор: несколько объектов со связями. [{key, def_id, offset: Vector2, props: {}}].
## В props строка "@key" (или элемент массива targets) заменяется на uid объекта набора с этим key.
@export var kit: Array = []
## Вид в конструкторе: цвет и размер рамки (px), слой по умолчанию.
@export var editor_color: Color = Color(0.8, 0.8, 0.8)
@export var editor_size: Vector2 = Vector2(32, 32)
@export var default_layer: int = 3
## Только один на уровень (старт героя).
@export var unique: bool = false
## Можно поворачивать, масштабировать и отражать (арт-объекты).
@export var transformable: bool = false
## Не показывать в палитре (служебная запись, например «картинка» для арт-объектов из файла).
@export var hidden: bool = false
## Для арт-объектов: картинка и привязанные контуры. Для компонентов — формы по умолчанию
## (контуры с role: рисуемый контур, область закраски, форма платформы), в координатах объекта.
@export var image: String = ""
@export var shapes: Array[GeoShape] = []


func has_tag(t: String) -> bool:
	return tags.has(t)
