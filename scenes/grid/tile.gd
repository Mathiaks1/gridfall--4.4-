class_name Tile
extends Control
## Widok pojedynczego pola. Tylko rysuje stan — bez logiki gry i bez obsługi wejścia.

const INSET := 1.0

var cell := Vector2i.ZERO
var skin: TileSkin

var _state: GridModel.CellState = GridModel.CellState.HIDDEN
var _content: GridModel.Content = GridModel.Content.EMPTY
var _danger: int = 0
var _resolved: bool = false
var _highlight: bool = false
var _show_solution: bool = false
var _hold_progress: float = 0.0
## Ikona zależna od pola (konkretny potwór / surowiec); null = ikona ogólna ze skina.
var _icon: Texture2D
## Animacja odkrycia: bieżąca klatka (-1 = brak) i czas.
var _reveal_frame: int = -1
var _reveal_time: float = 0.0
## Pierwsze set_view (nowa plansza / wczytany zapis) nie animuje.
var _has_view: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_icon(icon: Texture2D) -> void:
	if _icon != icon:
		_icon = icon
		queue_redraw()


## highlight = ostatnio uruchomione zagrożenie (czerwone tło).
func set_view(state: GridModel.CellState, content: GridModel.Content, danger: int, resolved: bool, highlight: bool, show_solution: bool) -> void:
	if _has_view and state == GridModel.CellState.REVEALED and _state != GridModel.CellState.REVEALED and skin and skin.reveal_animation:
		_reveal_frame = 0
		_reveal_time = 0.0
		set_process(true)
	_has_view = true
	_state = state
	_content = content
	_danger = danger
	_resolved = resolved
	_highlight = highlight
	_show_solution = show_solution
	queue_redraw()


func set_hold_progress(ratio: float) -> void:
	_hold_progress = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_reveal_time += delta
	var frame := int(_reveal_time * skin.reveal_fps)
	if frame >= skin.reveal_frames:
		_reveal_frame = -1
		set_process(false)
	else:
		_reveal_frame = frame
	queue_redraw()


func _is_hazard() -> bool:
	return _content == GridModel.Content.TRAP or _content == GridModel.Content.MONSTER


func _draw() -> void:
	if skin == null:
		return
	# Grafika pikselowa wypełnia całe pole (rozmiar pola = wielokrotność rozmiaru sprite'a);
	# odstęp INSET tylko dla placeholderów rysowanych prymitywami.
	var rect := Rect2(Vector2.ZERO, size)
	if skin.hidden_texture == null:
		rect = rect.grow(-INSET)
	match _state:
		GridModel.CellState.HIDDEN:
			_draw_hidden(rect)
		GridModel.CellState.FLAGGED:
			_draw_hidden(rect)
			_draw_flag(rect)
			# Po porażce: flaga na bezpiecznym polu = błąd
			if _show_solution and not _is_hazard():
				if skin.wrong_flag_texture:
					draw_texture_rect(skin.wrong_flag_texture, rect, false)
				else:
					_draw_cross(rect, skin.wrong_flag_color)
		GridModel.CellState.REVEALED:
			if _reveal_frame >= 0:
				_draw_reveal_frame(rect)
			else:
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


func _draw_reveal_frame(rect: Rect2) -> void:
	var tex := skin.reveal_animation
	var w := tex.get_width() / skin.reveal_frames
	draw_texture_rect_region(tex, rect, Rect2(w * _reveal_frame, 0, w, tex.get_height()))


func _draw_revealed(rect: Rect2) -> void:
	if _highlight and skin.revealed_danger_texture:
		draw_texture_rect(skin.revealed_danger_texture, rect, false)
	elif skin.revealed_texture:
		draw_texture_rect(skin.revealed_texture, rect, false)
	else:
		draw_rect(rect, skin.exploded_background_color if _highlight else skin.revealed_color)
		draw_rect(rect, skin.revealed_border_color, false, 1.0)
	var alpha := skin.resolved_alpha if _resolved else 1.0
	match _content:
		GridModel.Content.TRAP:
			_draw_trap(rect, alpha)
		GridModel.Content.MONSTER:
			_draw_monster(rect, alpha)
		GridModel.Content.TREASURE:
			_draw_treasure(rect, alpha)
			_draw_corner_number(rect)
		GridModel.Content.EXIT:
			_draw_exit(rect)
			_draw_corner_number(rect)
		GridModel.Content.SHOP:
			_draw_shop(rect)
			_draw_corner_number(rect)
		GridModel.Content.BLACKSMITH:
			_draw_blacksmith(rect)
			_draw_corner_number(rect)
		GridModel.Content.RESOURCE:
			_draw_resource(rect, alpha)
			_draw_corner_number(rect)
		_:
			if _danger > 0:
				_draw_number(rect, _danger)


func _draw_number(rect: Rect2, number: int) -> void:
	var tex := skin.get_number_texture(number)
	if tex:
		draw_texture_rect(tex, rect, false)
		return
	_draw_text_centered(rect, str(number), skin.font_size_ratio, skin.get_number_color(number))


## Pola specjalne też mają sąsiadów-zagrożenia — pokazujemy liczbę w rogu, żeby nie tracić informacji.
func _draw_corner_number(rect: Rect2) -> void:
	if _danger <= 0:
		return
	var tex := skin.get_small_number_texture(_danger)
	if tex:
		draw_texture_rect(tex, rect, false)
		return
	var corner := Rect2(rect.end - rect.size * 0.42, rect.size * 0.42)
	_draw_text_centered(corner, str(_danger), 0.9, skin.get_number_color(_danger))


func _draw_text_centered(rect: Rect2, text: String, size_ratio: float, color: Color) -> void:
	var font: Font = skin.font if skin.font else ThemeDB.fallback_font
	var font_size := maxi(int(rect.size.y * size_ratio), 8)
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


## Rozpatrzone pola mają osobne, przygaszone sprite'y (alfa grafiki zawsze 0/255).
func _draw_resolved(rect: Rect2, tex: Texture2D) -> bool:
	if _resolved and tex:
		draw_texture_rect(tex, rect, false)
		return true
	return false


func _draw_trap(rect: Rect2, alpha: float) -> void:
	if _draw_resolved(rect, skin.trap_resolved_texture):
		return
	if skin.hazard_texture:
		draw_texture_rect(skin.hazard_texture, rect, false, Color(1, 1, 1, alpha))
		return
	# Placeholder: kolczasta kula
	var color := Color(skin.hazard_color, alpha)
	var center := rect.get_center()
	var spike := rect.size.x * 0.34
	var w := maxf(rect.size.x * 0.06, 1.0)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(PI * 0.25 * i)
		draw_line(center - dir * spike, center + dir * spike, color, w)
	draw_circle(center, rect.size.x * 0.22, color)


func _draw_monster(rect: Rect2, alpha: float) -> void:
	if _draw_resolved(rect, skin.monster_resolved_texture):
		return
	var tex := _icon if _icon else skin.monster_texture
	if tex:
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
		return
	# Placeholder: głowa z rogami i oczami
	var s := rect.size.x
	var c := rect.get_center() + Vector2(0, s * 0.05)
	var body := Color(skin.monster_color, alpha)
	var eye := Color(skin.monster_eye_color, alpha)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.12), c + Vector2(-s * 0.34, -s * 0.38), c + Vector2(-s * 0.1, -s * 0.24)]), body)
	draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.28, -s * 0.12), c + Vector2(s * 0.34, -s * 0.38), c + Vector2(s * 0.1, -s * 0.24)]), body)
	draw_circle(c, s * 0.3, body)
	draw_circle(c + Vector2(-s * 0.11, -s * 0.04), s * 0.065, eye)
	draw_circle(c + Vector2(s * 0.11, -s * 0.04), s * 0.065, eye)
	if _resolved:
		_draw_cross(rect, Color(skin.revealed_border_color, 1.0))


func _draw_treasure(rect: Rect2, alpha: float) -> void:
	if _draw_resolved(rect, skin.treasure_resolved_texture):
		return
	if skin.treasure_texture:
		draw_texture_rect(skin.treasure_texture, rect, false, Color(1, 1, 1, alpha))
		return
	# Placeholder: skrzynia
	var s := rect.size.x
	var box := Rect2(rect.position + Vector2(s * 0.2, s * 0.32), Vector2(s * 0.6, s * 0.42))
	var trim := Color(skin.treasure_trim_color, alpha)
	draw_rect(box, Color(skin.treasure_color, alpha))
	draw_rect(Rect2(box.position, Vector2(box.size.x, box.size.y * 0.3)), trim, false, maxf(s * 0.04, 1.0))
	draw_rect(Rect2(box.get_center() - Vector2(s * 0.05, s * 0.02), Vector2(s * 0.1, s * 0.12)), trim)


func _draw_exit(rect: Rect2) -> void:
	if skin.exit_texture:
		draw_texture_rect(skin.exit_texture, rect, false)
		return
	# Placeholder: schody w dół
	var s := rect.size.x
	var step := s * 0.16
	var origin := rect.position + Vector2(s * 0.2, s * 0.24)
	for i in range(4):
		draw_rect(Rect2(origin + Vector2(step * i, step * i), Vector2(s * 0.6 - step * i, step * 0.8)), skin.exit_color)


func _draw_shop(rect: Rect2) -> void:
	if skin.shop_texture:
		draw_texture_rect(skin.shop_texture, rect, false)
		return
	# Placeholder: stragan z daszkiem w paski i monetą
	var s := rect.size.x
	var o := rect.position
	var stripe := s * 0.6 / 4.0
	for i in range(4):
		var color := skin.shop_color if i % 2 == 0 else Color.WHITE
		draw_rect(Rect2(o + Vector2(s * 0.2 + stripe * i, s * 0.2), Vector2(stripe, s * 0.16)), color)
	draw_rect(Rect2(o + Vector2(s * 0.24, s * 0.36), Vector2(s * 0.52, s * 0.4)), Color(skin.shop_color, 0.55))
	draw_circle(o + Vector2(s * 0.5, s * 0.56), s * 0.11, skin.treasure_trim_color)


func _draw_blacksmith(rect: Rect2) -> void:
	if skin.blacksmith_texture:
		draw_texture_rect(skin.blacksmith_texture, rect, false)
		return
	# Placeholder: kowadło
	var s := rect.size.x
	var o := rect.position
	var anvil := PackedVector2Array([
		o + Vector2(s * 0.14, s * 0.32), o + Vector2(s * 0.84, s * 0.32), o + Vector2(s * 0.84, s * 0.44),
		o + Vector2(s * 0.62, s * 0.48), o + Vector2(s * 0.62, s * 0.62), o + Vector2(s * 0.76, s * 0.76),
		o + Vector2(s * 0.24, s * 0.76), o + Vector2(s * 0.38, s * 0.62), o + Vector2(s * 0.38, s * 0.48),
		o + Vector2(s * 0.14, s * 0.4),
	])
	draw_colored_polygon(anvil, skin.blacksmith_color)


func _draw_resource(rect: Rect2, alpha: float) -> void:
	if _draw_resolved(rect, skin.resource_resolved_texture):
		return
	var tex := _icon if _icon else skin.resource_texture
	if tex:
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
		return
	# Placeholder: kryształ
	var s := rect.size.x
	var c := rect.get_center()
	var color := Color(skin.resource_color, alpha)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.32), c + Vector2(s * 0.2, -s * 0.06), c + Vector2(0, s * 0.32), c + Vector2(-s * 0.2, -s * 0.06),
	]), color)
	draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, s * 0.32), Color(1, 1, 1, 0.5 * alpha), maxf(s * 0.03, 1.0))


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
