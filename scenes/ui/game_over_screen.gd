class_name GameOverScreen
extends Control
## Nakładka końca gry ze statystykami runu i przyciskiem ponownej gry.

signal restart_requested

@onready var _title_label: Label = %TitleLabel
@onready var _info_label: Label = %InfoLabel
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	hide()
	_restart_button.text = UiText.t(&"result_restart")
	_restart_button.pressed.connect(restart_requested.emit)


func show_game_over(info: String) -> void:
	_title_label.text = UiText.t(&"result_lost")
	_info_label.text = info
	show()
	_restart_button.grab_focus()
