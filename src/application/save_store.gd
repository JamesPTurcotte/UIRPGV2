class_name SaveStore
extends RefCounted

## Atomic-ish JSON save with a backup slot. The shape mirrors the SQLite schema
## in the spec; this is the documented shortcut until the SQLite adapter lands.

const SAVE_VERSION := 2

## v2 renames folio_mode/content ids to pack_mode/pack.*; Session._load_doc
## migrates v1 documents in place on load.

var prefix: String = "user://"

func save_path() -> String:
	return prefix + "save.json"

func backup_path() -> String:
	return prefix + "save.bak.json"

func temp_path() -> String:
	return prefix + "save.tmp"

func has_save() -> bool:
	return FileAccess.file_exists(save_path()) or FileAccess.file_exists(backup_path())

func load_save() -> Dictionary:
	var primary := _read_json(save_path())
	if not primary.is_empty():
		return primary
	var backup := _read_json(backup_path())
	if not backup.is_empty():
		push_warning("SaveStore: primary save unreadable; loaded backup.")
		return backup
	return {}

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_warning("SaveStore: could not parse %s" % path)
		return {}
	var doc: Dictionary = parsed
	var version := int(doc.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		push_warning("SaveStore: unsupported save version %d at %s" % [version, path])
		return {}
	return doc

func write_save(doc: Dictionary) -> bool:
	var payload := doc.duplicate(true)
	payload["version"] = SAVE_VERSION
	var text := JSON.stringify(payload, "\t")
	if not _write_file(temp_path(), text):
		return false
	# Rotate the current save to backup, then move the temp file into place.
	if FileAccess.file_exists(save_path()):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		var rotate_error := DirAccess.rename_absolute(save_path(), backup_path())
		if rotate_error != OK:
			push_warning("SaveStore: could not rotate save to backup (%d)" % rotate_error)
	var rename_error := DirAccess.rename_absolute(temp_path(), save_path())
	if rename_error != OK:
		push_error("SaveStore: could not commit save (%d)" % rename_error)
		return false
	return true

func _write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveStore: cannot open %s for writing" % path)
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true

func delete_save() -> void:
	for path in [save_path(), backup_path(), temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
