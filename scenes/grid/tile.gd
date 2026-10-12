class_name Tile
extends Control
## Widok pojedynczego pola. Tylko rysuje stan — bez logiki gry i bez obsługi wejścia.

const INSET := 1.0

var cell := Vector2i.ZERO
var skin: TileSkin

var _state: GridModel.CellState = GridModel.CellState.HIDDEN
var _content: GridModel.Content = GridModel.Content.EMPTY
var _danger: int = 0
var _exploded: bool = false
var _show_solution: bool = false
var _hold_progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(state: GridModel.CellState, content: GridModel.Content, danger: int, exploded: bool, show_solution: bool) -> void:
	_state = state
	_content = content
	_danger = danger
	_exploded = exploded
	_show_solution = show_solution
	queue_redraw()


func set_hold_progress(ratio: float) -> void:
	_hold_progress = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func _is_hazard() -> bool:
	return _content == GridModel.Content.TRAP or _content == GridModel.Content.MONSTER


func _draw() -> void:
	if skin == null:
		return
	var rect := Rect2(Vector2.ZERO, size).grow(-INSET)
	match _state:
		GridModel.CellState.HIDDEN:
			_draw_hidden(rect)
		GridModel.CellState.FLAGGED:
			_draw_hidden(rect)
			_draw_flag(rect)
			# Po porażce: flaga na bezpiecznym polu = błąd
			if _show_solution and not _is_hazard():
				_draw_cross(rect, skin.wrong_flag_color)
		GridModel.CellState.REVEALED:
			_draw_revealed(rect)
	if _hold_progress > 0.0:
		var h := rect.size.y * _hold_progress
		draw_rect(Rect2(rect.position.x, rect.end.y - h, rect.size.x, h), skin.hold_feedback_color)


func _draw_hidden(rect: Rect2) -> void:
	if skin.hidden_texture:
		draw_texture_rect(skin.hidden_texture, rect, false)
		return
	draw_rect(rect, skin.hidden_color)
	draw_rect(rect, skin.hidden_border_color, false, 1.0)


func _draw_revealed(rect: Rect2) -> void:
	if skin.revealed_texture:
		draw_texture_rect(skin.revealed_texture, rect, false)
	else:
		draw_rect(rect, skin.exploded_background_color if _exploded else skin.revealed_color)
		draw_rect(rect, skin.revealed_border_color, false, 1.0)
	if _is_hazard():
		_draw_hazard(rect)
	elif _danger > 0:
		_draw_number(rect, _danger)


func _draw_number(rect: Rect2, number: int) -> void:
	var tex := skin.get_number_texture(number)
	if tex:
		draw_texture_rect(tex, rect, false)
		return
	var font: Font = skin.font if skin.font else ThemeDB.fallback_font
	var font_size := maxi(int(rect.size.y * skin.font_size_ratio), 8)
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(rect.position.x, baseline), str(number), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, skin.get_number_color(number))


func _draw_hazard(rect: Rect2) -> void:
	if skin.hazard_texture:
		draw_texture_rect(skin.hazard_texture, rect, false)
		return
	# Placeholder: kolczasta kula
	var center := rect.get_center()
	var r := rect.size.x * 0.22
	var spike := rect.size.x * 0.34
	var w := maxf(rect.size.x * 0.06, 1.0)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(PI * 0.25 * i)
		draw_line(center - dir * spike, center + dir * spike, skin.hazard_color, w)
	draw_circle(center, r, skin.hazard_color)


func _draw_flag(rect: Rect2) -> void:
	if skin.flag_texture:
		draw_texture_rect(skin.flag_texture, rect, false)
		return
	# Placeholder: maszt + trójkątna flaga
	var s := rect.size.x
	var o := rect.position
	var w := maxf(s * 0.06, 1.0)
	var pole_x := o.x + s * 0.38
	draw_line(Vector2(pole_x, o.y + s * 0.2), Vector2(pole_x, o.y + s * 0.8), skin.flag_pole_color, w)
	draw_line(Vector2(o.x + s * 0.26, o.y + s * 0.8), Vector2(o.x + s * 0.62, o.y + s * 0.8), skin.flag_pole_color, w)
	var points := PackedVector2Array([
		Vector2(pole_x, o.y + s * 0.2),
		Vector2(o.x + s * 0.76, o.y + s * 0.34),
		Vector2(pole_x, o.y + s * 0.48),
	])
	draw_colored_polygon(points, skin.flag_color)


func _draw_cross(rect: Rect2, color: Color) -> void:
	var r := rect.grow(-rect.size.x * 0.18)
	var w := maxf(rect.size.x * 0.07, 1.0)
	draw_line(r.position, r.end, color, w)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), color, w)
