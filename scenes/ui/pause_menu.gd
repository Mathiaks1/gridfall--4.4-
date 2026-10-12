class_name PauseMenu
extends ModalScreen
## Menu pauzy: wznów, opcje, zapisz i wyjdź, porzuć run.

signal options_requested
signal save_quit_requested
signal abandon_requested


func _ready() -> void:
	super()
	title_label.text = UiText.t(&"pause_title")
	subtitle_label.hide()
	add_list_button(UiText.t(&"pause_resume"), close)
	add_list_button(UiText.t(&"pause_options"), options_requested.emit)
	add_list_button(UiText.t(&"pause_save_quit"), save_quit_requested.emit)
	add_list_button(UiText.t(&"pause_abandon"), abandon_requested.emit)
