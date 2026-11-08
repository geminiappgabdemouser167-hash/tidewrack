extends Node
## GameState – global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and discovered journal entry IDs, persisting them to
## user://save.json so "Continue" works.

signal state_changed
signal journal_reset
signal journal_changed(entries: Array[String])

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
	var clean_id := entry_id.strip_edges()
	if clean_id.is_empty() or journal_entries.has(clean_id):
		return false
	journal_entries.append(clean_id)
	journal_changed.emit(get_journal_entries())
	state_changed.emit()
	return true


func has_journal_entry(entry_id: String) -> bool:
	return journal_entries.has(entry_id.strip_edges())


func get_journal_entries() -> Array[String]:
	return journal_entries.duplicate()


## Clears all in-memory journal entry IDs cleanly.
func reset_journal(notify: bool = true) -> void:
	journal_entries.clear()
	if notify:
		journal_reset.emit()
		journal_changed.emit(get_journal_entries())
		state_changed.emit()


## Replaces in-memory journal entry IDs cleanly from a loaded value instead of appending.
## Malformed outer types or broken inner elements warn and fall back safely without failing load.
func restore_journal(entries: Variant, notify: bool = true) -> void:
	journal_entries.clear()
	if entries == null:
		push_warning("GameState: journal_entries is null; defaulting to empty journal.")
	elif typeof(entries) != TYPE_ARRAY:
		push_warning(
			"GameState: malformed journal_entries (expected Array, got %s); defaulting to empty journal."
			% type_string(typeof(entries))
		)
	else:
		var raw_list: Array = entries
		for entry in raw_list:
			if typeof(entry) != TYPE_STRING:
				push_warning(
					"GameState: skipping malformed journal entry (expected String, got %s)."
					% type_string(typeof(entry))
				)
				continue
			var clean_id: String = (entry as String).strip_edges()
			if clean_id.is_empty():
				push_warning("GameState: skipping empty journal entry ID.")
				continue
			if not journal_entries.has(clean_id):
				journal_entries.append(clean_id)
	if notify:
		journal_changed.emit(get_journal_entries())
		state_changed.emit()


func new_game() -> void:
	flags.clear()
	current_scene = "res://scenes/game.tscn"
	reset_journal()


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
	if data.has("journal_entries"):
		restore_journal(data["journal_entries"], false)
	else:
		reset_journal(false)
	journal_changed.emit(get_journal_entries())
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
