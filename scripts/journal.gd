extends Control
class_name Journal
## Journal – tracks and displays discovered log entry IDs. Built in code.
##
## Use `add_entry()` during play, `reset()` on New Game, and `restore()` on
## Continue/load so in-memory entries replace cleanly instead of piling up.

signal entries_changed(entries: Array[String])

var entries: Array[String] = []
var _list_box: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("get_journal_entries"):
			restore(gs.call("get_journal_entries"))
		if gs.has_signal("journal_changed"):
			gs.connect("journal_changed", _on_game_state_journal_changed)


func add_entry(entry_id: String) -> bool:
	if entry_id.is_empty() or entries.has(entry_id):
		return false
	entries.append(entry_id)
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("add_journal_entry"):
		gs.call("add_journal_entry", entry_id)
	_refresh_ui()
	entries_changed.emit(get_entries())
	return true


func has_entry(entry_id: String) -> bool:
	return entries.has(entry_id)


func get_entries() -> Array[String]:
	return entries.duplicate()


## Clears all in-memory journal entries cleanly.
func reset() -> void:
	entries.clear()
	_refresh_ui()
	entries_changed.emit(get_entries())


## Replaces in-memory journal entries cleanly from a saved/loaded list
## instead of appending onto prior session state.
func restore(saved_entries: Variant) -> void:
	entries.clear()
	if typeof(saved_entries) == TYPE_ARRAY:
		for entry in saved_entries:
			if typeof(entry) == TYPE_STRING and not entry.is_empty() and not entries.has(entry):
				entries.append(entry)
	_refresh_ui()
	entries_changed.emit(get_entries())


func _on_game_state_journal_changed(state_entries: Array[String]) -> void:
	if entries == state_entries:
		return
	if state_entries.is_empty():
		reset()
	else:
		restore(state_entries)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(460, 320)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Keeper's Journal"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color("#ffd466")
	vbox.add_child(title)

	_empty_label = Label.new()
	_empty_label.text = "No log entries recorded yet."
	_empty_label.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(_empty_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

	var close_button := Button.new()
	close_button.text = "Back"
	close_button.pressed.connect(queue_free)
	vbox.add_child(close_button)

	_refresh_ui()
	close_button.grab_focus()


func _refresh_ui() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		child.queue_free()
	if _empty_label != null:
		_empty_label.visible = entries.is_empty()
	for entry_id in entries:
		var item := Label.new()
		item.text = "• %s" % entry_id
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_box.add_child(item)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
