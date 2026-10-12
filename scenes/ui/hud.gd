class_name Hud
extends HBoxContainer
## Górny pasek: piętro, licznik zagrożeń, przełącznik trybu flagi (dotyk), restart.

signal restart_pressed

@onready var _floor_label: Label = $FloorLabel
@onready var _hazard_label: Label = $HazardLabel
@onready var _flag_mode_button: Button = $FlagModeButton
@onready var _restart_button: Button = $RestartButton


func _ready() -> void:
	_restart_button.text = UiText.t(&"hud_restart")
	_flag_mode_button.text = UiText.t(&"hud_flag_mode")
	_flag_mode_button.visible = DisplayServer.is_touchscreen_available()
	_flag_mode_button.toggled.connect(_on_flag_mode_toggled)
	_restart_button.pressed.connect(restart_pressed.emit)
	EventBus.flags_changed.connect(_on_flags_changed)


func set_floor(floor_number: int) -> void:
	_floor_label.text = UiText.t(&"hud_floor") % floor_number


func _on_flags_changed(placed: int, hazard_total: int) -> void:
	# Klasycznie: pozostałe = wszystkie zagrożenia − postawione flagi (może zejść poniżej zera)
	_hazard_label.text = UiText.t(&"hud_hazards") % [hazard_total - placed, hazard_total]


func _on_flag_mode_toggled(enabled: bool) -> void:
	EventBus.flag_mode_changed.emit(enabled)
