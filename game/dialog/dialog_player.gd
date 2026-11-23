extends CanvasLayer
## Реплики на ходу: титры внизу по центру + голос. Игра не останавливается. Создаёт уровень (level_runtime).
## Очередь — три правила: говорит один голос; say ждёт в очереди; bark и hint пропускаются, если кто-то говорит.
##   var req = dialog.say("goddess_cave_004")   → await req.finished (окончание реплики)
##   dialog.bark("goddess_on_death")            → null, если пропущено
## Параметры — вкладка «Титры» (data/subtitle_params.gd).
## Текст и имя — на текущем языке (Loc.line, Loc.speaker_name); при смене языка титр перестраивается на лету.
## Голос — Loc.voice_path: язык озвучки → ru → без голоса (титр по скорости чтения).

const Lines := preload("res://game/dialog/lines_db.gd")


class Req:
	extends RefCounted
	signal finished
	var id := ""
	var done := false

	func finish() -> void:
		if done:
			return
		done = true
		finished.emit.call_deferred()


var sp: Resource
var queue: Array = []
var current: Req = null
var _t := 0.0
var _gap := 0.0
var _bags := {}          ## набор барков → оставшиеся id (без повторов)
var _last_bark := {}
var audio: AudioStreamPlayer
var _panel: PanelContainer
var _name: Label
var _text: Label
var _box: VBoxContainer
var _alpha := 0.0


func _ready() -> void:
	layer = 55
	sp = Params.get_res("subtitle")
	audio = AudioStreamPlayer.new()
	add_child(audio)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_panel.add_child(_box)
	_name = Label.new()
	_box.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_text)
	_panel.modulate.a = 0.0
	# в титрах — готовый текст реплики, а не ключ: автоперевод Godot здесь не нужен
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	Loc.locale_changed.connect(_on_locale_changed)


## Кто-то говорит или ждёт очереди.
func busy() -> bool:
	return current != null or not queue.is_empty()


func say(id: String) -> Req:
	var r := Req.new()
	r.id = id
	if not Lines.has_line(id):
		push_warning("Реплики нет в content/dialog/lines.csv: " + id)
		Events.log_line("dialog", "нет реплики «%s»" % id)
		r.finish()
		return r
	queue.append(r)
	return r


## Случайная реплика из набора без повторов; null — пропущено (кто-то говорит или набора нет).
func bark(set_name: String) -> Req:
	if busy():
		Events.log_line("dialog", "bark %s пропущен — говорят" % set_name)
		return null
	var ids: Array = Lines.set_lines(set_name)
	if ids.is_empty():
		push_warning("Нет набора реплик: " + set_name)
		return null
	var bag: Array = _bags.get(set_name, [])
	if bag.is_empty():
		bag = ids.duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag[0] == _last_bark.get(set_name, ""):
			bag.push_back(bag.pop_front())
	var id: String = bag.pop_front()
	_bags[set_name] = bag
	_last_bark[set_name] = id
	return say(id)


## Реплика набора по номеру (лестница подсказок; номер ведёт сценарий). null — пропущено.
func hint_line(set_name: String, index: int) -> Req:
	if busy():
		Events.log_line("dialog", "hint %s пропущен — говорят" % set_name)
		return null
	var ids: Array = Lines.set_lines(set_name)
	if ids.is_empty():
		push_warning("Нет набора реплик: " + set_name)
		return null
	return say(ids[clampi(index, 0, ids.size() - 1)])


## Прервать всё (смерть героя, выход из уровня): текущая и очередь заканчиваются сразу.
func stop_all() -> void:
	audio.stop()
	if current != null:
		current.finish()
	for r in queue:
		r.finish()
	queue.clear()
	current = null
	_t = 0.0
	_gap = 0.0


func _process(delta: float) -> void:
	var want := 1.0 if current != null else 0.0
	_alpha = move_toward(_alpha, want, delta / maxf(sp.fade_time, 0.001))
	_panel.modulate.a = _alpha
	if current != null:
		# высота титра с переносами известна только после отрисовки текста — подгоняем, если изменилась
		if not is_equal_approx(_panel.size.y, _panel.get_combined_minimum_size().y):
			_layout()
		_t -= delta
		if _t <= 0.0:
			current.finish()
			current = null
			_gap = sp.gap
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if not queue.is_empty():
		_start(queue.pop_front())


func _start(r: Req) -> void:
	current = r
	var l := Lines.get_line(r.id)
	var speaker: String = l.get("speaker", "")
	var text := Loc.line(r.id)
	_name.visible = sp.show_names and speaker != ""
	_name.text = Loc.speaker_name(speaker)
	var col: Color = sp.other_color
	if speaker == "goddess":
		col = sp.goddess_color
	elif speaker == "hero":
		col = sp.hero_color
	_name.add_theme_color_override("font_color", col)
	_name.add_theme_font_size_override("font_size", sp.name_size)
	_text.text = text
	_text.add_theme_font_size_override("font_size", sp.font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, sp.bg_alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	_text.custom_minimum_size = Vector2(sp.max_width - 20.0, 0)
	_layout.call_deferred()
	var dur: float = maxf(text.length() / maxf(sp.reading_speed, 0.1), sp.min_time)
	var stream := Lines.load_voice(Lines.voice_path(r.id))
	if stream != null:
		audio.stream = stream
		audio.volume_db = sp.voice_db
		audio.play()
		dur = stream.get_length() + sp.tail_time
	_t = dur
	Events.log_line("dialog", "%s: «%s»%s" % [r.id, text.left(40), "" if stream != null else " (без голоса)"])


## Язык сменился посреди реплики — тот же титр на новом языке (длительность прежняя).
func _on_locale_changed() -> void:
	if current == null:
		return
	_name.text = Loc.speaker_name(Lines.speaker_of(current.id))
	_text.text = Loc.line(current.id)
	_layout.call_deferred()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.reset_size()
	var w: float = minf(sp.max_width, vp.x - 40.0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.position = Vector2((vp.x - _panel.size.x) * 0.5, vp.y - sp.bottom_margin - _panel.size.y)


func current_text() -> String:
	return _text.text if current != null else ""
