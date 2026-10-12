extends "res://tests/test_case.gd"
## Testy Fazy 3: atrybuty, ekwipunek, sklep, kowal, walka turowa, przedmioty na planszy, zapis.

const DEFAULT_CONFIG := preload("res://data/default_floor_config.tres")
const DATABASE := preload("res://data/game_database.tres")
const BASE_PLAYER := preload("res://data/player_base_stats.tres")
const SMITH_CONFIG := preload("res://data/blacksmith_config.tres")


func _new_player() -> PlayerStats:
	var p := BASE_PLAYER.duplicate() as PlayerStats
	p.start_run()
	return p


func _item(id: StringName) -> ItemData:
	return DATABASE.get_item(id)


func _monster(hp: int, attack: int, defense: int) -> MonsterInstance:
	var m := MonsterInstance.new()
	m.data = DATABASE.monsters[0]
	m.max_hp = hp
	m.hp = hp
	m.attack = attack
	m.defense = defense
	return m


func _rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


# --- Atrybuty ----------------------------------------------------------------

func test_starting_player() -> void:
	var p := _new_player()
	check_eq(p.get_max_hp(), 30, "25 + 1 Witalność × 5")
	check_eq(p.get_attack(), 5, "3 + 1 Siła + sztylet 1")
	check_eq(p.get_defense(), 1, "1 + kurta 0")
	check_eq(p.inventory.weapon.data.id, &"dagger", "sztylet założony")
	check_eq(p.inventory.armor.data.id, &"cloth_armor", "kurta założona")
	check_eq(p.inventory.get_count(_item(&"potion_small")), 1, "mikstura w plecaku")
	check_eq(p.hp, p.get_max_hp(), "pełne HP")


func test_attribute_effects() -> void:
	var p := _new_player()
	p.attribute_points = 10
	var alloc := PackedInt32Array([2, 2, 2, 2, 2])
	check(p.apply_attribute_points(alloc), "rozdanie punktów")
	check_eq(p.attribute_points, 0, "punkty zużyte")
	check_eq(p.get_attack(), 7, "Siła 3 → ATK 7")
	check_eq(p.get_max_hp(), 40, "Witalność 3 → 40 HP")
	check_eq(p.hp, 40, "Witalność podnosi też bieżące HP")
	check(is_equal_approx(p.get_crit_chance(), 0.09), "Szczęście 3 → 9% krytyka")
	check(is_equal_approx(p.get_price_multiplier(), 0.91), "Charyzma 3 → ceny 91%")
	check(is_equal_approx(p.get_item_power_multiplier(), 1.3), "Inteligencja 3 → przedmioty 130%")
	check_eq(p.get_scry_radius_bonus(), 0, "Inteligencja 3 → brak bonusu promienia")


func test_attribute_points_validation() -> void:
	var p := _new_player()
	p.attribute_points = 2
	check(not p.apply_attribute_points(PackedInt32Array([3, 0, 0, 0, 0])), "za dużo punktów")
	check(not p.apply_attribute_points(PackedInt32Array([-1, 0, 0, 0, 0])), "ujemne punkty")
	check_eq(p.get_attribute(PlayerStats.Attribute.STRENGTH), 1, "bez zmian")


# --- Ekwipunek ---------------------------------------------------------------

func test_inventory_stacks_and_equip() -> void:
	var p := _new_player()
	var inv := p.inventory
	var potion := _item(&"potion_small")
	inv.add_item(potion, 2)
	check_eq(inv.get_count(potion), 3, "mikstury się stackują")
	check(inv.remove_consumable(potion, 3), "usunięcie stosu")
	check_eq(inv.get_count(potion), 0, "stos pusty")
	check(not inv.remove_consumable(potion), "nie można usunąć czegoś, czego nie ma")

	inv.add_item(_item(&"sword"))
	check_eq(inv.gear.size(), 1, "miecz trafia do plecaka (slot zajęty)")
	check(inv.equip(inv.gear[0]), "zakładanie miecza")
	check_eq(inv.weapon.data.id, &"sword", "miecz założony")
	check_eq(inv.gear[0].data.id, &"dagger", "sztylet wraca do plecaka")
	check_eq(p.get_attack(), 7, "ATK z mieczem: 3 + 1 + 3")


func test_materials() -> void:
	var inv := Inventory.new()
	inv.add_material(&"iron_ore", 3)
	inv.add_material(&"iron_ore")
	check_eq(inv.get_material_count(&"iron_ore"), 4, "surowce się stackują")
	check(inv.has_materials({&"iron_ore": 4}), "wystarczy rudy")
	check(not inv.has_materials({&"iron_ore": 1, &"magic_crystal": 1}), "brak kryształu")
	check(inv.remove_materials({&"iron_ore": 4}), "zużycie")
	check_eq(inv.get_material_count(&"iron_ore"), 0, "ruda zużyta")


# --- Sklep i kowal -------------------------------------------------------------

func test_shop_prices_and_buying() -> void:
	var p := _new_player()
	var sword := _item(&"sword")
	var price := Economy.buy_price(sword, 1, p, DEFAULT_CONFIG)
	check_eq(price, roundi(45 * 0.97), "cena z Charyzmą 1")
	check(Economy.buy_price(sword, 5, p, DEFAULT_CONFIG) > price, "głębiej drożej")
	check(not Economy.buy(p, sword, price), "brak złota")
	p.add_gold(100)
	check(Economy.buy(p, sword, price), "kupno")
	check_eq(p.gold, 100 - price, "złoto pobrane")
	check_eq(p.inventory.gear.size(), 1, "miecz w plecaku")
	var sold := p.inventory.gear[0]
	check(Economy.sell_gear(p, sold, DEFAULT_CONFIG), "sprzedaż")
	check_eq(p.gold, 100 - price + Economy.sell_price(sword, 0, DEFAULT_CONFIG), "złoto za sprzedaż")


func test_blacksmith_upgrade() -> void:
	var p := _new_player()
	var dagger := p.inventory.weapon
	check(Blacksmith.can_upgrade(dagger, SMITH_CONFIG), "można ulepszyć")
	check(not Blacksmith.can_afford(p, dagger, SMITH_CONFIG), "brak złota i rudy")
	p.add_gold(15)
	check(not Blacksmith.upgrade(p, dagger, SMITH_CONFIG), "brak rudy")
	p.inventory.add_material(&"iron_ore", 2)
	check(Blacksmith.upgrade(p, dagger, SMITH_CONFIG), "ulepszenie")
	check_eq(dagger.upgrade_level, 1, "sztylet +1")
	check_eq(p.gold, 0, "złoto pobrane")
	check_eq(p.inventory.get_material_count(&"iron_ore"), 0, "ruda pobrana")
	check_eq(p.get_attack(), 6, "ATK rośnie po ulepszeniu")
	check_eq(dagger.get_display_name(), "Sztylet +1", "nazwa z poziomem")
	dagger.upgrade_level = SMITH_CONFIG.max_upgrade_level
	check(not Blacksmith.can_upgrade(dagger, SMITH_CONFIG), "limit poziomu")


# --- Walka -------------------------------------------------------------------

func test_combat_attack_until_win() -> void:
	var p := _new_player()
	p.attributes[PlayerStats.Attribute.LUCK] = 0  # bez krytyków — wynik deterministyczny
	var session := CombatSession.new(p, _monster(10, 4, 1), _rng(1))
	session.auto_resolve()
	# ATK 5 - DEF 1 = 4 na cios → 3 ciosy; potwór 4 - 1 = 3 obrażeń, uderza 2 razy
	check_eq(session.outcome, CombatSession.Outcome.WON, "wygrana")
	check_eq(session.rounds, 3, "3 rundy")
	check_eq(session.damage_taken, 6, "obrażenia gracza")
	check_eq(p.hp, p.get_max_hp() - 6, "HP gracza zmniejszone")
	check(not session.take_messages().is_empty(), "komunikaty walki")


func test_combat_loss() -> void:
	var p := _new_player()
	var session := CombatSession.new(p, _monster(500, 50, 50), _rng(1))
	session.auto_resolve()
	check_eq(session.outcome, CombatSession.Outcome.LOST, "przegrana")
	check(p.is_dead(), "gracz martwy")


func test_combat_crits_are_deterministic() -> void:
	var results: Array[int] = []
	for i in range(2):
		var p := _new_player()
		p.attributes[PlayerStats.Attribute.LUCK] = 10
		var m := _monster(1000, 0, 0)
		var session := CombatSession.new(p, m, _rng(77))
		for r in range(20):
			session.attack()
		results.append(m.hp)
	check_eq(results[0], results[1], "ten sam seed RNG = te same krytyki")
	check(results[0] < 1000 - 20 * 5, "przy Szczęściu 10 zdarzają się krytyki")


func test_combat_items() -> void:
	var p := _new_player()
	var grenade := _item(&"grenade")
	var scroll := _item(&"scroll_return")
	p.inventory.add_item(grenade)
	p.inventory.add_item(scroll)
	var m := _monster(100, 2, 0)
	var session := CombatSession.new(p, m, _rng(3))
	check(session.use_item(grenade), "granat użyty")
	check_eq(m.hp, 100 - roundi(12 * 1.1), "granat: 12 × (1 + 0.1 INT)")
	check_eq(p.inventory.get_count(grenade), 0, "granat zużyty")
	check(not session.use_item(grenade), "nie ma już granatu")
	check(not session.use_item(_item(&"scroll_scry")), "zwój odkrycia nie działa w walce")
	check(session.use_item(scroll), "zwój powrotu")
	check_eq(session.outcome, CombatSession.Outcome.FLED, "pewna ucieczka")


func test_combat_flee_chance() -> void:
	var fled := 0
	for s in range(200):
		var p := _new_player()
		var session := CombatSession.new(p, _monster(100, 1, 0), _rng(s))
		session.flee()
		if session.outcome == CombatSession.Outcome.FLED:
			fled += 1
	# Szansa 0.35 + 0.05 = 40%
	check(fled > 50 and fled < 110, "ucieczka udaje się w ok. 40%% prób (jest %d/200)" % fled)


# --- Przedmioty na planszy -----------------------------------------------------

func test_scry_flags_hazards_and_reveals_safe() -> void:
	var hazards: Array[Vector2i] = [Vector2i(1, 1), Vector2i(4, 4)]
	var model := GridModel.new(5, 5, 2, 1)
	model.setup_layout(hazards)
	var changed := model.scry(Vector2i(1, 1), 1)
	check_eq(model.get_state(Vector2i(1, 1)), GridModel.CellState.FLAGGED, "zagrożenie oflagowane")
	check_eq(model.get_state(Vector2i(0, 0)), GridModel.CellState.REVEALED, "bezpieczne pole odkryte")
	check_eq(model.get_state(Vector2i(4, 4)), GridModel.CellState.HIDDEN, "poza zasięgiem bez zmian")
	check(not model.has_exploded(), "zwój nigdy nie uruchamia zagrożeń")
	check(changed.has(Vector2i(1, 1)), "flaga w zmienionych polach")
	check_eq(model.get_flag_count(), 1, "licznik flag")


func test_blast_destroys_hazards() -> void:
	var hazards: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 4)]
	var model := GridModel.new(5, 5, 3, 1)
	model.setup_layout(hazards)
	model.toggle_flag(Vector2i(2, 1))
	var destroyed: Array[Vector2i] = []
	model.blast(Vector2i(1, 1), 1, destroyed)
	check_eq(destroyed.size(), 2, "zniszczone dwa zagrożenia")
	check(model.is_resolved(Vector2i(1, 1)) and model.is_resolved(Vector2i(2, 1)), "zagrożenia rozpatrzone")
	check_eq(model.get_state(Vector2i(2, 1)), GridModel.CellState.REVEALED, "flaga zastąpiona odsłonięciem")
	check_eq(model.get_flag_count(), 0, "flaga zdjęta z licznika")
	check_eq(model.get_marked_hazard_count(), 2, "zniszczone liczą się jako znane")
	check_eq(model.get_state(Vector2i(0, 0)), GridModel.CellState.REVEALED, "bezpieczne pole odkryte")
	check(not model.has_exploded(), "wybuch nie uruchamia zagrożeń")


# --- Zapis -------------------------------------------------------------------

func test_grid_model_round_trip() -> void:
	var model := GridModel.create_for_floor(DEFAULT_CONFIG, DATABASE, 4, 1234)
	model.reveal(Vector2i(3, 3))
	model.toggle_flag(Vector2i(0, 0))
	var copy := GridModel.from_dict(model.to_dict())
	check_eq(copy.to_dict(), model.to_dict(), "model po zapisie identyczny")
	check_eq(copy.get_revealed_safe_count(), model.get_revealed_safe_count(), "licznik odkrytych")


func test_player_round_trip() -> void:
	var p := _new_player()
	p.add_gold(77)
	p.attribute_points = 3
	p.attributes[PlayerStats.Attribute.LUCK] = 4
	p.inventory.add_item(_item(&"sword"))
	p.inventory.weapon.upgrade_level = 2
	p.inventory.add_material(&"magic_crystal", 2)
	var copy := BASE_PLAYER.duplicate() as PlayerStats
	copy.load_from_dict(p.to_dict(), DATABASE)
	check_eq(copy.to_dict(), p.to_dict(), "gracz po zapisie identyczny")
	check_eq(copy.get_attack(), p.get_attack(), "ATK zgodny (ulepszenia + ekwipunek)")
	check_eq(copy.inventory.get_count(_item(&"potion_small")), 1, "przedmioty użytkowe")


func test_save_system_file_round_trip() -> void:
	var previous := SaveSystem.save_path
	SaveSystem.save_path = "user://test_savegame.dat"
	SaveSystem.delete()
	check(not SaveSystem.has_save(), "brak zapisu na start")
	var data := {"floor_number": 3, "cells": PackedByteArray([1, 2, 3]), "cell": Vector2i(2, 5), "id": &"sword"}
	check(SaveSystem.write(data), "zapis")
	check(SaveSystem.has_save(), "plik istnieje")
	var loaded := SaveSystem.read()
	check_eq(loaded.get("floor_number"), 3, "int")
	check_eq(loaded.get("cells"), PackedByteArray([1, 2, 3]), "PackedByteArray")
	check_eq(loaded.get("cell"), Vector2i(2, 5), "Vector2i")
	check_eq(loaded.get("id"), &"sword", "StringName")
	SaveSystem.delete()
	check(not SaveSystem.has_save(), "zapis usunięty")
	SaveSystem.save_path = previous
