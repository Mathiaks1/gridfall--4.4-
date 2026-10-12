class_name GameFlow
extends RefCounted
## Przejścia między scenami (menu ↔ gra) i przekazanie prośby o wczytanie zapisu.

const MAIN_MENU_SCENE := "res://scenes/menu/MainMenu.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"

static var _continue_requested: bool = false


static func new_game(tree: SceneTree) -> void:
	_continue_requested = false
	tree.change_scene_to_file(GAME_SCENE)


static func continue_game(tree: SceneTree) -> void:
	_continue_requested = true
	tree.change_scene_to_file(GAME_SCENE)


static func to_main_menu(tree: SceneTree) -> void:
	_continue_requested = false
	tree.change_scene_to_file(MAIN_MENU_SCENE)


## Zwraca true tylko raz po continue_game().
static func consume_continue_request() -> bool:
	var requested := _continue_requested
	_continue_requested = false
	return requested
