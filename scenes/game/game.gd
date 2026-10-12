extends Control
## Przebieg runu: piętra, gracz, reakcje na aktywowane pola (pułapka, walka, skarb, wyjście), śmierć i restart.

@export var floor_config: FloorConfig
## Wartości startowe bohatera; na każdy run tworzona jest kopia.
@export var base_player_stats: PlayerStats
## 0 = losowy seed przy każdym runie; inna wartość = powtarzalny run (debug / testy).
@export var fixed_seed: int = 0
@export var result_delay: float = 0.8

var player: PlayerStats
var floor_number: int = 1

var _run_seed: int = 0
## Unieważnia opóźnione callbacki z poprzedniego runu (np. restart w trakcie animacji porażki).
var _run_token: int = 0
var _exit_announced: bool = false

@onready var _grid: GridManager = %GridManager
@onready var _hud: Hud = %Hud
@onready var _game_over: GameOverScreen = %GameOverScreen


func _ready() -> void:
	EventBus.cell_activated.connect(_on_cell_activated)
	EventBus.cells_revealed.connect(_on_cells_revealed)
	_hud.restart_pressed.connect(start_run)
	_game_over.restart_requested.connect(start_run)
	start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_run"):
		start_run()
		get_viewport().set_input_as_handled()


func start_run() -> void:
	_run_token += 1
	_run_seed = fixed_seed if fixed_seed != 0 else randi()
	_game_over.hide()
	if player and player.leveled_up.is_connected(_on_player_leveled_up):
		player.leveled_up.disconnect(_on_player_leveled_up)
	player = base_player_stats.duplicate() as PlayerStats
	player.start_run()
	player.leveled_up.connect(_on_player_leveled_up)
	_hud.bind_player(player)
	EventBus.run_started.emit(_run_seed)
	_start_floor(1)
	EventBus.message_logged.emit(UiText.t(&"log_run_start") % floor_number)


func _start_floor(number: int) -> void:
	floor_number = number
	_exit_announced = false
	_grid.setup(GridModel.create_for_floor(floor_config, floor_number, _floor_seed()))
	EventBus.floor_started.emit(floor_number)


## Seed piętra wyprowadzony z seeda runu — każde piętro inne, cały run powtarzalny.
func _floor_seed() -> int:
	return hash([_run_seed, floor_number])


func _on_cell_activated(cell: Vector2i, content: GridModel.Content) -> void:
	match content:
		GridModel.Content.TRAP:
			_trigger_trap(cell)
		GridModel.Content.MONSTER:
			_fight_monster(cell)
		GridModel.Content.TREASURE:
			_collect_treasure(cell)
		GridModel.Content.EXIT:
			_descend()


func _trigger_trap(cell: Vector2i) -> void:
	var damage := floor_config.get_trap_damage(floor_number)
	player.take_damage(damage)
	_grid.resolve_cell(cell)
	EventBus.message_logged.emit(UiText.t(&"log_trap") % damage)
	_check_death()


func _fight_monster(cell: Vector2i) -> void:
	var monster := _create_monster(_grid.model.get_payload(cell))
	var result := CombatResolver.resolve(player, monster)
	player.take_damage(result.damage_taken)
	if not result.won:
		EventBus.message_logged.emit(UiText.t(&"log_combat_lose") % monster.get_display_name())
		_check_death()
		return
	_grid.resolve_cell(cell)
	EventBus.message_logged.emit(UiText.t(&"log_combat_win") % [
		monster.get_display_name(), result.rounds, result.damage_taken, monster.gold_reward, monster.exp_reward,
	])
	player.add_gold(monster.gold_reward)
	# EXP na końcu — ewentualny komunikat o awansie pojawi się po komunikacie walki
	player.add_experience(monster.exp_reward)


func _create_monster(kind: int) -> MonsterInstance:
	var pool := floor_config.get_monsters_for_floor(floor_number)
	if pool.is_empty():
		push_error("FloorConfig: brak potworów dla piętra %d" % floor_number)
		return MonsterInstance.new()
	var data := pool[clampi(kind, 0, pool.size() - 1)]
	return data.create_instance(floor_config.get_monster_power(floor_number))


func _collect_treasure(cell: Vector2i) -> void:
	var gold := _grid.model.get_payload(cell)
	player.add_gold(gold)
	_grid.resolve_cell(cell)
	EventBus.message_logged.emit(UiText.t(&"log_treasure") % gold)


func _descend() -> void:
	var healed := player.heal(roundi(player.max_hp * floor_config.heal_on_descend))
	_start_floor(floor_number + 1)
	EventBus.message_logged.emit(UiText.t(&"log_descend") % [floor_number, healed])


func _on_cells_revealed(cells: Array[Vector2i]) -> void:
	if _exit_announced:
		return
	for c in cells:
		if _grid.model.get_content(c) == GridModel.Content.EXIT:
			_exit_announced = true
			EventBus.message_logged.emit(UiText.t(&"log_exit_found"))
			return


func _on_player_leveled_up(new_level: int) -> void:
	EventBus.message_logged.emit(UiText.t(&"log_level_up") % new_level)


func _check_death() -> void:
	if not player.is_dead():
		return
	_grid.show_solution()
	EventBus.player_died.emit()
	var token := _run_token
	await get_tree().create_timer(result_delay).timeout
	if token != _run_token:
		return
	_game_over.show_game_over(UiText.t(&"result_info") % [floor_number, player.level, player.gold, _run_seed])
