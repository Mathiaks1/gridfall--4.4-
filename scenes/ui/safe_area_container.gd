class_name SafeAreaContainer
extends MarginContainer
## Marginesy uwzględniające safe area (notch, pasek gestów) na urządzeniach mobilnych.

@export var base_margin: int = 8


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_margins)
	_apply_margins()


func _apply_margins() -> void:
	var insets := _get_safe_insets()
	add_theme_constant_override("margin_left", base_margin + int(insets.position.x))
	add_theme_constant_override("margin_top", base_margin + int(insets.position.y))
	add_theme_constant_override("margin_right", base_margin + int(insets.size.x))
	add_theme_constant_override("margin_bottom", base_margin + int(insets.size.y))


## Zwraca wcięcia w jednostkach canvas: position = (lewo, góra), size = (prawo, dół).
func _get_safe_insets() -> Rect2:
	# Na PC safe area to obszar pulpitu, a nie okna — ignorujemy
	if not OS.has_feature("mobile"):
		return Rect2()
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Rect2()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	# Piksele ekranu → jednostki canvas (stretch mode canvas_items)
	var to_canvas := get_viewport_rect().size / window_size
	var left := maxf(safe.position.x, 0.0) * to_canvas.x
	var top := maxf(safe.position.y, 0.0) * to_canvas.y
	var right := maxf(window_size.x - safe.end.x, 0.0) * to_canvas.x
	var bottom := maxf(window_size.y - safe.end.y, 0.0) * to_canvas.y
	return Rect2(left, top, right, bottom)
