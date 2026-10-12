extends "res://tests/test_case.gd"
## Testy czystej logiki GridModel.

const HIDDEN := GridModel.CellState.HIDDEN
const REVEALED := GridModel.CellState.REVEALED
const FLAGGED := GridModel.CellState.FLAGGED


func _model_with(w: int, h: int, hazards: Array[Vector2i]) -> GridModel:
	var model := GridModel.new(w, h, hazards.size(), 1)
	model.setup_layout(hazards)
	return model


func _hazard_layout(model: GridModel) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(model.height):
		for x in range(model.width):
			if model.is_hazard(Vector2i(x, y)):
				result.append(Vector2i(x, y))
	return result


func test_neighbor_counts() -> void:
	# H . . .
	# . . H .
	# . . . .
	# . . . .
	var model := _model_with(4, 4, [Vector2i(0, 0), Vector2i(2, 1)] as Array[Vector2i])
	check_eq(model.get_danger(Vector2i(1, 0)), 2, "(1,0) widzi oba zagrożenia")
	check_eq(model.get_danger(Vector2i(1, 1)), 2, "(1,1) widzi oba zagrożenia")
	check_eq(model.get_danger(Vector2i(0, 1)), 1, "krawędź (0,1)")
	check_eq(model.get_danger(Vector2i(3, 0)), 1, "róg (3,0)")
	check_eq(model.get_danger(Vector2i(3, 3)), 0, "róg (3,3) bez zagrożeń")
	check_eq(model.get_danger(Vector2i(1, 2)), 1, "(1,2) pod zagrożeniem (2,1)")
	check_eq(model.get_neighbors(Vector2i(0, 0)).size(), 3, "róg ma 3 sąsiadów")
	check_eq(model.get_neighbors(Vector2i(1, 0)).size(), 5, "krawędź ma 5 sąsiadów")
	check_eq(model.get_neighbors(Vector2i(1, 1)).size(), 8, "środek ma 8 sąsiadów")


func test_flood_fill_reveals_whole_open_area() -> void:
	var model := _model_with(5, 5, [Vector2i(4, 4)] as Array[Vector2i])
	var revealed := model.reveal(Vector2i(0, 0))
	check_eq(revealed.size(), 24, "odkryto wszystko poza zagrożeniem")
	check_eq(model.get_state(Vector2i(4, 4)), HIDDEN, "zagrożenie zostaje zakryte")
	check(model.is_cleared(), "plansza oczyszczona")
	check(not model.has_exploded(), "brak eksplozji")


func test_flood_fill_stops_at_numbers() -> void:
	# Ściana zagrożeń w kolumnie x=2: flood z lewej nie może przejść na prawą stronę
	var wall: Array[Vector2i] = []
	for y in range(5):
		wall.append(Vector2i(2, y))
	var model := _model_with(5, 5, wall)
	var revealed := model.reveal(Vector2i(0, 0))
	check_eq(revealed.size(), 10, "odkryte kolumny x=0 i x=1")
	for y in range(5):
		check_eq(model.get_state(Vector2i(1, y)), REVEALED, "kolumna z liczbami odkryta (y=%d)" % y)
		check_eq(model.get_state(Vector2i(3, y)), HIDDEN, "prawa strona zakryta (y=%d)" % y)
	check(not model.is_cleared(), "plansza nieoczyszczona")


func test_flood_fill_respects_flags() -> void:
	var model := _model_with(5, 5, [Vector2i(4, 4)] as Array[Vector2i])
	check(model.toggle_flag(Vector2i(2, 2)), "flaga postawiona")
	var revealed := model.reveal(Vector2i(0, 0))
	check_eq(revealed.size(), 23, "pole z flagą pominięte")
	check_eq(model.get_state(Vector2i(2, 2)), FLAGGED, "flaga zostaje")
	check_eq(model.reveal(Vector2i(2, 2)).size(), 0, "nie można odkryć oflagowanego pola")


func test_reveal_hazard_explodes() -> void:
	var model := _model_with(3, 3, [Vector2i(1, 1)] as Array[Vector2i])
	model.reveal(Vector2i(1, 1))
	check(model.has_exploded(), "eksplozja")
	check_eq(model.exploded_cell, Vector2i(1, 1), "pole eksplozji")
	check(not model.is_cleared(), "po eksplozji nie ma wygranej")


func test_first_click_is_safe() -> void:
	var picker := RandomNumberGenerator.new()
	picker.seed = 12345
	for s in range(1, 301):
		var model := GridModel.new(9, 9, 20, s, 1)
		var click := Vector2i(picker.randi_range(0, 8), picker.randi_range(0, 8))
		model.reveal(click)
		check(not model.has_exploded(), "seed %d: pierwszy klik bezpieczny" % s)
		check_eq(model.get_danger(click), 0, "seed %d: pierwszy klik otwiera obszar" % s)
		check_eq(_hazard_layout(model).size(), 20, "seed %d: liczba zagrożeń" % s)


func test_first_click_safe_on_crowded_board() -> void:
	# 3x3 z 8 zagrożeniami: strefa 3x3 niemożliwa — chronione jest tylko kliknięte pole
	for s in range(1, 51):
		var model := GridModel.new(3, 3, 8, s, 1)
		model.reveal(Vector2i(0, 0))
		check(not model.has_exploded(), "seed %d: bezpieczny klik na zatłoczonej planszy" % s)
		check(model.is_cleared(), "seed %d: jedyne bezpieczne pole odkryte" % s)


func test_generation_is_deterministic() -> void:
	var a := GridModel.new(12, 10, 25, 777)
	var b := GridModel.new(12, 10, 25, 777)
	a.reveal(Vector2i(5, 5))
	b.reveal(Vector2i(5, 5))
	check_eq(_hazard_layout(a), _hazard_layout(b), "ten sam seed + klik = ten sam układ")

	var any_different := false
	for s in range(1, 11):
		var c := GridModel.new(12, 10, 25, 777 + s)
		c.reveal(Vector2i(5, 5))
		if _hazard_layout(c) != _hazard_layout(a):
			any_different = true
	check(any_different, "inne seedy dają inne układy")


func test_chord_reveals_neighbors_when_flags_match() -> void:
	var model := _model_with(3, 3, [Vector2i(0, 0)] as Array[Vector2i])
	model.reveal(Vector2i(1, 1))
	check_eq(model.chord(Vector2i(1, 1)).size(), 0, "bez flag chording nic nie robi")
	model.toggle_flag(Vector2i(0, 0))
	var revealed := model.chord(Vector2i(1, 1))
	check_eq(revealed.size(), 7, "chording odkrywa pozostałych sąsiadów")
	check(model.is_cleared(), "plansza oczyszczona")


func test_chord_with_wrong_flag_explodes() -> void:
	var model := _model_with(3, 3, [Vector2i(0, 0)] as Array[Vector2i])
	model.reveal(Vector2i(1, 1))
	model.toggle_flag(Vector2i(2, 2))
	model.chord(Vector2i(1, 1))
	check(model.has_exploded(), "błędna flaga + chording = eksplozja")


func test_flag_toggle_and_count() -> void:
	var model := _model_with(3, 3, [Vector2i(0, 0)] as Array[Vector2i])
	check(model.toggle_flag(Vector2i(2, 2)), "flaga on")
	check_eq(model.get_flag_count(), 1, "1 flaga")
	check(model.toggle_flag(Vector2i(2, 2)), "flaga off")
	check_eq(model.get_flag_count(), 0, "0 flag")
	model.reveal(Vector2i(1, 1))
	check(not model.toggle_flag(Vector2i(1, 1)), "nie można oflagować odkrytego pola")


func test_reveal_all_hazards() -> void:
	var model := _model_with(4, 4, [Vector2i(0, 0), Vector2i(3, 3)] as Array[Vector2i])
	model.toggle_flag(Vector2i(0, 0))
	var changed := model.reveal_all_hazards()
	check_eq(changed.size(), 1, "oflagowane zagrożenie zostaje flagą")
	check_eq(model.get_state(Vector2i(3, 3)), REVEALED, "nieoflagowane zagrożenie odsłonięte")


func test_floor_config_scaling() -> void:
	var config := FloorConfig.new()
	check(config.get_hazard_count(10) >= config.get_hazard_count(1), "więcej zagrożeń głębiej")
	check(config.get_width(10) >= config.get_width(1), "siatka rośnie z piętrem")
	check_eq(config.get_width(1000), config.max_width, "szerokość ograniczona maksimum")
	check(config.get_hazard_density(1000) <= config.max_hazard_density, "gęstość ograniczona maksimum")
	var model := GridModel.create_for_floor(config, 1, 42)
	check_eq(model.width, config.get_width(1), "model z konfiguracji: szerokość")
	check_eq(model.hazard_count, config.get_hazard_count(1), "model z konfiguracji: zagrożenia")
