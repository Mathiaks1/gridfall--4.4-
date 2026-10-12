class_name TileSkin
extends Resource
## Wygląd pól. Placeholdery rysowane z prymitywów; ustaw tekstury, by podmienić grafikę bez zmian w kodzie.

@export_group("Colors")
@export var hidden_color := Color("2c3140")
@export var hidden_border_color := Color("454c60")
@export var revealed_color := Color("16181f")
@export var revealed_border_color := Color("22252e")
@export var hazard_color := Color("c23b3b")
@export var exploded_background_color := Color("5a1414")
@export var flag_color := Color("e8b53a")
@export var flag_pole_color := Color("c9ccd6")
@export var wrong_flag_color := Color("ff5a5a")
@export var hold_feedback_color := Color(1.0, 1.0, 1.0, 0.22)
@export var monster_color := Color("9b4fd1")
@export var monster_eye_color := Color("f5f0e0")
@export var treasure_color := Color("8a5a2b")
@export var treasure_trim_color := Color("f0c040")
@export var exit_color := Color("4fc3d9")
@export var shop_color := Color("3fa86b")
@export var blacksmith_color := Color("9aa3b5")
@export var resource_color := Color("7fd4ff")
## Przezroczystość ikon pól rozpatrzonych (pokonany potwór, zebrany skarb, zużyta pułapka).
@export_range(0.0, 1.0, 0.05) var resolved_alpha: float = 0.35
## Kolory cyfr 1–8 (indeks 0 = cyfra 1).
@export var number_colors: Array[Color] = [
	Color("5aa9ff"), Color("5fd16a"), Color("ff6b6b"), Color("b57bff"),
	Color("ffa64d"), Color("4dd9d9"), Color("e0e0e0"), Color("9a9a9a"),
]

@export_group("Textures (optional)")
@export var hidden_texture: Texture2D
@export var revealed_texture: Texture2D
@export var flag_texture: Texture2D
@export var hazard_texture: Texture2D
@export var monster_texture: Texture2D
@export var treasure_texture: Texture2D
@export var exit_texture: Texture2D
@export var shop_texture: Texture2D
@export var blacksmith_texture: Texture2D
@export var resource_texture: Texture2D
## Tekstury cyfr: indeks = liczba (0–8). Puste/brakujące = rysowanie tekstem.
@export var number_textures: Array[Texture2D] = []
## Małe cyfry w rogu pól specjalnych (indeks = liczba). Puste = tekst.
@export var small_number_textures: Array[Texture2D] = []
## Tło odkrytego zagrożenia, które właśnie zadziałało.
@export var revealed_danger_texture: Texture2D
@export var wrong_flag_texture: Texture2D

@export_group("Resolved textures (optional)")
## Pola rozpatrzone: osobne sprite'y zamiast półprzezroczystości (resolved_alpha to fallback).
@export var trap_resolved_texture: Texture2D
@export var monster_resolved_texture: Texture2D
@export var treasure_resolved_texture: Texture2D
@export var resource_resolved_texture: Texture2D

@export_group("Reveal animation (optional)")
## Sprite sheet (klatki w poziomie) odgrywany przy odkryciu pola.
@export var reveal_animation: Texture2D
@export_range(1, 16) var reveal_frames: int = 4
@export_range(1.0, 60.0) var reveal_fps: float = 20.0

@export_group("Text")
## Pusty = domyślna czcionka silnika.
@export var font: Font
@export_range(0.2, 0.9, 0.05) var font_size_ratio: float = 0.6


func get_number_color(number: int) -> Color:
	if number >= 1 and number <= number_colors.size():
		return number_colors[number - 1]
	return Color.WHITE


func get_small_number_texture(number: int) -> Texture2D:
	if number >= 0 and number < small_number_textures.size():
		return small_number_textures[number]
	return null


func get_number_texture(number: int) -> Texture2D:
	if number >= 0 and number < number_textures.size():
		return number_textures[number]
	return null
