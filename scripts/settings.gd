extends Control
## Settings — volume + fullscreen overlay. Instantiated on top of any scene.

var _volume_slider: HSlider


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


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
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# Master volume
	var vol_label := Label.new()
	vol_label.text = "Master Volume"
	vbox.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = _current_volume_linear()
	_volume_slider.value_changed.connect(_on_volume_changed)
	vbox.add_child(_volume_slider)

	# Fullscreen
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fullscreen_check)

	var close_button := Button.new()
	close_button.text = "Back"
	close_button.pressed.connect(_close)
	vbox.add_child(close_button)

	close_button.grab_focus()


func _current_volume_linear() -> float:
	var bus := AudioServer.get_bus_index("Master")
	return db_to_linear(AudioServer.get_bus_volume_db(bus))


func _on_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	queue_free()
