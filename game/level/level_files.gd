extends RefCounted
## Список ресурсов в папке res://. В экспортированной сборке .tres превращаются в «имя.tres.remap» —
## функции это учитывают, поэтому работают и в редакторе, и в сборке.

## Пути .tres/.res в папке (без подпапок).
static func resources_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var p := dir.path_join(name)
			if not out.has(p):
				out.append(p)
	out.sort()
	return out


static func subdirs(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	var d := DirAccess.get_directories_at(dir)
	d.sort()
	return d


## Все уровни: [{path, epoch, id}], без черновиков автосохранения.
static func all_levels() -> Array:
	var out := []
	for ep in subdirs(LevelData.LEVELS_DIR):
		if ep.begins_with("_"):
			continue
		for p in resources_in(LevelData.LEVELS_DIR.path_join(ep)):
			out.append({"path": p, "epoch": ep, "id": p.get_file().get_basename()})
	return out


## Картинки в папке (png/jpg/jpeg/webp), включая ещё не импортированные.
static func images_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := name.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp"]:
			var p := dir.path_join(name)
			if not out.has(p):
				out.append(p)
	out.sort()
	return out
