class_name GridModel
extends RefCounted
## Czysta logika siatki: generacja, odkrywanie, flagi, chording.
## Bez węzłów — testowalna i deterministyczna względem seeda.

## Zawartość pola. Faza 1 używa EMPTY i TRAP; reszta jest gotowa na Fazy 2–3.
enum Content { EMPTY, TRAP, MONSTER, TREASURE, EXIT, SHOP, BLACKSMITH, RESOURCE }
enum CellState { HIDDEN, REVEALED, FLAGGED }

const INVALID_CELL := Vector2i(-1, -1)
const NEIGHBOR_OFFSETS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var width: int
var height: int
var hazard_count: int
var run_seed: int
var safe_radius: int
var is_generated: bool = false
var exploded_cell: Vector2i = INVALID_CELL

var _content := PackedByteArray()
var _state := PackedByteArray()
var _danger := PackedByteArray()
var _revealed_safe_count: int = 0
var _flag_count: int = 0


func _init(p_width: int, p_height: int, p_hazard_count: int, p_run_seed: int, p_safe_radius: int = 1) -> void:
	width = maxi(p_width, 1)
	height = maxi(p_height, 1)
	run_seed = p_run_seed
	safe_radius = maxi(p_safe_radius, 0)
	# Zawsze zostaw co najmniej jedno bezpieczne pole na pierwszy klik
	hazard_count = clampi(p_hazard_count, 0, width * height - 1)
	var total := width * height
	_content.resize(total)
	_content.fill(Content.EMPTY)
	_state.resize(total)
	_state.fill(CellState.HIDDEN)
	_danger.resize(total)
	_danger.fill(0)


## Tworzy model dla danego piętra na podstawie konfiguracji (rozmiar i gęstość skalują się z piętrem).
static func create_for_floor(config: FloorConfig, floor_number: int, p_run_seed: int) -> GridModel:
	return GridModel.new(
		config.get_width(floor_number),
		config.get_height(floor_number),
		config.get_hazard_count(floor_number),
		p_run_seed,
		config.safe_radius
	)


# --- Generacja -------------------------------------------------------------

## Rozmieszcza zagrożenia tak, by safe_cell (i jego otoczenie w promieniu safe_radius) było puste.
## Ten sam seed + to samo pierwsze kliknięcie = identyczny układ.
func generate(safe_cell: Vector2i) -> void:
	if is_generated:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed

	var safe_index := _index(safe_cell) if is_inside(safe_cell) else -1
	var safe_zone := {}
	if safe_index >= 0:
		for dy in range(-safe_radius, safe_radius + 1):
			for dx in range(-safe_radius, safe_radius + 1):
				var c := safe_cell + Vector2i(dx, dy)
				if is_inside(c):
					safe_zone[_index(c)] = true

	var candidates: Array[int] = []
	for i in range(width * height):
		if not safe_zone.has(i):
			candidates.append(i)
	# Mała plansza / duża gęstość: chronimy tylko kliknięte pole
	if candidates.size() < hazard_count:
		candidates.clear()
		for i in range(width * height):
			if i != safe_index:
				candidates.append(i)

	# Fisher–Yates na własnym RNG (deterministyczny, niezależny od globalnego randi())
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	hazard_count = mini(hazard_count, candidates.size())
	for k in range(hazard_count):
		_content[candidates[k]] = Content.TRAP
	_finish_generation()


## Ustawia konkretny układ zagrożeń (testy, w przyszłości wczytywanie zapisu).
func setup_layout(hazard_cells: Array[Vector2i]) -> void:
	_content.fill(Content.EMPTY)
	var placed := 0
	for c in hazard_cells:
		if is_inside(c) and _content[_index(c)] == Content.EMPTY:
			_content[_index(c)] = Content.TRAP
			placed += 1
	hazard_count = placed
	_finish_generation()


func _finish_generation() -> void:
	for i in range(width * height):
		var cell := _cell_from_index(i)
		var count := 0
		for n in get_neighbors(cell):
			if is_hazard(n):
				count += 1
		_danger[i] = count
	is_generated = true


# --- Akcje gracza ------------------------------------------------------------

## Odkrywa pole. Pierwsze odkrycie generuje planszę. Zwraca listę faktycznie odkrytych pól.
## Puste pola (0) rozlewają się iteracyjnym BFS — bez rekurencji, bezpiecznie dla dużych siatek.
func reveal(cell: Vector2i) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	if not is_inside(cell):
		return revealed
	if not is_generated:
		generate(cell)
	var idx := _index(cell)
	if _state[idx] != CellState.HIDDEN:
		return revealed

	_state[idx] = CellState.REVEALED
	revealed.append(cell)
	if is_hazard(cell):
		exploded_cell = cell
		return revealed
	_revealed_safe_count += 1

	# revealed służy jednocześnie jako kolejka BFS
	var head := 0
	while head < revealed.size():
		var current := revealed[head]
		head += 1
		# Rozlewamy się tylko z pustych pól z zerem; pola specjalne (skarb, wyjście...) zatrzymują flood fill
		if _danger[_index(current)] != 0 or _content[_index(current)] != Content.EMPTY:
			continue
		for n in get_neighbors(current):
			var ni := _index(n)
			if _state[ni] != CellState.HIDDEN or is_hazard(n):
				continue
			_state[ni] = CellState.REVEALED
			_revealed_safe_count += 1
			revealed.append(n)
	return revealed


## Chording: na odkrytym polu z liczbą, gdy liczba flag wokół == liczba, odkrywa resztę sąsiadów.
func chord(cell: Vector2i) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	if not is_inside(cell) or get_state(cell) != CellState.REVEALED or is_hazard(cell):
		return revealed
	var danger := get_danger(cell)
	if danger == 0 or count_adjacent_flags(cell) != danger:
		return revealed
	for n in get_neighbors(cell):
		if get_state(n) == CellState.HIDDEN:
			revealed.append_array(reveal(n))
			if has_exploded():
				break
	return revealed


## Przełącza flagę na zakrytym polu. Zwraca true, jeśli stan się zmienił.
func toggle_flag(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	var idx := _index(cell)
	match _state[idx]:
		CellState.HIDDEN:
			_state[idx] = CellState.FLAGGED
			_flag_count += 1
			return true
		CellState.FLAGGED:
			_state[idx] = CellState.HIDDEN
			_flag_count -= 1
			return true
	return false


## Po porażce: odsłania wszystkie nieoflagowane zagrożenia. Zwraca zmienione pola.
func reveal_all_hazards() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for i in range(width * height):
		var cell := _cell_from_index(i)
		if is_hazard(cell) and _state[i] == CellState.HIDDEN:
			_state[i] = CellState.REVEALED
			changed.append(cell)
	return changed


# --- Zapytania ---------------------------------------------------------------

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_state(cell: Vector2i) -> CellState:
	return _state[_index(cell)] as CellState


func get_content(cell: Vector2i) -> Content:
	return _content[_index(cell)] as Content


## Liczba zagrożeń (pułapek + potworów) wśród 8 sąsiadów.
func get_danger(cell: Vector2i) -> int:
	return _danger[_index(cell)]


func is_hazard(cell: Vector2i) -> bool:
	var c := _content[_index(cell)]
	return c == Content.TRAP or c == Content.MONSTER


func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var n := cell + offset
		if is_inside(n):
			result.append(n)
	return result


func count_adjacent_flags(cell: Vector2i) -> int:
	var count := 0
	for n in get_neighbors(cell):
		if get_state(n) == CellState.FLAGGED:
			count += 1
	return count


func get_flag_count() -> int:
	return _flag_count


func get_safe_total() -> int:
	return width * height - hazard_count


func get_revealed_safe_count() -> int:
	return _revealed_safe_count


func has_exploded() -> bool:
	return exploded_cell != INVALID_CELL


## Klasyczny warunek wygranej sapera: wszystkie bezpieczne pola odkryte.
func is_cleared() -> bool:
	return is_generated and not has_exploded() and _revealed_safe_count == get_safe_total()


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _cell_from_index(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % width, i / width)
