class_name OptionsScreen
extends ModalScreen
## Opcje: głośność, pełny ekran (PC), wibracje i czas przytrzymania (dotyk). Zapis do GameSettings.

var _volume_label: Label
var _long_press_label: Label


func _ready() -> void:
	super()
	title_label.text = UiText.t(&"options_title")
	subtitle_label.hide()
	add_footer_button(UiText.t(&"common_close"), close)
	closed.connect(func() -> void: GameSettings.save_settings())


func open_options() -> void:
	GameSettings.ensure_loaded()
	_build()
	open_modal()


func _build() -> void:
	clear_list()
	_volume_label = add_text("")
	var volume := _add_slider(0.0, 1.0, 0.05, GameSettings.master_volume, _on_volume_changed)
	_on_volume_changed(volume.value)

	if not OS.has_feature("mobile"):
		_add_check(UiText.t(&"options_fullscreen"), GameSettings.fullscreen, _on_fullscreen_toggled)

	_add_check(UiText.t(&"options_vibration"), GameSettings.vibration, _on_vibration_toggled)
	_long_press_label = add_text("")
	var long_press := _add_slider(0.2, 0.8, 0.05, GameSettings.long_press_time, _on_long_press_changed)
	_on_long_press_changed(long_press.value)


func _add_slider(min_value: float, max_value: float, step: float, value: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 40)
	slider.value_changed.connect(callback)
	list.add_child(slider)
	return slider


func _add_check(text: String, pressed: bool, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = pressed
	check.custom_minimum_size = Vector2(0, 48)
	check.toggled.connect(callback)
	list.add_child(check)
	return check


func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	_volume_label.text = UiText.t(&"options_volume") % roundi(value * 100.0)
	GameSettings.apply()


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.fullscreen = enabled
	GameSettings.apply()


func _on_vibration_toggled(enabled: bool) -> void:
	GameSettings.vibration = enabled


func _on_long_press_changed(value: float) -> void:
	GameSettings.long_press_time = value
	_long_press_label.text = UiText.t(&"options_long_press") % value
