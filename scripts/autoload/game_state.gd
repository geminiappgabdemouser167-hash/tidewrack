extends Node
## GameState – global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and discovered journal entry IDs, persisting them to
## user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Ordered list of discovered journal entry IDs, e.g. ["edith_log_01"].
var journal_entries: Array[String] = []
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func add_journal_entry(entry_id: String) -> bool:
	if entry_id.is_empty() or journal_entries.has(entry_id):
		return false
	journal_entries.append(entry_id)
	state_changed.emit()
	return true


func has_journal_entry(entry_id: String) -> bool:
	return journal_entries.has(entry_id)


func get_journal_entries() -> Array[String]:
	return journal_entries.duplicate()


func new_game() -> void:
	flags.clear()
	journal_entries.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags.duplicate(),
		"journal_entries": journal_entries.duplicate(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	# Future-proofing: migrate older save versions here.
	var loaded_scene: Variant = data.get("scene", "res://scenes/game.tscn")
	current_scene = loaded_scene if typeof(loaded_scene) == TYPE_STRING else "res://scenes/game.tscn"
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags.duplicate() if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	journal_entries.clear()
	var loaded_entries: Variant = data.get("journal_entries", [])
	if typeof(loaded_entries) == TYPE_ARRAY:
		for entry in loaded_entries:
			if typeof(entry) == TYPE_STRING and not entry.is_empty() and not journal_entries.has(entry):
				journal_entries.append(entry)
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
