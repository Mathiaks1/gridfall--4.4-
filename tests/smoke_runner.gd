extends Node
## Właściwy test dymny sceny gry (wczytywany przez smoke_game.gd po rejestracji autoloadów).

## Ładowane w trakcie działania (nie preload), żeby autoloady były już zarejestrowane.
const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"

var _failures := PackedStringArray()


func _ready() -> void:
	SaveSystem.save_path = "user://smoke_savegame.dat"
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		print("  FAIL  ", message)
	else:
		print("  ok    ", message)


func _frames(n: int = 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _run() -> void:
	var game: Control = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	game.fixed_seed = 4242
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await _frames()

	var grid: GridManager = game.get_node("%GridManager")
	var player: PlayerStats = game.player
	var db: GameDatabase = game.database
	_check(player != null and grid.model != null, "run wystartował")

	# Pierwszy ruch: odkrycie środka
	grid._on_action_triggered(GridInput.Action.REVEAL, Vector2i(4, 4))
	_check(grid.model.is_generated and not grid.model.has_exploded(), "pierwszy klik bezpieczny")

	# Sklep
	player.add_gold(500)
	var shop: ShopScreen = game.get_node("%ShopScreen")
	var stock: Array[ItemData] = game._get_shop_stock(Vector2i(0, 0))
	_check(stock.size() == game.floor_config.shop_stock_size, "asortyment sklepu")
	shop.open_shop(player, stock, 1, game.floor_config)
	await _frames()
	var first: ItemData = stock[0]
	shop._on_buy(first, Economy.buy_price(first, 1, player, game.floor_config))
	_check(not stock.has(first), "zakup zdejmuje przedmiot z asortymentu")
	shop.close()

	# Kowal
	player.inventory.add_material(&"iron_ore", 5)
	var smith: BlacksmithScreen = game.get_node("%BlacksmithScreen")
	smith.open_blacksmith(player, game.blacksmith_config, db)
	await _frames()
	smith._on_upgrade(player.inventory.weapon)
	_check(player.inventory.weapon.upgrade_level == 1, "ulepszenie u kowala")
	smith.close()

	# Ekwipunek: mikstura i zwój odkrycia z wskazaniem pola
	var inventory_screen: InventoryScreen = game.get_node("%InventoryScreen")
	inventory_screen.open_inventory(player, db)
	await _frames()
	inventory_screen.close()
	player.take_damage(10)
	var hp_before := player.hp
	game._on_item_use_requested(db.get_item(&"potion_small"))
	_check(player.hp > hp_before, "mikstura leczy")
	var scroll := db.get_item(&"scroll_scry")
	var grenade := db.get_item(&"grenade")
	player.inventory.add_item(scroll)
	var scrolls := player.inventory.get_count(scroll)
	game._on_item_use_requested(scroll)
	_check(grid.is_targeting(), "zwój czeka na wskazanie pola")
	grid._on_action_triggered(GridInput.Action.REVEAL, Vector2i(0, 0))
	_check(not grid.is_targeting() and player.inventory.get_count(scroll) == scrolls - 1, "zwój zużyty po wskazaniu")
	player.inventory.add_item(grenade)
	var grenades := player.inventory.get_count(grenade)
	game._on_item_use_requested(grenade)
	grid._on_action_triggered(GridInput.Action.FLAG, Vector2i(0, 0))
	_check(not grid.is_targeting() and player.inventory.get_count(grenade) == grenades, "anulowanie granatu")
	game._on_item_use_requested(grenade)
	grid._on_action_triggered(GridInput.Action.REVEAL, Vector2i(8, 8))
	_check(player.inventory.get_count(grenade) == grenades - 1, "granat użyty na planszy")

	# Walka: znajdź nierozpatrzonego potwora
	var monster_cell := GridModel.INVALID_CELL
	for y in range(grid.model.height):
		for x in range(grid.model.width):
			var c := Vector2i(x, y)
			if grid.model.get_content(c) == GridModel.Content.MONSTER and not grid.model.is_resolved(c):
				monster_cell = c
	if monster_cell != GridModel.INVALID_CELL:
		var combat: CombatScreen = game.get_node("%CombatScreen")
		player.heal(999)
		game._on_cell_activated(monster_cell, GridModel.Content.MONSTER)
		await _frames()
		_check(combat.visible, "ekran walki otwarty")
		combat._on_items()
		combat._on_back()
		combat._on_auto()
		combat._on_continue()
		await _frames()
		_check(not combat.visible, "ekran walki zamknięty")
		_check(grid.model.is_resolved(monster_cell) or player.is_dead(), "potwór pokonany")
	else:
		print("  skip  brak potwora na planszy")

	# Awans
	if not player.is_dead():
		var level_screen: LevelUpScreen = game.get_node("%LevelUpScreen")
		level_screen.close()
		player.add_experience(player.get_exp_to_next_level())
		game._maybe_open_level_up()
		await _frames()
		_check(level_screen.visible, "ekran awansu otwarty")
		level_screen._on_add(0)
		level_screen._on_add(1)
		level_screen._on_confirm()
		_check(player.attribute_points == player.attribute_points_per_level - 2, "punkty rozdane")

		# Zapis i wczytanie
		var save: Dictionary = game._make_save()
		var gold := player.gold
		var revealed := grid.model.get_revealed_safe_count()
		_check(SaveSystem.write(save), "zapis")
		_check(game._load_run(SaveSystem.read()), "wczytanie")
		_check(game.player.gold == gold, "złoto po wczytaniu")
		_check(grid.model.get_revealed_safe_count() == revealed, "plansza po wczytaniu")
		_check(not SaveSystem.has_save(), "zapis skasowany po wczytaniu")

		# Pauza i opcje
		var pause: PauseMenu = game.get_node("%PauseMenu")
		game._open_pause()
		_check(pause.visible, "pauza otwarta")
		var options: OptionsScreen = game.get_node("%OptionsScreen")
		options.open_options()
		await _frames()
		options.close()
		pause.close()

		# Zejście piętro niżej
		game._descend()
		_check(game.floor_number == 2, "zejście na piętro 2")

	# Śmierć
	game.player.take_damage(9999)
	game._check_death()
	await get_tree().create_timer(game.result_delay + 0.2).timeout
	_check(game.get_node("%GameOverScreen").visible, "ekran końca gry")

	print("Smoke: %s" % ("OK" if _failures.is_empty() else "%d błędów" % _failures.size()))
	SaveSystem.delete()
	get_tree().quit(0 if _failures.is_empty() else 1)
