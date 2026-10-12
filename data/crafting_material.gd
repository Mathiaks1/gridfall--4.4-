class_name CraftingMaterial
extends Resource
## Surowiec do ulepszeń u Kowala. Stackowalny, przechowywany w osobnej sekcji ekwipunku.

enum Rarity { COMMON, RARE, EPIC }

@export var id: StringName
@export var name_key: StringName
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 100) var min_floor: int = 1
## Waga losowania na piętrze min_floor; zmienia się o weight_per_floor z każdym piętrem.
@export var drop_weight: float = 1.0
@export var weight_per_floor: float = 0.0

@export_group("Visuals (optional)")
@export var color := Color.WHITE
@export var icon: Texture2D


func get_weight(floor_number: int) -> float:
	if floor_number < min_floor:
		return 0.0
	return maxf(drop_weight + weight_per_floor * (floor_number - min_floor), 0.0)


func get_display_name() -> String:
	return UiText.t(name_key)
