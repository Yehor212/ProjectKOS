@tool
extends EditorScript

## Примусове налаштування імпорт-параметрів за шляхом.
## Фони: VRAM + mipmaps. Брендинг/іконки: Lossless. Спрайти: VRAM без mipmaps.
## Запуск: Editor → File → Run EditorScript → enforce_imports.gd

const RULES: Array[Dictionary] = [
	{"path": "res://assets/backgrounds/", "compress_mode": 2, "mipmaps": true},
	{"path": "res://assets/sprites/", "compress_mode": 2, "mipmaps": false},
	{"path": "res://assets/icons/", "compress_mode": 0, "mipmaps": false},
	{"path": "res://assets/branding/", "compress_mode": 0, "mipmaps": false},
	{"path": "res://assets/textures/ui/", "compress_mode": 0, "mipmaps": false},
]


func _run() -> void:
	print("=== Import Settings Enforcer ===")
	var count: int = 0
	var changed: int = 0
	for rule: Dictionary in RULES:
		var dir_path: String = rule["path"]
		var compress_mode: int = rule["compress_mode"]
		var mipmaps: bool = rule["mipmaps"]
		var dir: DirAccess = DirAccess.open(dir_path)
		if not dir:
			print("  SKIP: %s (not found)" % dir_path)
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				var import_path: String = dir_path + file_name + ".import"
				if FileAccess.file_exists(import_path):
					var updated: bool = _update_import(import_path, compress_mode, mipmaps)
					count += 1
					if updated:
						changed += 1
			file_name = dir.get_next()
		dir.list_dir_end()
	print("=== Done: %d files checked, %d updated ===" % [count, changed])
	if changed > 0:
		print("NOTE: Reimport assets via Editor → Project → Reimport All to apply.")


func _update_import(path: String, compress_mode: int, mipmaps: bool) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content: String = file.get_as_text()
	file.close()
	var original: String = content

	## Замінити compress/mode
	var mode_regex: RegEx = RegEx.new()
	mode_regex.compile("compress/mode=\\d+")
	content = mode_regex.sub(content, "compress/mode=%d" % compress_mode, true)

	## Замінити mipmaps/generate
	var mip_regex: RegEx = RegEx.new()
	mip_regex.compile("mipmaps/generate=\\w+")
	content = mip_regex.sub(content, "mipmaps/generate=%s" % str(mipmaps).to_lower(), true)

	if content == original:
		return false

	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out:
		out.store_string(content)
		out.close()
		print("  UPDATED: %s (mode=%d, mipmaps=%s)" % [path, compress_mode, mipmaps])
		return true
	return false
