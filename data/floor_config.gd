class_name FloorConfig
extends Resource
## Skalowanie trudności pięter. Balans zmieniamy w pliku .tres, nie w kodzie.

@export_group("Grid size")
@export_range(3, 64) var base_width: int = 9
@export_range(3, 64) var base_height: int = 9
## Ile pól przybywa w każdym wymiarze na piętro (0.5 = +1 co dwa piętra).
@export_range(0.0, 4.0, 0.05) var size_growth_per_floor: float = 0.5
@export_range(3, 64) var max_width: int = 20
@export_range(3, 64) var max_height: int = 20

@export_group("Hazards")
@export_range(0.0, 0.9, 0.005) var base_hazard_density: float = 0.12
@export_range(0.0, 0.1, 0.001) var hazard_density_per_floor: float = 0.008
@export_range(0.0, 0.9, 0.005) var max_hazard_density: float = 0.22
## Promień bezpiecznej strefy wokół pierwszego kliknięcia (1 = kwadrat 3x3).
@export_range(0, 3) var safe_radius: int = 1

@export_group("Monsters (Phase 2)")
@export var base_monster_power: int = 1
@export_range(0.0, 5.0, 0.05) var monster_power_per_floor: float = 0.5


func get_width(floor_number: int) -> int:
	return mini(base_width + _growth(floor_number), max_width)


func get_height(floor_number: int) -> int:
	return mini(base_height + _growth(floor_number), max_height)


func get_hazard_density(floor_number: int) -> float:
	return minf(base_hazard_density + hazard_density_per_floor * _floors_below(floor_number), max_hazard_density)


func get_hazard_count(floor_number: int) -> int:
	var cells := get_width(floor_number) * get_height(floor_number)
	return maxi(1, roundi(cells * get_hazard_density(floor_number)))


func get_monster_power(floor_number: int) -> int:
	return base_monster_power + int(monster_power_per_floor * _floors_below(floor_number))


func _growth(floor_number: int) -> int:
	return int(size_growth_per_floor * _floors_below(floor_number))


func _floors_below(floor_number: int) -> int:
	return maxi(floor_number - 1, 0)
