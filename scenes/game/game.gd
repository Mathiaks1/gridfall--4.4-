extends Control
## Przebieg runu. Faza 1: jedno piętro sapera, porażka na zagrożeniu, wygrana po oczyszczeniu, restart.
## Faza 2: tu dojdą Player, walka, przejście na kolejne piętro.

@export var floor_config: FloorConfig
## 0 = losowy seed przy każdym runie; inna wartość = powtarzalna plansza (debug / testy).
@export var fixed_seed: int = 0
@export var result_delay: float = 0.8

var _floor_number: int = 1
var _run_seed: int = 0
## Unieważnia opóźnione callbacki z poprzedniego runu (np. restart w trakcie animacji porażki).
var _run_token: int = 0

@onready var _grid: GridManager = %GridManager
@onready var _hud: Hud = %Hud
@onready var _game_over: GameOverScreen = %GameOverScreen


func _ready() -> void:
	EventBus.hazard_triggered.connect(_on_hazard_triggered)
	EventBus.grid_cleared.connect(_on_grid_cleared)
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
	_floor_number = 1
	_game_over.hide()
	_grid.setup(GridModel.create_for_floor(floor_config, _floor_number, _floor_seed()))
	_hud.set_floor(_floor_number)
	EventBus.run_started.emit(_run_seed)


## Seed piętra wyprowadzony z seeda runu — każde piętro inne, cały run powtarzalny.
func _floor_seed() -> int:
	return hash([_run_seed, _floor_number])


func _on_hazard_triggered(_cell: Vector2i) -> void:
	_grid.show_solution()
	_show_result_delayed(false)


func _on_grid_cleared() -> void:
	_show_result_delayed(true)


func _show_result_delayed(won: bool) -> void:
	var token := _run_token
	await get_tree().create_timer(result_delay).timeout
	if token != _run_token:
		return
	_game_over.show_result(won, UiText.t(&"result_info") % [_floor_number, _run_seed])
