extends VBoxContainer
## Палитра объектов: категории (сворачиваются), поиск, фильтр по эпохе уровня (+ общие).
## Клик по объекту — затем клик в холсте; или перетащить объект в холст.

const Catalog := preload("res://game/level/catalog.gd")
const ArtLoader := preload("res://game/level/art_loader.gd")

var ed
var tree: Tree
var search: LineEdit
var all_epochs: CheckBox
var desc: Label
var _thumbs := {}


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = "ПАЛИТРА"
	t.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	add_child(t)
	search = LineEdit.new()
	search.placeholder_text = "поиск"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_s: String) -> void: rebuild())
	add_child(search)
	all_epochs = CheckBox.new()
	all_epochs.text = "все эпохи"
	all_epochs.tooltip_text = "Выключено — только эпоха уровня и общие объекты."
	all_epochs.focus_mode = Control.FOCUS_NONE
	all_epochs.toggled.connect(func(_on: bool) -> void: rebuild())
	add_child(all_epochs)
	tree = Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.focus_mode = Control.FOCUS_NONE
	tree.item_mouse_selected.connect(_on_pick)
	tree.set_drag_forwarding(_drag_data, Callable(), Callable())
	add_child(tree)
	desc = Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(100, 64)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	add_child(desc)
	tree.item_selected.connect(func() -> void:
		var it := tree.get_selected()
		if it != null and it.get_metadata(0) != null:
			_show_desc(Catalog.get_def(it.get_metadata(0))))
	tree.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var it := tree.get_item_at_position(ev.position)
			if it != null and it.get_metadata(0) != null:
				_show_desc(Catalog.get_def(it.get_metadata(0))))


func rebuild() -> void:
	if tree == null or ed == null or ed.level == null:
		return
	tree.clear()
	var root := tree.create_item()
	var cats := {}
	var filter := search.text.strip_edges().to_lower()
	var defs: Array = Catalog.all().values()
	defs.sort_custom(func(a, b): return a.title < b.title)
	# категории — в порядке ObjectDef.CATEGORIES, незнакомые — в конце
	var order: Array = ObjectDef.CATEGORIES.duplicate()
	for d in defs:
		if not order.has(d.category):
			order.append(d.category)
	var by_cat := {}
	for d in defs:
		if d.hidden:
			continue
		if not all_epochs.button_pressed and d.epoch != "common" and d.epoch != ed.level.epoch:
			continue
		if filter != "" and not (d.title.to_lower().contains(filter) or d.id.contains(filter) or d.description.to_lower().contains(filter) or d.category.to_lower().contains(filter)):
			continue
		if not by_cat.has(d.category):
			by_cat[d.category] = []
		by_cat[d.category].append(d)
	for cat in order:
		if not by_cat.has(cat):
			continue
		var c := tree.create_item(root)
		c.set_text(0, cat)
		c.set_selectable(0, false)
		c.set_custom_color(0, Color(1, 0.8, 0.35))
		cats[cat] = c
		# сначала обычные объекты, потом готовые наборы
		var list: Array = by_cat[cat]
		list.sort_custom(func(a, b): return (a.kit.is_empty() and not b.kit.is_empty()) or (a.kit.is_empty() == b.kit.is_empty() and a.title < b.title))
		for d in list:
			var it := tree.create_item(c)
			it.set_text(0, ("▣ " if not d.kit.is_empty() else "") + d.title)
			it.set_metadata(0, d.id)
			it.set_tooltip_text(0, "%s\n%s · %s" % [d.description if d.description != "" else d.title, d.id, d.epoch])
			var icon: Texture2D = d.icon
			if icon == null and d.image != "":
				icon = thumb(d.image)
			if icon == null:
				icon = _swatch(d.editor_color, not d.kit.is_empty())
			if icon != null:
				it.set_icon(0, icon)
				it.set_icon_max_width(0, 32)
	_show_desc(null)


## Цветной значок для объектов без картинки (у наборов — с рамкой).
func _swatch(col: Color, kit: bool) -> Texture2D:
	var key := "%s|%s" % [col.to_html(), kit]
	if _thumbs.has(key):
		return _thumbs[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 14):
		for x in range(2, 14):
			img.set_pixel(x, y, col)
	if kit:
		for i in range(16):
			for e in [0, 15]:
				img.set_pixel(i, e, Color.WHITE)
				img.set_pixel(e, i, Color.WHITE)
	var t := ImageTexture.create_from_image(img)
	_thumbs[key] = t
	return t


func _show_desc(d: ObjectDef) -> void:
	if desc == null:
		return
	if d == null:
		desc.text = "Клик — потом клик в холсте.\nИли перетащи в холст."
	else:
		desc.text = "%s\n%s" % [d.title, d.description if d.description != "" else d.id]


## Миниатюра картинки (для палитры и окна «Добавить картинку»).
func thumb(path: String) -> Texture2D:
	if _thumbs.has(path):
		return _thumbs[path]
	var img := ArtLoader.load_image(path)
	if img == null:
		return null
	var c := img.duplicate() as Image
	var s: float = float(ed.ep.thumb_size) / maxf(c.get_width(), c.get_height())
	c.resize(maxi(int(c.get_width() * s), 1), maxi(int(c.get_height() * s), 1), Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(c)
	_thumbs[path] = t
	return t


func _on_pick(_pos: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var it := tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	var d := Catalog.get_def(it.get_metadata(0))
	if d != null:
		ed.begin_place(d)
		ed.say("Поставить «%s»: клик в холсте (Shift — несколько)" % d.title)


func _drag_data(pos: Vector2) -> Variant:
	var it := tree.get_item_at_position(pos)
	if it == null or it.get_metadata(0) == null:
		return null
	var l := Label.new()
	l.text = it.get_text(0)
	tree.set_drag_preview(l)
	return {"def_id": it.get_metadata(0)}
