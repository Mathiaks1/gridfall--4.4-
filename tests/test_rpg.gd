extends "res://tests/test_case.gd"
## Testy Fazy 2: zawartość planszy, statystyki gracza, skalowanie potworów.

const DEFAULT_CONFIG := preload("res://data/default_floor_config.tres")
const DATABASE := preload("res://data/game_database.tres")
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


func test_generation_places_all_content() -> void:
	var config: FloorConfig = DEFAULT_CONFIG
	for s in range(1, 101):
		var floor_number := 1 + s % 6
		var model := GridModel.create_for_floor(config, DATABASE, floor_number, s)
		@warning_ignore("integer_division")
		var click := Vector2i(model.width / 2, model.height / 2)
		model.reveal(click)
		var monsters := _count(model, GridModel.Content.MONSTER)
		var traps := _count(model, GridModel.Content.TRAP)
		check(not model.has_exploded(), "seed %d: pierwszy klik bezpieczny" % s)
		check_eq(monsters + traps, config.get_hazard_count(floor_number), "seed %d: liczba zagrożeń" % s)
		check_eq(monsters, config.get_monster_count(floor_number), "seed %d: liczba potworów" % s)
		check_eq(_count(model, GridModel.Content.EXIT), 1, "seed %d: dokładnie jedno wyjście" % s)
		check_eq(_count(model, GridModel.Content.TREASURE), config.get_treasure_count(floor_number), "seed %d: skarby" % s)
		check_eq(_count(model, GridModel.Content.SHOP), model.shop_count, "seed %d: sklep" % s)
		check_eq(_count(model, GridModel.Content.BLACKSMITH), model.blacksmith_count, "seed %d: kowal" % s)
		check_eq(_count(model, GridModel.Content.RESOURCE), config.get_resource_count(floor_number), "seed %d: pola surowców" % s)
		if floor_number < config.blacksmith_min_floor:
			check_eq(model.blacksmith_count, 0, "seed %d: brak kowala na płytkich piętrach" % s)
		var kinds := DATABASE.get_monsters_for_floor(floor_number).size()
		var materials := DATABASE.get_materials_for_floor(floor_number).size()
		var gold := config.get_treasure_gold_range(floor_number)
		for y in range(model.height):
			for x in range(model.width):
				var c := Vector2i(x, y)
				var payload := model.get_payload(c)
				match model.get_content(c):
					GridModel.Content.MONSTER:
						check(payload >= 0 and payload < kinds, "seed %d: typ potwora w puli" % s)
					GridModel.Content.TREASURE:
						check(payload >= gold.x and payload <= gold.y, "seed %d: złoto w zakresie" % s)
					GridModel.Content.RESOURCE:
						check(payload >= 0 and payload < materials, "seed %d: surowiec w puli" % s)


func test_features_appear_across_seeds() -> void:
	var shops := 0
	var smiths := 0
	for s in range(1, 201):
		var model := GridModel.create_for_floor(DEFAULT_CONFIG, DATABASE, 3, s)
		shops += model.shop_count
		smiths += model.blacksmith_count
	check(shops > 40 and shops < 140, "sklep na ok. 40%% pięter (jest %d/200)" % shops)
	check(smiths > 25 and smiths < 100, "kowal na ok. 30%% pięter (jest %d/200)" % smiths)


func test_generation_with_content_is_deterministic() -> void:
	var a := GridModel.create_for_floor(DEFAULT_CONFIG, DATABASE, 3, 999)
	var b := GridModel.create_for_floor(DEFAULT_CONFIG, DATABASE, 3, 999)
	a.reveal(Vector2i(2, 2))
	b.reveal(Vector2i(2, 2))
	var same := true
	for y in range(a.height):
		for x in range(a.width):
			var c := Vector2i(x, y)
			if a.get_content(c) != b.get_content(c) or a.get_payload(c) != b.get_payload(c):
				same = false
	check(same, "ten sam seed = te same potwory, skarby, sklepy i wyjście")


func test_flood_fill_stops_at_special_cells() -> void:
	var hazards: Array[Vector2i] = [Vector2i(4, 4)]
	var model := GridModel.new(5, 5, 1, 1)
	model.setup_layout(hazards)
	for y in range(5):
		model.set_cell_content(Vector2i(2, y), GridModel.Content.TREASURE, 10)
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


func test_player_level_up_gives_points() -> void:
	var player := _new_player()
	var need := player.get_exp_to_next_level()
	var levels: Array[int] = []
	player.leveled_up.connect(func(l: int) -> void: levels.append(l))
	player.take_damage(10)
	player.add_experience(need + 1)
	check_eq(player.level, 2, "awans na 2")
	check_eq(player.experience, 1, "nadwyżka EXP zostaje")
	check_eq(player.attribute_points, BASE_PLAYER.attribute_points_per_level, "punkty atrybutów")
	check_eq(player.hp, player.get_max_hp(), "pełne HP po awansie")
	check_eq(levels, [2] as Array[int], "sygnał leveled_up")


func test_player_damage_and_heal() -> void:
	var player := _new_player()
	player.take_damage(1000)
	check_eq(player.hp, 0, "HP nie spada poniżej 0")
	check(player.is_dead(), "martwy")
	check_eq(player.heal(5), 5, "leczenie zwraca odzyskane HP")
	check_eq(player.heal(1000), player.get_max_hp() - 5, "leczenie do max HP")


func test_monster_scaling() -> void:
	var data: MonsterData = DATABASE.monsters[1]
	var weak := data.create_instance(1)
	var strong := data.create_instance(5)
	check_eq(weak.max_hp, data.max_hp, "moc 1 = statystyki bazowe")
	check(strong.max_hp > weak.max_hp, "więcej HP przy większej mocy")
	check(strong.gold_reward >= weak.gold_reward, "lepsze nagrody przy większej mocy")
	check(UiText.t(data.name_key) != String(data.name_key), "nazwa potwora ma tekst w UiText")


func test_floor_config_rpg_values() -> void:
	var config: FloorConfig = DEFAULT_CONFIG
	check_eq(DATABASE.get_monsters_for_floor(1).size(), 3, "na 1. piętrze szczur, goblin i szlam")
	check_eq(DATABASE.get_monsters_for_floor(5).size(), 6, "na 5. piętrze wszystkie potwory")
	# Nowe potwory dopisane na końcu listy: indeksy w pulach pięter (payload pól w zapisach) bez zmian
	check_eq(DATABASE.get_monsters_for_floor(5)[3].id, &"orc", "kolejność istniejących potworów zachowana")
	check(config.get_trap_damage(10) > config.get_trap_damage(1), "pułapki mocniejsze głębiej")
	var g1 := config.get_treasure_gold_range(1)
	var g9 := config.get_treasure_gold_range(9)
	check(g1.x <= g1.y, "poprawny zakres złota")
	check(g9.y > g1.y, "skarby cenniejsze głębiej")


func test_monster_art_assigned() -> void:
	for m: MonsterData in DATABASE.monsters:
		if m.id in [&"skeleton", &"slime", &"ghoul"]:
			check(m.texture != null and m.battle_sheet != null, "grafika potwora %s" % m.id)
			check(m.battle_sheet.get_width() == m.battle_sheet.get_height() * m.battle_frames, "klatki sheetu %s" % m.id)


func test_database_texts_exist() -> void:
	for item: ItemData in DATABASE.items:
		check(UiText.t(item.name_key) != String(item.name_key), "nazwa przedmiotu %s" % item.id)
		check(UiText.t(item.desc_key) != String(item.desc_key), "opis przedmiotu %s" % item.id)
	for m: CraftingMaterial in DATABASE.materials:
		check(UiText.t(m.name_key) != String(m.name_key), "nazwa surowca %s" % m.id)
