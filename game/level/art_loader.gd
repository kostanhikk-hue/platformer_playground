extends RefCounted
## Загрузка картинок уровня. В уровне хранится только путь.
## Уже импортированная Godot картинка — через load(); свежая (только что брошенная в конструктор) —
## через Image.load_from_file. Картинки больше MAX_TEXTURE по стороне режутся на куски при показе.

const MAX_TEXTURE := 4096   ## техническое ограничение размера текстуры (не влияет на ощущение)

static var _tex: Dictionary = {}
static var _img: Dictionary = {}


static func is_imported(path: String) -> bool:
	return ResourceLoader.exists(path)


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func forget(path: String) -> void:
	_tex.erase(path)
	_img.erase(path)


static func load_image(path: String) -> Image:
	if _img.has(path):
		return _img[path]
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null and ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			img = t.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	if img != null:
		_img[path] = img
	return img


static func load_texture(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			t = r
	if t == null:
		var img := load_image(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	if t != null:
		_tex[path] = t
	return t


static func image_size(path: String) -> Vector2:
	var t := load_texture(path)
	return t.get_size() if t != null else Vector2.ZERO


## Узел с картинкой. centered — центр в (0,0) (арт-объекты), иначе левый верхний угол (фоны).
## region — кадрирование в пикселях картинки (пустой — вся).
static func make_node(path: String, region: Rect2 = Rect2(), centered: bool = false) -> Node2D:
	var root := Node2D.new()
	var tex := load_texture(path)
	if tex == null:
		return root
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var r := full if not region.has_area() else region.intersection(full)
	var origin := -r.size * 0.5 if centered else Vector2.ZERO
	if r.size.x <= MAX_TEXTURE and r.size.y <= MAX_TEXTURE:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.position = origin
		if r != full:
			sp.region_enabled = true
			sp.region_rect = r
		root.add_child(sp)
		return root
	var img := load_image(path)
	if img == null:
		return root
	var y := 0.0
	while y < r.size.y:
		var x := 0.0
		var h := minf(MAX_TEXTURE, r.size.y - y)
		while x < r.size.x:
			var w := minf(MAX_TEXTURE, r.size.x - x)
			var piece := img.get_region(Rect2i(int(r.position.x + x), int(r.position.y + y), int(w), int(h)))
			var sp := Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(piece)
			sp.centered = false
			sp.position = origin + Vector2(x, y)
			root.add_child(sp)
			x += MAX_TEXTURE
		y += MAX_TEXTURE
	return root
