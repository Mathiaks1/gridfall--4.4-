extends Control
## Przebieg runu: piętra, gracz, reakcje na aktywowane pola (pułapka, walka, skarb, surowiec, sklep, kowal, wyjście),
## przedmioty, awanse, zapis „zapisz i wyjdź”, śmierć.

@export var floor_config: FloorConfig
@export var database: GameDatabase
@export var blacksmith_config: BlacksmithConfig
## Wartości startowe bohatera; na każdy run tworzona jest kopia.
@export var base_player_stats: PlayerStats
## 0 = losowy seed przy każdym runie; inna wartość = powtarzalny run (debug / testy).
@export var fixed_seed: int = 0
@export var result_delay: float = 0.8

var player: PlayerStats
var floor_number: int = 1
var monsters_killed: int = 0

var _run_seed: int = 0
## Unieważnia opóźnione callbacki z poprzedniego runu (np. restart w trakcie animacji porażki).
var _run_token: int = 0
var _run_over: bool = false
var _exit_announced: bool = false
var _level_up_pending: bool = false
## Losowość zdarzeń (krytyki, uniki, łupy) — deterministyczna względem seeda, zapisywana razem z runem.
var _rng := RandomNumberGenerator.new()
## Asortyment sklepów na piętrze: Vector2i -> Array[ItemData].
var _shop_stocks: Dictionary = {}
## Potwory, od których gracz uciekł (zachowują obrażenia): Vector2i -> MonsterInstance.
var _wounded_monsters: Dictionary = {}
var _combat_cell := GridModel.INVALID_CELL
var _targeting_item: ItemData
var _modals: Array[ModalScreen] = []

@onready var _grid: GridManager = %GridManager
@onready var _hud: Hud = %Hud
@onready var _game_over: GameOverScreen = %GameOverScreen
@onready var _combat_screen: CombatScreen = %CombatScreen
@onready var _shop_screen: ShopScreen = %ShopScreen
@onready var _blacksmith_screen: BlacksmithScreen = %BlacksmithScreen
@onready var _inventory_screen: InventoryScreen = %InventoryScreen
@onready var _level_up_screen: LevelUpScreen = %LevelUpScreen
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _options_screen: OptionsScreen = %OptionsScreen


func _ready() -> void:
	GameSettings.ensure_loaded()
	# Zamknięcie okna obsługujemy sami (autozapis)
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	_modals = [_combat_screen, _shop_screen, _blacksmith_screen, _inventory_screen, _level_up_screen, _pause_menu, _options_screen]
	for modal in _modals:
		modal.closed.connect(_on_modal_closed)

	EventBus.cell_activated.connect(_on_cell_activated)
	EventBus.cells_revealed.connect(_on_cells_revealed)
	_hud.inventory_pressed.connect(_open_inventory)
	_hud.points_pressed.connect(_open_level_up)
	_hud.menu_pressed.connect(_open_pause)
	_game_over.restart_requested.connect(start_run)
	_game_over.menu_requested.connect(_go_to_menu)
	_combat_screen.combat_finished.connect(_on_combat_finished)
	_inventory_screen.item_use_requested.connect(_on_item_use_requested)
	_pause_menu.options_requested.connect(_options_screen.open_options)
	_pause_menu.save_quit_requested.connect(_save_and_quit)
	_pause_menu.abandon_requested.connect(_abandon_run)
	_grid.icon_resolver = _get_cell_icon

	if not (GameFlow.consume_continue_request() and _load_run(SaveSystem.read())):
		start_run()


func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_autosave()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			# Android może ubić aplikację w tle — zapisujemy jak przy „zapisz i wyjdź”
			_autosave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_requested()


func _unhandled_input(event: InputEvent) -> void:
	if _is_modal_open() or _game_over.visible:
		return
	if event.is_action_pressed(&"restart_run"):
		start_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		if _grid.is_targeting():
			_grid.cancel_targeting()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


# --- Run i piętra --------------------------------------------------------------

func start_run() -> void:
	_run_token += 1
	_run_over = false
	_run_seed = fixed_seed if fixed_seed != 0 else randi()
	_close_all_modals()
	_game_over.hide()
	var new_player := base_player_stats.duplicate() as PlayerStats
	new_player.start_run()
	_set_player(new_player)
	monsters_killed = 0
	_level_up_pending = false
	# Permadeath: nowy run unieważnia stary zapis
	SaveSystem.delete()
	EventBus.run_started.emit(_run_seed)
	_start_floor(1)
	_log(UiText.t(&"log_run_start") % floor_number)


func _set_player(value: PlayerStats) -> void:
	if player and player.leveled_up.is_connected(_on_player_leveled_up):
		player.leveled_up.disconnect(_on_player_leveled_up)
	player = value
	player.leveled_up.connect(_on_player_leveled_up)
	_hud.bind_player(player)


func _start_floor(number: int) -> void:
	floor_number = number
	_exit_announced = false
	_shop_stocks.clear()
	_wounded_monsters.clear()
	_combat_cell = GridModel.INVALID_CELL
	_targeting_item = null
	_rng.seed = hash([_run_seed, floor_number, "events"])
	_grid.setup(GridModel.create_for_floor(floor_config, database, floor_number, _floor_seed()))
	EventBus.floor_started.emit(floor_number)


## Seed piętra wyprowadzony z seeda runu — każde piętro inne, cały run powtarzalny.
func _floor_seed() -> int:
	return hash([_run_seed, floor_number])


func _descend() -> void:
	var healed := player.heal(roundi(player.get_max_hp() * floor_config.heal_on_descend))
	_start_floor(floor_number + 1)
	_log(UiText.t(&"log_descend") % [floor_number, healed])


# --- Aktywacje pól -----------------------------------------------------------------

func _on_cell_activated(cell: Vector2i, content: int) -> void:
	if _run_over:
		return
	match content:
		GridModel.Content.TRAP:
			_trigger_trap(cell)
		GridModel.Content.MONSTER:
			_start_combat(cell)
		GridModel.Content.TREASURE:
			_collect_treasure(cell)
		GridModel.Content.RESOURCE:
			_collect_resource(cell)
		GridModel.Content.SHOP:
			_shop_screen.open_shop(player, _get_shop_stock(cell), floor_number, floor_config)
		GridModel.Content.BLACKSMITH:
			_blacksmith_screen.open_blacksmith(player, blacksmith_config, database)
		GridModel.Content.EXIT:
			_descend()
	_maybe_open_level_up()


func _trigger_trap(cell: Vector2i) -> void:
	_grid.resolve_cell(cell)
	if _rng.randf() < player.get_trap_dodge_chance():
		_log(UiText.t(&"log_trap_dodged"))
		return
	var damage := floor_config.get_trap_damage(floor_number)
	player.take_damage(damage)
	_log(UiText.t(&"log_trap") % damage)
	_check_death()


func _start_combat(cell: Vector2i) -> void:
	var monster := _wounded_monsters.get(cell) as MonsterInstance
	if monster == null:
		monster = _create_monster(_grid.model.get_payload(cell))
	_combat_cell = cell
	_combat_screen.start(CombatSession.new(player, monster, _rng))


func _on_combat_finished(session: CombatSession) -> void:
	var cell := _combat_cell
	_combat_cell = GridModel.INVALID_CELL
	match session.outcome:
		CombatSession.Outcome.WON:
			_wounded_monsters.erase(cell)
			_grid.resolve_cell(cell)
			_grant_monster_rewards(session.monster, true)
		CombatSession.Outcome.FLED:
			_wounded_monsters[cell] = session.monster
			_log(UiText.t(&"log_combat_fled") % session.monster.get_display_name())
		CombatSession.Outcome.LOST:
			_check_death()
	_maybe_open_level_up()


func _create_monster(kind: int) -> MonsterInstance:
	var pool := database.get_monsters_for_floor(floor_number)
	if pool.is_empty():
		push_error("GameDatabase: brak potworów dla piętra %d" % floor_number)
		return MonsterInstance.new()
	var data := pool[clampi(kind, 0, pool.size() - 1)]
	return data.create_instance(floor_config.get_monster_power(floor_number))


## Ikona konkretnego potwora / surowca na polu (payload = indeks w puli piętra); null = ikona ogólna.
func _get_cell_icon(cell: Vector2i) -> Texture2D:
	var model := _grid.model
	match model.get_content(cell):
		GridModel.Content.MONSTER:
			var pool := database.get_monsters_for_floor(floor_number)
			var kind := model.get_payload(cell)
			if kind >= 0 and kind < pool.size():
				return pool[kind].texture
		GridModel.Content.RESOURCE:
			var materials := database.get_materials_for_floor(floor_number)
			var index := model.get_payload(cell)
			if index >= 0 and index < materials.size():
				return materials[index].icon
	return null


## Nagrody za potwora; can_drop = szansa na surowiec (nie przy zabiciu granatem na planszy).
func _grant_monster_rewards(monster: MonsterInstance, can_drop: bool) -> void:
	monsters_killed += 1
	var gold := roundi(monster.gold_reward * player.get_loot_multiplier())
	player.add_gold(gold)
	_log(UiText.t(&"log_combat_win") % [monster.get_display_name(), gold, monster.exp_reward])
	if can_drop and monster.data and _roll(monster.data.material_drop_chance * player.get_loot_multiplier()):
		_give_material(_roll_material(), 1)
	# EXP na końcu — komunikat o awansie pojawi się po komunikacie o nagrodzie
	player.add_experience(monster.exp_reward)


func _collect_treasure(cell: Vector2i) -> void:
	var gold := roundi(_grid.model.get_payload(cell) * player.get_loot_multiplier())
	player.add_gold(gold)
	_grid.resolve_cell(cell)
	_log(UiText.t(&"log_treasure") % gold)
	var loot_mult := player.get_loot_multiplier()
	if _roll(floor_config.treasure_item_chance * loot_mult):
		var items := database.get_treasure_items(floor_number)
		if not items.is_empty():
			var item := items[_rng.randi_range(0, items.size() - 1)]
			player.inventory.add_item(item)
			_log(UiText.t(&"log_found_item") % item.get_display_name())
	if _roll(floor_config.treasure_material_chance * loot_mult):
		_give_material(_roll_material(), 1)


func _collect_resource(cell: Vector2i) -> void:
	var materials := database.get_materials_for_floor(floor_number)
	var index := _grid.model.get_payload(cell)
	_grid.resolve_cell(cell)
	if index < 0 or index >= materials.size():
		return
	# Szczęście daje szansę na dodatkową sztukę
	var amount := 1 + (1 if _roll(player.get_loot_multiplier() - 1.0) else 0)
	_give_material(materials[index], amount)


func _give_material(material: CraftingMaterial, amount: int) -> void:
	if material == null:
		return
	player.inventory.add_material(material.id, amount)
	_log(UiText.t(&"log_found_material") % [material.get_display_name(), amount])


func _roll_material() -> CraftingMaterial:
	var materials := database.get_materials_for_floor(floor_number)
	var index := GameDatabase.pick_weighted(database.get_material_weights(floor_number), _rng)
	return materials[index] if index >= 0 else null


func _roll(chance: float) -> bool:
	return _rng.randf() < chance


## Asortyment sklepu: deterministyczny względem seeda i pola, zakupy go uszczuplają.
func _get_shop_stock(cell: Vector2i) -> Array[ItemData]:
	if _shop_stocks.has(cell):
		return _shop_stocks[cell]
	var pool := database.get_shop_items(floor_number)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_run_seed, floor_number, cell])
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var stock: Array[ItemData] = pool.slice(0, floor_config.shop_stock_size)
	_shop_stocks[cell] = stock
	return stock


func _on_cells_revealed(cells: Array[Vector2i]) -> void:
	if _exit_announced:
		return
	for c in cells:
		if _grid.model.get_content(c) == GridModel.Content.EXIT:
			_exit_announced = true
			_log(UiText.t(&"log_exit_found"))
			return


# --- Przedmioty na planszy -----------------------------------------------------------

func _on_item_use_requested(item: ItemData) -> void:
	if _run_over:
		return
	match item.effect:
		ItemData.Effect.HEAL:
			if player.hp >= player.get_max_hp():
				_log(UiText.t(&"log_hp_full"))
				return
			if player.inventory.remove_consumable(item):
				_log(UiText.t(&"log_heal") % player.heal(roundi(item.power * player.get_item_power_multiplier())))
		ItemData.Effect.SCRY, ItemData.Effect.GRENADE:
			_targeting_item = item
			_grid.begin_targeting(_on_target_selected, _on_target_cancelled)
			_log(UiText.t(&"log_choose_target") % item.get_display_name())


func _on_target_selected(cell: Vector2i) -> void:
	var item := _targeting_item
	_targeting_item = null
	if item == null or not player.inventory.remove_consumable(item):
		return
	match item.effect:
		ItemData.Effect.SCRY:
			_grid.apply_external_changes(_grid.model.scry(cell, item.radius + player.get_scry_radius_bonus()))
			_log(UiText.t(&"log_scry"))
		ItemData.Effect.GRENADE:
			var destroyed: Array[Vector2i] = []
			_grid.apply_external_changes(_grid.model.blast(cell, item.radius, destroyed))
			_log(UiText.t(&"log_grenade") % destroyed.size())
			for c in destroyed:
				if _grid.model.get_content(c) != GridModel.Content.MONSTER:
					continue
				var monster := _wounded_monsters.get(c) as MonsterInstance
				_wounded_monsters.erase(c)
				_grant_monster_rewards(monster if monster else _create_monster(_grid.model.get_payload(c)), false)
	_maybe_open_level_up()


func _on_target_cancelled() -> void:
	_targeting_item = null
	_log(UiText.t(&"log_target_cancelled"))


# --- Ekrany i awanse -------------------------------------------------------------------

func _on_player_leveled_up(new_level: int) -> void:
	_log(UiText.t(&"log_level_up") % new_level)
	_level_up_pending = true


func _maybe_open_level_up() -> void:
	if _level_up_pending and not _run_over and not _is_modal_open() and player.attribute_points > 0:
		_level_up_pending = false
		_level_up_screen.open_level_up(player)


func _open_level_up() -> void:
	if not _is_modal_open() and player.attribute_points > 0:
		_level_up_screen.open_level_up(player)


func _open_inventory() -> void:
	if _is_modal_open() or _run_over:
		return
	_grid.cancel_targeting()
	_inventory_screen.open_inventory(player, database)


func _open_pause() -> void:
	if _is_modal_open() or _run_over:
		return
	_grid.cancel_targeting()
	_pause_menu.open_modal()


func _on_modal_closed() -> void:
	_maybe_open_level_up()


func _is_modal_open() -> bool:
	for modal in _modals:
		if modal.visible:
			return true
	return false


func _close_all_modals() -> void:
	for modal in _modals:
		modal.hide()


func _on_back_requested() -> void:
	if _run_over:
		return
	# Zamknij najwyżej położony ekran (ostatni w drzewie), w walce ignoruj
	for i in range(_modals.size() - 1, -1, -1):
		var modal := _modals[i]
		if modal.visible:
			if modal.closable:
				modal.close()
			return
	if _grid.is_targeting():
		_grid.cancel_targeting()
	else:
		_open_pause()


func _log(text: String) -> void:
	EventBus.message_logged.emit(text)


# --- Śmierć, zapis, wyjście ------------------------------------------------------------------

func _check_death() -> void:
	if not player.is_dead() or _run_over:
		return
	_run_over = true
	SaveSystem.delete()
	_grid.show_solution()
	EventBus.player_died.emit()
	var token := _run_token
	await get_tree().create_timer(result_delay).timeout
	if token != _run_token:
		return
	_close_all_modals()
	_game_over.show_game_over(UiText.t(&"result_info") % [floor_number, player.level, player.gold, monsters_killed, _run_seed])


func _autosave() -> void:
	if player and not _run_over and not player.is_dead():
		SaveSystem.write(_make_save())


func _save_and_quit() -> void:
	_autosave()
	_go_to_menu()


func _abandon_run() -> void:
	SaveSystem.delete()
	_go_to_menu()


func _go_to_menu() -> void:
	GameFlow.to_main_menu(get_tree())


func _make_save() -> Dictionary:
	var shops := {}
	for cell: Vector2i in _shop_stocks:
		var ids: Array[StringName] = []
		for item: ItemData in _shop_stocks[cell]:
			ids.append(item.id)
		shops[cell] = ids
	var wounded := {}
	for cell: Vector2i in _wounded_monsters:
		wounded[cell] = (_wounded_monsters[cell] as MonsterInstance).to_dict()
	# Walka w toku zapisuje się jak ucieczka: ranny potwór czeka na polu
	var session := _combat_screen.get_session()
	if _combat_cell != GridModel.INVALID_CELL and session:
		wounded[_combat_cell] = session.monster.to_dict()
	return {
		"run_seed": _run_seed,
		"floor_number": floor_number,
		"monsters_killed": monsters_killed,
		"exit_announced": _exit_announced,
		"rng_state": _rng.state,
		"player": player.to_dict(),
		"grid": _grid.model.to_dict(),
		"shops": shops,
		"wounded": wounded,
	}


## Odtwarza run z zapisu i kasuje zapis (permadeath). Zwraca false, gdy zapis jest pusty.
func _load_run(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	SaveSystem.delete()
	_run_token += 1
	_run_over = false
	_run_seed = int(data["run_seed"])
	floor_number = int(data["floor_number"])
	monsters_killed = int(data.get("monsters_killed", 0))
	_exit_announced = bool(data.get("exit_announced", false))
	_level_up_pending = false
	_combat_cell = GridModel.INVALID_CELL
	_targeting_item = null

	var loaded_player := base_player_stats.duplicate() as PlayerStats
	loaded_player.load_from_dict(data["player"], database)
	_set_player(loaded_player)
	_rng.state = int(data["rng_state"])

	_shop_stocks.clear()
	var shops: Dictionary = data.get("shops", {})
	for cell: Vector2i in shops:
		var stock: Array[ItemData] = []
		for id: StringName in shops[cell]:
			var item := database.get_item(id)
			if item:
				stock.append(item)
		_shop_stocks[cell] = stock

	_wounded_monsters.clear()
	var wounded: Dictionary = data.get("wounded", {})
	for cell: Vector2i in wounded:
		var entry: Dictionary = wounded[cell]
		var monster_data := database.get_monster(entry.get("id", &""))
		if monster_data:
			var monster := monster_data.create_instance(floor_config.get_monster_power(floor_number))
			monster.hp = int(entry.get("hp", monster.max_hp))
			_wounded_monsters[cell] = monster

	EventBus.run_started.emit(_run_seed)
	_grid.setup(GridModel.from_dict(data["grid"]))
	EventBus.floor_started.emit(floor_number)
	_log(UiText.t(&"log_run_loaded") % floor_number)
	return true
