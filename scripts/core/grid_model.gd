class_name GridModel
extends RefCounted
## Czysta logika siatki: generacja, odkrywanie, flagi, chording, efekty przedmiotów, zapis stanu.
## Bez węzłów — testowalna i deterministyczna względem seeda.

## Zawartość pola.
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
## Ostatnio uruchomione zagrożenie (pułapka/potwór).
var exploded_cell: Vector2i = INVALID_CELL

# Zawartość dodatkowa — ustawiana przed generacją (create_for_floor). Domyślnie: czysty saper.
## Ile z hazard_count to potwory (reszta to pułapki).
var monster_count: int = 0
## Liczba typów potworów do wylosowania; payload potwora = indeks typu.
var monster_kinds: int = 1
var treasure_count: int = 0
## Zakres złota w skarbie (payload skarbu).
var treasure_gold := Vector2i(1, 1)
var has_exit: bool = false
var shop_count: int = 0
var blacksmith_count: int = 0
var resource_count: int = 0
## Wagi losowania surowców; payload pola surowca = indeks w tej tablicy.
var material_weights := PackedFloat32Array()

var _content := PackedByteArray()
var _state := PackedByteArray()
var _danger := PackedByteArray()
## Dane pola zależne od zawartości: typ potwora, ilość złota.
var _payload := PackedInt32Array()
## Pole "rozpatrzone": pułapka zadziałała, potwór pokonany, skarb zebrany.
var _resolved := PackedByteArray()
var _revealed_safe_count: int = 0
var _flag_count: int = 0
var _revealed_hazard_count: int = 0


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
	_payload.resize(total)
	_payload.fill(0)
	_resolved.resize(total)
	_resolved.fill(0)


## Tworzy model dla danego piętra na podstawie konfiguracji (rozmiar i gęstość skalują się z piętrem).
## database może być null (czysty saper bez potworów i surowców).
static func create_for_floor(config: FloorConfig, database: GameDatabase, floor_number: int, p_run_seed: int) -> GridModel:
	var model := GridModel.new(
		config.get_width(floor_number),
		config.get_height(floor_number),
		config.get_hazard_count(floor_number),
		p_run_seed,
		config.safe_radius
	)
	var monster_types := database.get_monsters_for_floor(floor_number).size() if database else 0
	model.monster_count = config.get_monster_count(floor_number) if monster_types > 0 else 0
	model.monster_kinds = maxi(monster_types, 1)
	model.treasure_count = config.get_treasure_count(floor_number)
	model.treasure_gold = config.get_treasure_gold_range(floor_number)
	model.has_exit = config.has_exit
	if database:
		model.material_weights = database.get_material_weights(floor_number)
	model.resource_count = config.get_resource_count(floor_number) if not model.material_weights.is_empty() else 0
	# Sklep i Kowal pojawiają się losowo — rzut zależny tylko od seeda piętra
	var features := RandomNumberGenerator.new()
	features.seed = hash([p_run_seed, "features"])
	var shop_roll := features.randf()
	var blacksmith_roll := features.randf()
	model.shop_count = 1 if floor_number >= config.shop_min_floor and shop_roll < config.shop_chance else 0
	model.blacksmith_count = 1 if floor_number >= config.blacksmith_min_floor and blacksmith_roll < config.blacksmith_chance else 0
	return model


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
	var monsters := clampi(monster_count, 0, hazard_count)
	for k in range(hazard_count):
		var i := candidates[k]
		if k < monsters:
			_content[i] = Content.MONSTER
			_payload[i] = rng.randi_range(0, maxi(monster_kinds, 1) - 1)
		else:
			_content[i] = Content.TRAP

	# Pola specjalne z pozostałych kandydatów (poza strefą startu)
	var rest := candidates.slice(hazard_count)
	if has_exit and not rest.is_empty():
		var exit_pos := _pick_far_index(rest, safe_cell)
		_content[rest[exit_pos]] = Content.EXIT
		rest.remove_at(exit_pos)
	for _k in range(shop_count):
		_take_special(rest, Content.SHOP, 0)
	for _k in range(blacksmith_count):
		_take_special(rest, Content.BLACKSMITH, 0)
	for _k in range(treasure_count):
		_take_special(rest, Content.TREASURE, rng.randi_range(treasure_gold.x, maxi(treasure_gold.y, treasure_gold.x)))
	for _k in range(resource_count):
		var material := GameDatabase.pick_weighted(material_weights, rng)
		if material >= 0:
			_take_special(rest, Content.RESOURCE, material)
	_finish_generation()


## Zdejmuje pierwsze wolne pole z listy i ustawia na nim zawartość specjalną.
func _take_special(free_indices: Array[int], content: Content, payload: int) -> void:
	if free_indices.is_empty():
		return
	var i: int = free_indices.pop_front()
	_content[i] = content
	_payload[i] = payload


## Wybiera (z już przetasowanej listy) pierwsze pole odległe od startu o co najmniej pół planszy.
func _pick_far_index(indices: Array[int], from: Vector2i) -> int:
	var min_dist := maxi(width, height) / 2.0
	for k in range(indices.size()):
		var c := _cell_from_index(indices[k])
		if maxi(absi(c.x - from.x), absi(c.y - from.y)) >= min_dist:
			return k
	return 0


## Ustawia konkretny układ zagrożeń (testy, w przyszłości wczytywanie zapisu).
func setup_layout(hazard_cells: Array[Vector2i]) -> void:
	_content.fill(Content.EMPTY)
	_payload.fill(0)
	var placed := 0
	for c in hazard_cells:
		if is_inside(c) and _content[_index(c)] == Content.EMPTY:
			_content[_index(c)] = Content.TRAP
			placed += 1
	hazard_count = placed
	_finish_generation()


## Ustawia zawartość pojedynczego pola (testy / wczytywanie). Wołać po setup_layout.
func set_cell_content(cell: Vector2i, content: Content, payload: int = 0) -> void:
	var i := _index(cell)
	var was_hazard := is_hazard(cell)
	_content[i] = content
	_payload[i] = payload
	if was_hazard != is_hazard(cell):
		hazard_count += 1 if is_hazard(cell) else -1
	_finish_generation()


func _finish_generation() -> void:
	_revealed_safe_count = 0
	for i in range(width * height):
		var cell := _cell_from_index(i)
		var count := 0
		for n in get_neighbors(cell):
			if is_hazard(n):
				count += 1
		_danger[i] = count
		if _state[i] == CellState.REVEALED and not is_hazard(cell):
			_revealed_safe_count += 1
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
		_revealed_hazard_count += 1
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


## Chording: na odkrytym polu z liczbą, gdy flagi + znane zagrożenia wokół == liczba, odkrywa resztę sąsiadów.
func chord(cell: Vector2i) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	if not is_inside(cell) or get_state(cell) != CellState.REVEALED or is_hazard(cell):
		return revealed
	var danger := get_danger(cell)
	if danger == 0 or count_known_adjacent_hazards(cell) != danger:
		return revealed
	for n in get_neighbors(cell):
		if get_state(n) == CellState.HIDDEN:
			revealed.append_array(reveal(n))
			# Jedno uruchomione zagrożenie na akcję
			if is_hazard(n):
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


## Zwój odkrycia: w promieniu odsłania bezpieczne pola i oflagowuje zagrożenia. Zwraca zmienione pola.
func scry(center: Vector2i, radius: int) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	if not is_inside(center):
		return changed
	if not is_generated:
		generate(center)
	for c in get_cells_in_radius(center, radius):
		if get_state(c) != CellState.HIDDEN:
			continue
		if is_hazard(c):
			_state[_index(c)] = CellState.FLAGGED
			_flag_count += 1
			changed.append(c)
		else:
			changed.append_array(reveal(c))
	return changed


## Granat: niszczy nierozpatrzone zagrożenia w promieniu (odsłania je jako rozpatrzone) i odkrywa bezpieczne pola.
## Zniszczone pola dopisuje do destroyed. Zwraca wszystkie zmienione pola.
func blast(center: Vector2i, radius: int, destroyed: Array[Vector2i]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	if not is_inside(center):
		return changed
	if not is_generated:
		generate(center)
	var area := get_cells_in_radius(center, radius)
	for c in area:
		var i := _index(c)
		if not is_hazard(c) or _resolved[i] != 0:
			continue
		if _state[i] == CellState.FLAGGED:
			_flag_count -= 1
		if _state[i] != CellState.REVEALED:
			_state[i] = CellState.REVEALED
			_revealed_hazard_count += 1
		_resolved[i] = 1
		destroyed.append(c)
		changed.append(c)
	for c in area:
		if not is_hazard(c) and get_state(c) == CellState.HIDDEN:
			changed.append_array(reveal(c))
	return changed


func get_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if is_inside(c):
				result.append(c)
	return result


## Oznacza pole jako rozpatrzone (pułapka zadziałała, potwór pokonany, skarb zebrany).
func resolve(cell: Vector2i) -> void:
	if is_inside(cell):
		_resolved[_index(cell)] = 1


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


## Typ potwora (indeks w puli piętra) albo ilość złota w skarbie.
func get_payload(cell: Vector2i) -> int:
	return _payload[_index(cell)]


func is_resolved(cell: Vector2i) -> bool:
	return _resolved[_index(cell)] != 0


## Pola specjalne niebędące zagrożeniem (skarb, wyjście, ...): aktywowane dotknięciem.
func is_special(cell: Vector2i) -> bool:
	var c := _content[_index(cell)]
	return c != Content.EMPTY and c != Content.TRAP and c != Content.MONSTER


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


## Flagi + już odkryte zagrożenia (zużyte pułapki, pokonane potwory) wokół pola.
func count_known_adjacent_hazards(cell: Vector2i) -> int:
	var count := 0
	for n in get_neighbors(cell):
		var st := get_state(n)
		if st == CellState.FLAGGED or (st == CellState.REVEALED and is_hazard(n)):
			count += 1
	return count


func get_flag_count() -> int:
	return _flag_count


## Zagrożenia już zidentyfikowane: flagi + odkryte (zużyte pułapki, potwory po walce).
func get_marked_hazard_count() -> int:
	return _flag_count + _revealed_hazard_count


func get_safe_total() -> int:
	return width * height - hazard_count


func get_revealed_safe_count() -> int:
	return _revealed_safe_count


func has_exploded() -> bool:
	return exploded_cell != INVALID_CELL


## Wszystkie bezpieczne pola odkryte (od Fazy 2 nie kończy gry — warunkiem przejścia jest wyjście).
func is_cleared() -> bool:
	return is_generated and _revealed_safe_count == get_safe_total()


# --- Zapis -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"width": width, "height": height, "hazard_count": hazard_count,
		"run_seed": run_seed, "safe_radius": safe_radius,
		"is_generated": is_generated, "exploded_cell": exploded_cell,
		"monster_count": monster_count, "monster_kinds": monster_kinds,
		"treasure_count": treasure_count, "treasure_gold": treasure_gold, "has_exit": has_exit,
		"shop_count": shop_count, "blacksmith_count": blacksmith_count,
		"resource_count": resource_count, "material_weights": material_weights,
		"content": _content, "state": _state, "danger": _danger,
		"payload": _payload, "resolved": _resolved,
		"revealed_safe_count": _revealed_safe_count, "flag_count": _flag_count,
		"revealed_hazard_count": _revealed_hazard_count,
	}


static func from_dict(d: Dictionary) -> GridModel:
	var m := GridModel.new(int(d["width"]), int(d["height"]), int(d["hazard_count"]), int(d["run_seed"]), int(d["safe_radius"]))
	m.hazard_count = int(d["hazard_count"])
	m.is_generated = bool(d["is_generated"])
	m.exploded_cell = d["exploded_cell"]
	m.monster_count = int(d["monster_count"])
	m.monster_kinds = int(d["monster_kinds"])
	m.treasure_count = int(d["treasure_count"])
	m.treasure_gold = d["treasure_gold"]
	m.has_exit = bool(d["has_exit"])
	m.shop_count = int(d["shop_count"])
	m.blacksmith_count = int(d["blacksmith_count"])
	m.resource_count = int(d["resource_count"])
	m.material_weights = d["material_weights"]
	m._content = d["content"]
	m._state = d["state"]
	m._danger = d["danger"]
	m._payload = d["payload"]
	m._resolved = d["resolved"]
	m._revealed_safe_count = int(d["revealed_safe_count"])
	m._flag_count = int(d["flag_count"])
	m._revealed_hazard_count = int(d["revealed_hazard_count"])
	return m


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _cell_from_index(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % width, i / width)
