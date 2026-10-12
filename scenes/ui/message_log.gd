class_name MessageLog
extends PanelContainer
## Dziennik komunikatów: ostatnie wpisy z EventBus.message_logged, najnowszy na dole.

@export var max_lines: int = 3

var _lines: PackedStringArray = []

@onready var _label: Label = $Margin/Label


func _ready() -> void:
	EventBus.message_logged.connect(add_message)
	EventBus.run_started.connect(_on_run_started)
	_label.text = ""


func add_message(text: String) -> void:
	_lines.append(text)
	while _lines.size() > max_lines:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)


func _on_run_started(_run_seed: int) -> void:
	_lines.clear()
	_label.text = ""
