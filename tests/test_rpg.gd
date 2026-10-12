extends "res://tests/test_case.gd"
## Testy Fazy 2: zawartość planszy, walka automatyczna, statystyki gracza.

const DEFAULT_CONFIG := preload("res://data/default_floor_config.tres")
const BASE_PLAYER := preload("res://data/player_base_stats.tres")


func _count(model: GridModel, content: GridModel.Content) -> int:
	var n := 0
	for y in range(model.height):
		for x in range(model.width):
			if model.get_content(Vector2i(x, y)) == content:
				n += 1
	return n


func _new_player() -> PlayerStats:
	var p := BASE_PLAYER.duplicate() as PlayerStats
	p.start_run()
	return p


func _monster(hp: int, attack: int, defense: int) -> MonsterInstance:
	var m := MonsterInstance.new()
	m.max_hp = hp
	m.hp = hp
	m.attack = attack
	m.defense = defense
	return m


func test_generation_places_all_content() -> void:
	var config: FloorConfig = DEFAULT_CONFIG
	for s in range(1, 101):
		var floor_number := 1 + s % 6
		var model := GridModel.create_for_floor(config, floor_number, s)
		var click := Vector2i(model.width / 2, model.height / 2)
		model.reveal(click)
		var monsters := _count(model, GridModel.Content.MONSTER)
		var traps := _count(model, GridModel.Content.TRAP)
		check(not model.has_exploded(), "seed %d: pierwszy klik bezpieczny" % s)
		check_eq(monsters + traps, config.get_hazard_count(floor_number), "seed %d: liczba zagrożeń" % s)
		check_eq(monsters, config.get_monster_count(floor_number), "seed %d: liczba potworów" % s)
		check_eq(_count(model, GridModel.Content.EXIT), 1, "seed %d: dokładnie jedno wyjście" % s)
		check_eq(_count(model, GridModel.Content.TREASURE), config.get_treasure_count(floor_number), "seed %d: skarby" % s)
		var kinds := config.get_monsters_for_floor(floor_number).size()
		var gold := config.get_treasure_gold_range(floor_number)
		for y in range(model.height):
			for x in range(model.width):
				var c := Vector2i(x, y)
				match model.get_content(c):
					GridModel.Content.MONSTER:
						check(model.get_payload(c) >= 0 and model.get_payload(c) < kinds, "seed %d: typ potwora w puli" % s)
					GridModel.Content.TREASURE:
						check(model.get_payload(c) >= gold.x and model.get_payload(c) <= gold.y, "seed %d: złoto w zakresie" % s)


func test_generation_with_content_is_deterministic() -> void:
	var a := GridModel.create_for_floor(DEFAULT_CONFIG, 3, 999)
	var b := GridModel.create_for_floor(DEFAULT_CONFIG, 3, 999)
	a.reveal(Vector2i(2, 2))
	b.reveal(Vector2i(2, 2))
	var same := true
	for y in range(a.height):
		for x in range(a.width):
			var c := Vector2i(x, y)
			if a.get_content(c) != b.get_content(c) or a.get_payload(c) != b.get_payload(c):
				same = false
	check(same, "ten sam seed = te same potwory, skarby i wyjście")


func test_flood_fill_stops_at_special_cells() -> void:
	var hazards: Array[Vector2i] = [Vector2i(4, 4)]
	var model := GridModel.new(5, 5, 1, 1)
	model.setup_layout(hazards)
	model.set_cell_content(Vector2i(2, 0), GridModel.Content.TREASURE, 10)
	model.set_cell_content(Vector2i(2, 1), GridModel.Content.TREASURE, 10)
	model.set_cell_content(Vector2i(2, 2), GridModel.Content.EXIT)
	model.set_cell_content(Vector2i(2, 3), GridModel.Content.TREASURE, 10)
	model.set_cell_content(Vector2i(2, 4), GridModel.Content.TREASURE, 10)
	model.reveal(Vector2i(0, 0))
	check_eq(model.get_state(Vector2i(2, 2)), GridModel.CellState.REVEALED, "pole specjalne odkryte")
	check_eq(model.get_state(Vector2i(3, 2)), GridModel.CellState.HIDDEN, "flood fill nie przechodzi przez pola specjalne")
	check_eq(model.get_payload(Vector2i(2, 0)), 10, "payload skarbu")


func test_chord_counts_revealed_hazards() -> void:
	var hazards: Array[Vector2i] = [Vector2i(0, 0)]
	var model := GridModel.new(3, 3, 1, 1)
	model.setup_layout(hazards)
	model.reveal(Vector2i(0, 0))
	model.resolve(Vector2i(0, 0))
	model.reveal(Vector2i(1, 1))
	check_eq(model.chord(Vector2i(1, 1)).size(), 7, "odkryte zagrożenie liczy się jak flaga")
	check_eq(model.get_marked_hazard_count(), 1, "licznik zidentyfikowanych zagrożeń")


func test_combat_win() -> void:
	var player := _new_player()
	var result := CombatResolver.resolve(player, _monster(10, 4, 1))
	# 5 ATK - 1 DEF = 4 na cios -> 3 ciosy; potwór 4 - 1 = 3 obrażeń, uderza 2 razy
	check(result.won, "gracz wygrywa")
	check_eq(result.rounds, 3, "3 rundy")
	check_eq(result.damage_taken, 6, "obrażenia gracza")
	check_eq(player.hp, player.max_hp, "resolve nie modyfikuje gracza")


func test_combat_loss() -> void:
	var player := _new_player()
	var result := CombatResolver.resolve(player, _monster(200, 20, 10))
	check(not result.won, "gracz przegrywa")
	check_eq(result.damage_taken, player.hp, "obrażenia równe pozostałemu HP")


func test_combat_minimum_damage() -> void:
	check_eq(CombatResolver.hit_damage(1, 50), 1, "minimum 1 obrażeń")


func test_player_level_up() -> void:
	var player := _new_player()
	var need := player.get_exp_to_next_level()
	var levels: Array[int] = []
	player.leveled_up.connect(func(l: int) -> void: levels.append(l))
	player.take_damage(10)
	player.add_experience(need + 1)
	check_eq(player.level, 2, "awans na 2")
	check_eq(player.experience, 1, "nadwyżka EXP zostaje")
	check_eq(player.max_hp, BASE_PLAYER.max_hp + BASE_PLAYER.hp_per_level, "więcej max HP")
	check_eq(player.hp, player.max_hp, "pełne HP po awansie")
	check_eq(levels, [2] as Array[int], "sygnał leveled_up")
	check_eq(BASE_PLAYER.max_hp, 30, "zasób bazowy nienaruszony")


func test_player_damage_and_heal() -> void:
	var player := _new_player()
	player.take_damage(1000)
	check_eq(player.hp, 0, "HP nie spada poniżej 0")
	check(player.is_dead(), "martwy")
	check_eq(player.heal(5), 5, "leczenie zwraca odzyskane HP")
	check_eq(player.heal(1000), player.max_hp - 5, "leczenie do max HP")


func test_monster_scaling() -> void:
	var data: MonsterData = DEFAULT_CONFIG.monster_pool[1]
	var weak := data.create_instance(1)
	var strong := data.create_instance(5)
	check_eq(weak.max_hp, data.max_hp, "moc 1 = statystyki bazowe")
	check(strong.max_hp > weak.max_hp, "więcej HP przy większej mocy")
	check(strong.gold_reward >= weak.gold_reward, "lepsze nagrody przy większej mocy")
	check(UiText.t(data.name_key) != String(data.name_key), "nazwa potwora ma tekst w UiText")


func test_floor_config_rpg_values() -> void:
	var config: FloorConfig = DEFAULT_CONFIG
	check_eq(config.get_monsters_for_floor(1).size(), 2, "na 1. piętrze tylko szczur i goblin")
	check_eq(config.get_monsters_for_floor(5).size(), 4, "na 5. piętrze wszystkie potwory")
	check(config.get_trap_damage(10) > config.get_trap_damage(1), "pułapki mocniejsze głębiej")
	var g1 := config.get_treasure_gold_range(1)
	var g9 := config.get_treasure_gold_range(9)
	check(g1.x <= g1.y, "poprawny zakres złota")
	check(g9.y > g1.y, "skarby cenniejsze głębiej")
