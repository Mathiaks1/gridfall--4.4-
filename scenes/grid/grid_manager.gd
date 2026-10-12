class_name GridManager
extends Control
## Widok siatki: tworzy Tile, dopasowuje rozmiar pól do dostępnego miejsca,
## tłumaczy akcje z GridInput na wywołania GridModel i ogłasza wyniki przez EventBus.

@export var tile_scene: PackedScene
@export var skin: TileSkin
@export var max_tile_size: float = 72.0

var model: GridModel
var interactive: bool = false

var _tiles: Array[Tile] = []
var _tile_size: float = 32.0
var _origin := Vector2.ZERO
var _held_cell := GridModel.INVALID_CELL
var _solution_shown: bool = false
var _highlighted_cell := GridModel.INVALID_CELL

@onready var _grid_input: GridInput = $GridInput


func _ready() -> void:
	resized.connect(_layout_tiles)
	_grid_input.cell_resolver = _cell_at
	_grid_input.action_triggered.connect(_on_action_triggered)
	_grid_input.hold_progress_changed.connect(_on_hold_progress_changed)


## Podpina nowy model (nowy run / nowe piętro) i odbudowuje pola.
func setup(p_model: GridModel) -> void:
	_grid_input.cancel()
	model = p_model
	_solution_shown = false
	_held_cell = GridModel.INVALID_CELL
	_highlighted_cell = GridModel.INVALID_CELL
	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()
	for y in range(model.height):
		for x in range(model.width):
			var tile := tile_scene.instantiate() as Tile
			tile.cell = Vector2i(x, y)
			tile.skin = skin
			add_child(tile)
			_tiles.append(tile)
	interactive = true
	_layout_tiles()
	_refresh_all()
	_emit_hazard_counter()


## Oznacza pole jako rozpatrzone i odświeża jego widok (wołane przez Game po obsłużeniu aktywacji).
func resolve_cell(cell: Vector2i) -> void:
	if model == null or not model.is_inside(cell):
		return
	model.resolve(cell)
	_refresh_tile(_tile_at(cell))


## Po porażce: pokazuje wszystkie zagrożenia i błędne flagi.
func show_solution() -> void:
	if model == null:
		return
	interactive = false
	_grid_input.cancel()
	model.reveal_all_hazards()
	_solution_shown = true
	_refresh_all()


func _gui_input(event: InputEvent) -> void:
	if interactive and model != null and _grid_input.handle_event(event):
		accept_event()


func _on_action_triggered(action: GridInput.Action, cell: Vector2i) -> void:
	if not interactive or model == null or not model.is_inside(cell):
		return
	match action:
		GridInput.Action.REVEAL:
			_handle_reveal(cell)
		GridInput.Action.FLAG:
			if model.toggle_flag(cell):
				_refresh_tile(_tile_at(cell))
				_emit_hazard_counter()


func _handle_reveal(cell: Vector2i) -> void:
	var was_hidden := model.get_state(cell) == GridModel.CellState.HIDDEN
	if not was_hidden and model.get_state(cell) != GridModel.CellState.REVEALED:
		return

	# Dotknięcie odkrytego pola specjalnego (skarb, wyjście) = aktywacja
	if not was_hidden and model.is_special(cell):
		if not model.is_resolved(cell):
			EventBus.cell_activated.emit(cell, model.get_content(cell))
		return

	var revealed := model.reveal(cell) if was_hidden else model.chord(cell)
	if revealed.is_empty():
		return
	_refresh_cells(revealed)
	# Podświetlenie przeszło na nowe zagrożenie — zgaś je na poprzednim
	if _highlighted_cell != model.exploded_cell:
		if model.is_inside(_highlighted_cell):
			_refresh_tile(_tile_at(_highlighted_cell))
		_highlighted_cell = model.exploded_cell
	EventBus.cells_revealed.emit(revealed)

	# Zagrożenie odkryte tą akcją (bezpośrednio albo przez chording) wymaga reakcji gry
	for c in revealed:
		if model.is_hazard(c) and not model.is_resolved(c):
			_emit_hazard_counter()
			EventBus.cell_activated.emit(c, model.get_content(c))
			return
	# Skarb odkryty bezpośrednim kliknięciem zbieramy od razu; wyjście wymaga drugiego dotknięcia
	if was_hidden and model.get_content(cell) == GridModel.Content.TREASURE:
		EventBus.cell_activated.emit(cell, GridModel.Content.TREASURE)


func _emit_hazard_counter() -> void:
	EventBus.flags_changed.emit(model.get_marked_hazard_count(), model.hazard_count)


func _on_hold_progress_changed(cell: Vector2i, ratio: float) -> void:
	if _held_cell != GridModel.INVALID_CELL and _held_cell != cell:
		_tile_at(_held_cell).set_hold_progress(0.0)
	if model == null or not model.is_inside(cell):
		_held_cell = GridModel.INVALID_CELL
		return
	_tile_at(cell).set_hold_progress(ratio)
	_held_cell = cell if ratio > 0.0 else GridModel.INVALID_CELL


func _layout_tiles() -> void:
	if model == null:
		return
	# Pola kwadratowe, dopasowane do mniejszego wymiaru. Faza 4: pan/zoom dla dużych siatek na telefonie.
	var fit := minf(size.x / model.width, size.y / model.height)
	_tile_size = maxf(floorf(minf(fit, max_tile_size)), 4.0)
	var board_size := Vector2(model.width, model.height) * _tile_size
	_origin = ((size - board_size) * 0.5).floor()
	for tile in _tiles:
		tile.position = _origin + Vector2(tile.cell) * _tile_size
		tile.size = Vector2(_tile_size, _tile_size)


func _cell_at(local_pos: Vector2) -> Vector2i:
	if model == null:
		return GridModel.INVALID_CELL
	var rel := (local_pos - _origin) / _tile_size
	var cell := Vector2i(floori(rel.x), floori(rel.y))
	return cell if model.is_inside(cell) else GridModel.INVALID_CELL


func _tile_at(cell: Vector2i) -> Tile:
	return _tiles[cell.y * model.width + cell.x]


func _refresh_all() -> void:
	for tile in _tiles:
		_refresh_tile(tile)


func _refresh_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_refresh_tile(_tile_at(cell))


func _refresh_tile(tile: Tile) -> void:
	var c := tile.cell
	tile.set_view(model.get_state(c), model.get_content(c), model.get_danger(c), model.is_resolved(c), c == model.exploded_cell, _solution_shown)
