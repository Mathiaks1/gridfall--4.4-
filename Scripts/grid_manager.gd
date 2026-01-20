# GridManager.gd
extends Node2D

@export var grid_width = 10
@export var grid_height = 10
@export var num_mines = 15
@export var tile_scene: PackedScene
@export var tile_size = 64

var tiles = []
var first_click = true

func _ready():
    generate_grid()

func generate_grid():
    # Wyczyść starą siatkę
    for child in get_children():
        if child is Tile:
            child.queue_free()
    tiles.clear()
    
    # Stwórz nową siatkę
    for x in range(grid_width):
        tiles.append([])
        for y in range(grid_height):
            var tile_instance = tile_scene.instantiate()
            add_child(tile_instance)
            tile_instance.position = Vector2(x * tile_size, y * tile_size)
            tile_instance.grid_coords = Vector2i(x, y)
            tile_instance.tile_revealed.connect(_on_tile_revealed)
            tiles[x].append(tile_instance)
    
    first_click = true

func _on_tile_revealed(coords: Vector2i, is_mine_hit: bool):
    if first_click:
        # Pierwsze kliknięcie - bezpieczne rozmieszczenie min
        place_mines_safely(coords)
        first_click = false
        
        # Odkryj pole i sąsiadów
        reveal_tile_recursive(coords.x, coords.y)
    elif is_mine_hit:
        # Trafiono na minę/potwora - rozpocznij walkę
        start_battle(coords)
    else:
        # Normalne pole - odkryj rekurencyjnie jeśli puste
        var tile = get_tile_at_coords(coords.x, coords.y)
        if tile and tile.adjacent_mines == 0:
            reveal_tile_recursive(coords.x, coords.y)

func place_mines_safely(safe_coords: Vector2i):
    var placed_mines = 0
    var safe_zone = get_safe_zone(safe_coords)
    
    while placed_mines < num_mines:
        var x = randi() % grid_width
        var y = randi() % grid_height
        var coords = Vector2i(x, y)
        
        if not safe_zone.has(coords) and not tiles[x][y].is_mine:
            tiles[x][y].is_mine = true
            placed_mines += 1
    
    calculate_adjacent_mines()

func get_safe_zone(center: Vector2i) -> Array:
    var safe_zone = []
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            var nx = center.x + dx
            var ny = center.y + dy
            if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
                safe_zone.append(Vector2i(nx, ny))
    return safe_zone

func calculate_adjacent_mines():
    for x in range(grid_width):
        for y in range(grid_height):
            if tiles[x][y].is_mine:
                continue
                
            var count = 0
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    if dx == 0 and dy == 0:
                        continue
                    var nx = x + dx
                    var ny = y + dy
                    if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
                        if tiles[nx][ny].is_mine:
                            count += 1
            tiles[x][y].adjacent_mines = count

func reveal_tile_recursive(x: int, y: int):
    if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
        return
        
    var tile = get_tile_at_coords(x, y)
    if not tile or tile.is_revealed or tile.is_flagged:
        return
        
    tile.reveal()
    
    if tile.adjacent_mines == 0 and not tile.is_mine:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                if dx == 0 and dy == 0:
                    continue
                reveal_tile_recursive(x + dx, y + dy)

func get_tile_at_coords(x: int, y: int) -> Tile:
    if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
        return tiles[x][y]
    return null

<<<<<<< HEAD
	# Jeśli to puste pole (z liczbą 0) i nie jest miną, rekurencyjnie odkryj sąsiadów
	if tile.adjacent_mines == 0 and not tile.is_mine:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				reveal_tile_recursive(x + dx, y + dy) # Rekurencja!

# --- Sygnały odbierane z Tile.gd ---
func _on_tile_revealed(coords: Vector2i, is_mine_hit: bool):
	var clicked_tile = get_tile_at_coords(coords.x, coords.y)

	if first_click:
		# Przy pierwszym kliknięciu upewnij się, że pole i jego sąsiedzi są bezpieczni
		place_mines(coords) # Rozmieść miny po pierwszym kliknięciu
		calculate_adjacent_mines() # Oblicz liczby sąsiednich min

		# Jeśli pierwsze kliknięcie było miną, zresetuj i odkryj ponownie bezpiecznie
		if clicked_tile.is_mine:
			clicked_tile.is_mine = false # Usuń minę z tego pola
			clicked_tile.adjacent_mines = 0 # Upewnij się, że jest puste
			# Przelicz sąsiadów dla pola, które było miną
			calculate_adjacent_mines_for_single_tile(coords.x, coords.y)
			# Opcjonalnie, znajdź nowe miejsce na minę, aby zachować ich liczbę
			# (to jest bardziej złożone, na razie pomijamy)

		first_click = false
		# Po ustawieniu min i liczb, wywołaj rekurencję dla pierwszego kliknięcia
		# Upewnij się, że pole jest poprawnie odkryte po rozłożeniu min
		clicked_tile.update_texture() # Odśwież teksturę po zmianie is_mine / adjacent_mines
		if clicked_tile.adjacent_mines == 0:
			reveal_tile_recursive(coords.x, coords.y)

	elif is_mine_hit:
		print("GAME OVER! Trafiłeś na minę na koordynatach: ", coords)
		# TUTAJ BĘDZIE LOGIKA WALKI / EFEKT PUŁAPKI / EKRAN KOŃCA GRY
		# Na razie po prostu pokazujemy wszystkie miny
		show_all_mines()
		# Możesz też zablokować dalsze kliknięcia:
		set_process_input(false) # Wyłącza _input()
		for x in range(grid_width):
			for y in range(grid_height):
				var tile = tiles[x][y]
				tile.set_process_input(false) # Wyłącz interakcje z przyciskami

	elif clicked_tile.adjacent_mines == 0:
		reveal_tile_recursive(coords.x, coords.y)

# Funkcja pomocnicza do przeliczenia min wokół jednego pola (przydatne przy usuwaniu min z pierwszego kliknięcia)
func calculate_adjacent_mines_for_single_tile(x: int, y: int):
	# Przelicza miny dla wszystkich 8 sąsiadów pola (x,y)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				var neighbor_tile = tiles[nx][ny]
				if not neighbor_tile.is_mine:
					var mine_count = 0
					for ddx in [-1, 0, 1]:
						for ddy in [-1, 0, 1]:
							if ddx == 0 and ddy == 0: continue
							var nnx = nx + ddx
							var nny = ny + ddy
							if nnx >= 0 and nnx < grid_width and nny >= 0 and nny < grid_height:
								if tiles[nnx][nny].is_mine:
									mine_count += 1
					neighbor_tile.adjacent_mines = mine_count
					if neighbor_tile.is_revealed: # Odśwież, jeśli już odkryte
						neighbor_tile.update_texture()

func show_all_mines():
	for x in range(grid_width):
		for y in range(grid_height):
			var tile = tiles[x][y]
			if tile.is_mine and not tile.is_flagged: # Pokaż miny, które nie są oflagowane
				tile.is_revealed = true
				tile.update_texture()

# Funkcja do resetowania gry (np. po Game Over)
func reset_game():
	set_process_input(true) # Włącz input
	for x in range(grid_width):
		for y in range(grid_height):
			var tile = tiles[x][y]
			tile.set_process_input(true) # Włącz interakcje z przyciskami
	generate_grid() # Wygeneruj nową siatkę

func _input(event):
	if event.is_action_pressed("reset_game"): # Naciśnięcie R
		reset_game()
=======
func start_battle(coords: Vector2i):
    print("🎯 Rozpoczynam walkę na pozycji: ", coords)
    
    var battle_manager = get_parent().get_node("BattleManager")
    if battle_manager:
        var monster_data = {
            "name": "Goblin",
            "health": 30,
            "attack": 8,
            "defense": 2,
            "gold_drop": 15,
            "exp_drop": 20
        }
        battle_manager.start_battle(monster_data)
    else:
        print("❌ BattleManager nie znaleziony!")
>>>>>>> 23dff8afd76f4109c4927ce238ae05ff3fe23731
