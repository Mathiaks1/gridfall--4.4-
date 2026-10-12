extends Node
## Narzędzie podglądu grafiki (nie test): uruchamia grę w oknie, odsłania przykładowe pola,
## zapisuje zrzuty planszy i ekranu walki do art_src/previews/.
##   godot --path . res://tests/CaptureScreens.tscn

const OUT := "res://art_src/previews/"

var _game: Node


func _ready() -> void:
	_game = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	add_child(_game)
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _run() -> void:
	await _wait(10)
	var grid: GridManager = _game.get("_grid")
	var model := grid.model
	var start := Vector2i(model.width / 2, model.height / 2)
	grid._on_action_triggered(GridInput.Action.REVEAL, start)
	model = grid.model
	await _wait(5)

	# Pokaż po jednym polu każdego rodzaju; dwa zagrożenia oflaguj, jedno rozpatrz.
	var shown := {}
	var monster_cell := GridModel.INVALID_CELL
	var flagged := 0
	for y in range(model.height):
		for x in range(model.width):
			var c := Vector2i(x, y)
			if model.get_state(c) != GridModel.CellState.HIDDEN:
				continue
			var content := model.get_content(c)
			if content == GridModel.Content.MONSTER:
				var data: MonsterData = _game.database.get_monsters_for_floor(_game.floor_number)[model.get_payload(c)]
				if data.texture and monster_cell == GridModel.INVALID_CELL:
					monster_cell = c
					model.reveal(c)
				elif flagged < 2:
					model.toggle_flag(c)
					flagged += 1
				elif not shown.has(&"defeated"):
					shown[&"defeated"] = true
					model.reveal(c)
					model.resolve(c)
			elif content != GridModel.Content.EMPTY and content != GridModel.Content.TRAP and not shown.has(content):
				shown[content] = true
				model.reveal(c)
	grid._refresh_all()
	await _wait(30)
	_save(OUT + "ingame_board.png")

	if monster_cell != GridModel.INVALID_CELL:
		_game.call("_start_combat", monster_cell)
		await _wait(20)
		_save(OUT + "ingame_combat.png")
	get_tree().quit()


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path, " ", img.get_size())
