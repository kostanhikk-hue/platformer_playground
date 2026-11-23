extends RefCounted
## Команды отмены и повтора. Каждое изменение уровня — команда с do_it() / undo_it().
##   PropsCmd  — поменять поля ресурса (снимок «до» и «после»);
##   ListCmd   — добавить или удалить элементы из списка уровня (backgrounds / shapes / objects);
##   Batch     — несколько команд как один шаг.
## UndoStack.push_done(cmd) — команда уже применена (например, после перетаскивания), просто запомнить;
## UndoStack.exec(cmd) — применить и запомнить. Команды с одинаковым merge_key, пришедшие подряд быстрее
## merge_time, склеиваются в один шаг (серия правок одного ползунка инспектора).


class Cmd:
	extends RefCounted
	var name := ""
	var merge_key := ""
	var time := 0.0

	func do_it() -> void:
		pass

	func undo_it() -> void:
		pass

	## Склеить с более поздней командой (у которой тот же merge_key).
	func merge(_later: Cmd) -> bool:
		return false

	static func copy_value(v: Variant) -> Variant:
		if v is Dictionary or v is Array:
			return v.duplicate(true)
		if typeof(v) >= TYPE_PACKED_BYTE_ARRAY and typeof(v) <= TYPE_PACKED_VECTOR4_ARRAY:
			return v.duplicate()   # Packed-массивы в Godot 4 передаются по ссылке
		return v


class PropsCmd:
	extends Cmd
	var target: Object
	var before: Dictionary
	var after: Dictionary

	func _init(t: Object, b: Dictionary, a: Dictionary, n: String = "Изменение") -> void:
		target = t
		before = b
		after = a
		name = n

	func do_it() -> void:
		for k in after:
			target.set(k, copy_value(after[k]))

	func undo_it() -> void:
		for k in before:
			target.set(k, copy_value(before[k]))

	func merge(later: Cmd) -> bool:
		if not (later is PropsCmd) or later.target != target:
			return false
		for k in later.after:
			after[k] = later.after[k]
			if not before.has(k):
				before[k] = later.before.get(k)
		return true


class ListCmd:
	extends Cmd
	var level: Resource
	var list_name: String
	var items: Array
	var adding: bool
	var _indices: Array = []

	func _init(lv: Resource, ln: String, its: Array, add: bool, n: String = "") -> void:
		level = lv
		list_name = ln
		items = its
		adding = add
		name = n if n != "" else ("Добавить" if add else "Удалить")

	func _add() -> void:
		var arr: Array = level.get(list_name)
		if _indices.is_empty():
			for it in items:
				arr.append(it)
		else:
			# вернуть на прежние места (по возрастанию индексов)
			var pairs := []
			for i in range(items.size()):
				pairs.append([_indices[i], items[i]])
			pairs.sort_custom(func(x, y): return x[0] < y[0])
			for pr in pairs:
				arr.insert(mini(pr[0], arr.size()), pr[1])

	func _remove() -> void:
		var arr: Array = level.get(list_name)
		_indices.clear()
		for it in items:
			_indices.append(arr.find(it))
		for it in items:
			arr.erase(it)

	func do_it() -> void:
		if adding:
			_add()
		else:
			_remove()

	func undo_it() -> void:
		if adding:
			_remove()
			_indices.clear()
		else:
			_add()


class Batch:
	extends Cmd
	var cmds: Array

	func _init(c: Array, n: String = "") -> void:
		cmds = c
		name = n

	func do_it() -> void:
		for c in cmds:
			c.do_it()

	func undo_it() -> void:
		for i in range(cmds.size() - 1, -1, -1):
			cmds[i].undo_it()

	func merge(later: Cmd) -> bool:
		if not (later is Batch) or later.cmds.size() != cmds.size():
			return false
		for i in range(cmds.size()):
			if not (cmds[i] is PropsCmd and later.cmds[i] is PropsCmd and cmds[i].target == later.cmds[i].target):
				return false
		for i in range(cmds.size()):
			cmds[i].merge(later.cmds[i])
		return true


## Снимок полей ресурса (с копией словарей и массивов, чтобы «до» не менялось вместе с ресурсом).
static func snap(r: Object, names: Array) -> Dictionary:
	var d := {}
	for n in names:
		d[n] = _copy(r.get(n))
	return d


static func _copy(v: Variant) -> Variant:
	return Cmd.copy_value(v)


## Команда из двух снимков; null, если ничего не поменялось.
static func props_from(r: Object, before: Dictionary, n: String = "Изменение") -> PropsCmd:
	var after := snap(r, before.keys())
	var same := true
	for k in before:
		if typeof(before[k]) != typeof(after[k]) or before[k] != after[k]:
			same = false
			break
	if same:
		return null
	return PropsCmd.new(r, before, after, n)


class UndoStack:
	extends RefCounted
	var done: Array = []
	var undone: Array = []
	var depth := 200
	var merge_time := 1.0
	## Вызывается после любого do/undo/redo.
	var on_change: Callable

	func exec(c: Cmd) -> void:
		c.do_it()
		push_done(c)

	func push_done(c: Cmd) -> void:
		if c == null:
			return
		var now := Time.get_ticks_msec() / 1000.0
		c.time = now
		undone.clear()
		if c.merge_key != "" and not done.is_empty():
			var last: Cmd = done[done.size() - 1]
			if last.merge_key == c.merge_key and now - last.time <= merge_time and last.merge(c):
				last.time = now
				_changed()
				return
		done.append(c)
		while done.size() > maxi(depth, 1):
			done.pop_front()
		_changed()

	func undo() -> bool:
		if done.is_empty():
			return false
		var c: Cmd = done.pop_back()
		c.undo_it()
		undone.append(c)
		_changed()
		return true

	func redo() -> bool:
		if undone.is_empty():
			return false
		var c: Cmd = undone.pop_back()
		c.do_it()
		c.time = 0.0   # не склеивать с тем, что придёт следом
		done.append(c)
		_changed()
		return true

	## Разорвать склейку: следующая команда точно будет отдельным шагом.
	func seal() -> void:
		if not done.is_empty():
			done[done.size() - 1].time = 0.0

	func clear() -> void:
		done.clear()
		undone.clear()

	func _changed() -> void:
		if on_change.is_valid():
			on_change.call()
