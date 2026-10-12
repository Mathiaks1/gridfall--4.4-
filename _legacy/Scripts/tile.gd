# tile.gd
class_name Tile

extends TextureButton

@export var hidden_texture: Texture2D
@export var revealed_textures: Array[Texture2D] = [] # Indeks 0 dla 0 min, 1 dla 1 miny itd.
@export var mine_texture: Texture2D
@export var flag_texture: Texture2D

var is_mine = false
var is_revealed = false
var is_flagged = false
var adjacent_mines = 0
var grid_coords = Vector2i() # Koordynaty (x, y) w siatce

# Definiowanie sygnałów niestandardowych
signal tile_revealed(coords, is_mine_hit)
signal tile_flag(coords, is_flagged_now)

func _ready():
	# Upewnij się, że tablica revealed_textures ma odpowiedni rozmiar
	# i przypisze odpowiednie tekstury dla liczb 0-8 w inspektorze
	if revealed_textures.is_empty():
		# Możesz dodać domyślne tekstury lub ostrzeżenie
		pass 
	update_texture()

# Zastąp _pressed() tą funkcją
func _gui_input(event):
	if is_revealed or is_flagged:
		# Jeśli już odkryte lub oflagowane, ale chcemy umożliwić odflagowanie prawym kliknięciem
		if is_flagged and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_flag()
			accept_event() # Ważne: zapobiega dalszemu przetwarzaniu tego zdarzenia
		return # Nie rób nic więcej, jeśli już odkryte/oflagowane

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Left click detected, revealing tile at", grid_coords)
			reveal()
			accept_event() # Ważne: zapobiega dalszemu przetwarzaniu
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right click detected, toggling flag at", grid_coords)
			toggle_flag()
			accept_event() # Ważne: zapobiega dalszemu przetwarzaniu

func toggle_flag():
	is_flagged = not is_flagged
	update_texture()
	emit_signal("tile_flag", grid_coords, is_flagged)

func reveal():
	if is_revealed or is_flagged:
		return

	is_revealed = true
	update_texture()

	# Emitowanie sygnału do GridManager
	emit_signal("tile_revealed", grid_coords, is_mine)

func update_texture():
	if is_flagged:
		texture_normal = flag_texture
	elif not is_revealed:
		texture_normal = hidden_texture
	else: # is_revealed == true
		if is_mine:
			texture_normal = mine_texture
		else:
			# Sprawdzanie, czy indeks jest prawidłowy
			if adjacent_mines >= 0 and adjacent_mines < revealed_textures.size():
				texture_normal = revealed_textures[adjacent_mines]
			else:
				# Awaryjnie, jeśli brakuje tekstur dla liczb
				texture_normal = hidden_texture # lub inna domyślna
