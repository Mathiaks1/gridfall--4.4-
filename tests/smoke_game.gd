extends SceneTree
## Test dymny sceny gry: przechodzi przez ekrany i przepływy UI, wyłapuje błędy wykonania.
## Uruchomienie: godot --headless --path . -s res://tests/smoke_game.gd
## Ten skrypt kompiluje się przed autoloadami, więc właściwy test (smoke_runner.gd) ładujemy w trakcie działania.


func _initialize() -> void:
	var runner: Node = load("res://tests/smoke_runner.gd").new()
	root.add_child.call_deferred(runner)
