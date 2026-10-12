class_name ModalScreen
extends Control
## Baza ekranów modalnych (walka, sklep, kowal, ekwipunek, awans, pauza, opcje).
## Wspólny szkielet sceny: Dim + panel z %Title, %Subtitle, przewijaną listą %List i stopką %Footer.
## Przyciemnienie (Dim) blokuje kliknięcia w planszę pod spodem.

signal closed

## Czy Esc / przycisk Wstecz zamyka ekran.
@export var closable: bool = true

const ROW_BUTTON_SIZE := Vector2(130, 48)
const SECTION_COLOR := Color(0.95, 0.78, 0.35)
const MUTED_COLOR := Color(0.7, 0.72, 0.8)

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var list: VBoxContainer = %List
@onready var footer: HBoxContainer = %Footer


func _ready() -> void:
	hide()


func open_modal() -> void:
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and closable and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Budowanie zawartości ------------------------------------------------------

func clear_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func clear_footer() -> void:
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()


func add_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", SECTION_COLOR)
	list.add_child(label)
	return label


func add_text(text: String, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted:
		label.add_theme_color_override(&"font_color", MUTED_COLOR)
	list.add_child(label)
	return label


## Wiersz: opis po lewej, przycisk po prawej.
func add_row(text: String, button_text: String, callback: Callable, enabled: bool = true) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := make_button(button_text, callback)
	button.disabled = not enabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	list.add_child(row)
	return button


## Duży przycisk na całą szerokość listy (menu).
func add_list_button(text: String, callback: Callable) -> Button:
	var button := make_button(text, callback)
	button.custom_minimum_size = Vector2(0, 56)
	list.add_child(button)
	return button


func add_footer_button(text: String, callback: Callable) -> Button:
	var button := make_button(text, callback)
	footer.add_child(button)
	return button


func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ROW_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button
