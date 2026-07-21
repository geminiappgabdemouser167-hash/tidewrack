extends CanvasLayer
## DialogueBox — renders DialogueManager output. Built entirely in code.
##
## Add one instance to a gameplay scene. It shows itself when a dialogue
## starts and hides when it finishes. Linear lines advance on ui_accept;
## choice nodes show a button per option.

const TEXT_SPEED := 45.0  # characters per second for the typewriter effect

var _root: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _choice_box: VBoxContainer
var _continue_hint: Label

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false
var _has_choices: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_root.hide()
	DialogueManager.dialogue_started.connect(_on_started)
	DialogueManager.line_shown.connect(_on_line)
	DialogueManager.dialogue_finished.connect(_on_finished)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -240
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	_root = PanelContainer.new()
	margin.add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_root.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.modulate = Color("#ffd466")
	vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.fit_content = true
	_text_label.bbcode_enabled = true
	_text_label.custom_minimum_size = Vector2(0, 96)
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	vbox.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_choice_box)

	_continue_hint = Label.new()
	_continue_hint.text = "▸ press Enter"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(_continue_hint)


func _on_started() -> void:
	_root.show()


func _on_line(speaker: String, text: String, choices: Array) -> void:
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_full_text = text
	_revealed = 0.0
	_typing = true
	_text_label.text = ""
	_has_choices = not choices.is_empty()
	_clear_choices()
	if _has_choices:
		_continue_hint.hide()
		for i in choices.size():
			var choice: Dictionary = choices[i]
			var button := Button.new()
			button.text = str(choice.get("text", "..."))
			button.disabled = true  # enabled once text finishes typing
			button.pressed.connect(_on_choice_pressed.bind(i))
			_choice_box.add_child(button)
	else:
		_continue_hint.show()


func _process(delta: float) -> void:
	if not _typing:
		return
	_revealed = min(_revealed + TEXT_SPEED * delta, float(_full_text.length()))
	_text_label.text = _full_text.substr(0, int(_revealed))
	if int(_revealed) >= _full_text.length():
		_typing = false
		_on_text_complete()


func _on_text_complete() -> void:
	if _has_choices:
		for child in _choice_box.get_children():
			(child as Button).disabled = false
		# Focus the first choice for keyboard/controller navigation.
		if _choice_box.get_child_count() > 0:
			(_choice_box.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not DialogueManager.is_active or _has_choices:
		return
	if event.is_action_pressed("ui_accept"):
		if _typing:
			# Fast-forward the typewriter on the first press.
			_revealed = float(_full_text.length())
			_text_label.text = _full_text
			_typing = false
			_on_text_complete()
		else:
			DialogueManager.advance()
		get_viewport().set_input_as_handled()


func _on_choice_pressed(index: int) -> void:
	DialogueManager.choose(index)


func _on_finished() -> void:
	_clear_choices()
	_root.hide()


func _clear_choices() -> void:
	for child in _choice_box.get_children():
		child.queue_free()
