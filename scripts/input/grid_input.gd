class_name GridInput
extends Node
## Warstwa wejścia: zamienia surowe zdarzenia myszy i dotyku na abstrakcyjne akcje siatki.
## PC: LPM = odkryj (na odkrytej liczbie = chording), PPM = flaga.
## Dotyk: tap = odkryj, przytrzymanie = flaga (z paskiem postępu). Tryb flagi zamienia te role.

enum Action { REVEAL, FLAG }

signal action_triggered(action: Action, cell: Vector2i)
## ratio 0..1; 0 = koniec/anulowanie podglądu przytrzymania.
signal hold_progress_changed(cell: Vector2i, ratio: float)

@export var long_press_time: float = 0.4
## Opóźnienie, po którym zaczyna się wizualny feedback przytrzymania (żeby zwykły tap nie migał).
@export var hold_feedback_delay: float = 0.08
@export var drag_cancel_distance: float = 16.0
@export var vibrate_on_long_press: bool = true
## Do testów sterowania dotykowego myszą na PC.
@export var force_touch_mode: bool = false

var flag_mode: bool = false
## Funkcja (local_pos: Vector2) -> Vector2i; zwraca GridModel.INVALID_CELL poza siatką.
var cell_resolver: Callable

var _pressing: bool = false
var _press_is_touch: bool = false
var _press_pos := Vector2.ZERO
var _press_cell := GridModel.INVALID_CELL
var _press_time: float = 0.0
var _long_press_fired: bool = false


func _ready() -> void:
	set_process(false)
	EventBus.flag_mode_changed.connect(_on_flag_mode_changed)


## Wywoływane przez GridManager z _gui_input (pozycje lokalne). Zwraca true, gdy zdarzenie obsłużone.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _is_touch(mb):
			return _handle_touch_button(mb)
		return _handle_mouse_button(mb)
	if event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_press_pos) > drag_cancel_distance:
			cancel()
		return true
	return false


## Przerywa trwające naciśnięcie (np. przy restarcie lub końcu gry).
func cancel() -> void:
	if _pressing:
		hold_progress_changed.emit(_press_cell, 0.0)
	_pressing = false
	_long_press_fired = false
	set_process(false)


func _process(delta: float) -> void:
	if not _pressing or _long_press_fired:
		set_process(false)
		return
	_press_time += delta
	if _press_time >= hold_feedback_delay:
		var ratio := clampf((_press_time - hold_feedback_delay) / maxf(long_press_time - hold_feedback_delay, 0.001), 0.0, 1.0)
		hold_progress_changed.emit(_press_cell, ratio)
	if _press_time >= long_press_time:
		_long_press_fired = true
		hold_progress_changed.emit(_press_cell, 0.0)
		if vibrate_on_long_press:
			Input.vibrate_handheld(30)
		action_triggered.emit(Action.REVEAL if flag_mode else Action.FLAG, _press_cell)
		set_process(false)


func _is_touch(mb: InputEventMouseButton) -> bool:
	# Dotyk na Androidzie dociera jako emulowana mysz z device == DEVICE_ID_EMULATION
	return force_touch_mode or mb.device == InputEvent.DEVICE_ID_EMULATION


func _handle_mouse_button(mb: InputEventMouseButton) -> bool:
	match mb.button_index:
		MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				cancel()
				var cell := _resolve(mb.position)
				if cell != GridModel.INVALID_CELL:
					action_triggered.emit(Action.FLAG, cell)
			return true
		MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position, false)
			else:
				_end_press(mb.position)
			return true
	return false


func _handle_touch_button(mb: InputEventMouseButton) -> bool:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mb.pressed:
		_begin_press(mb.position, true)
	else:
		_end_press(mb.position)
	return true


func _begin_press(pos: Vector2, is_touch: bool) -> void:
	cancel()
	var cell := _resolve(pos)
	if cell == GridModel.INVALID_CELL:
		return
	_pressing = true
	_press_is_touch = is_touch
	_press_pos = pos
	_press_cell = cell
	_press_time = 0.0
	_long_press_fired = false
	set_process(is_touch)


func _end_press(pos: Vector2) -> void:
	if not _pressing:
		return
	var was_long := _long_press_fired
	var start_cell := _press_cell
	cancel()
	# Długie przytrzymanie już wykonało akcję — puszczenie palca nic nie robi
	if was_long or _resolve(pos) != start_cell:
		return
	action_triggered.emit(Action.FLAG if flag_mode else Action.REVEAL, start_cell)


func _resolve(pos: Vector2) -> Vector2i:
	if not cell_resolver.is_valid():
		return GridModel.INVALID_CELL
	var cell: Vector2i = cell_resolver.call(pos)
	return cell


func _on_flag_mode_changed(enabled: bool) -> void:
	flag_mode = enabled
