class_name FloorConfig
extends Resource
## Skalowanie trudności i nagród pięter. Balans zmieniamy w pliku .tres, nie w kodzie.

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

@export_group("Monsters")
@export var monster_pool: Array[MonsterData] = []
## Jaka część zagrożeń to potwory (reszta to pułapki).
@export_range(0.0, 1.0, 0.05) var monster_share: float = 0.4
@export var base_monster_power: int = 1
@export_range(0.0, 5.0, 0.05) var monster_power_per_floor: float = 0.5

@export_group("Traps")
@export var trap_damage_base: int = 3
@export_range(0.0, 5.0, 0.05) var trap_damage_per_floor: float = 0.5

@export_group("Treasure")
@export var base_treasure_count: int = 2
@export_range(0.0, 2.0, 0.05) var treasure_count_per_floor: float = 0.25
@export var max_treasure_count: int = 6
@export var treasure_gold_min: int = 4
@export var treasure_gold_max: int = 12
## Wzrost wartości skarbów na piętro (0.15 = +15%).
@export_range(0.0, 1.0, 0.01) var treasure_gold_growth: float = 0.15

@export_group("Exit")
@export var has_exit: bool = true
## Ułamek max HP odzyskiwany przy zejściu piętro niżej.
@export_range(0.0, 1.0, 0.05) var heal_on_descend: float = 0.25


func get_width(floor_number: int) -> int:
	return mini(base_width + _growth(floor_number), max_width)


func get_height(floor_number: int) -> int:
	return mini(base_height + _growth(floor_number), max_height)


func get_hazard_density(floor_number: int) -> float:
	return minf(base_hazard_density + hazard_density_per_floor * _floors_below(floor_number), max_hazard_density)


## Łączna liczba zagrożeń (pułapki + potwory).
func get_hazard_count(floor_number: int) -> int:
	var cells := get_width(floor_number) * get_height(floor_number)
	return maxi(1, roundi(cells * get_hazard_density(floor_number)))


func get_monsters_for_floor(floor_number: int) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for m in monster_pool:
		if m != null and m.min_floor <= floor_number:
			result.append(m)
	return result


func get_monster_count(floor_number: int) -> int:
	if get_monsters_for_floor(floor_number).is_empty():
		return 0
	return roundi(get_hazard_count(floor_number) * monster_share)


func get_monster_power(floor_number: int) -> int:
	return base_monster_power + int(monster_power_per_floor * _floors_below(floor_number))


func get_trap_damage(floor_number: int) -> int:
	return trap_damage_base + int(trap_damage_per_floor * _floors_below(floor_number))


func get_treasure_count(floor_number: int) -> int:
	return mini(base_treasure_count + int(treasure_count_per_floor * _floors_below(floor_number)), max_treasure_count)


## Zakres złota w skarbie: x = min, y = max.
func get_treasure_gold_range(floor_number: int) -> Vector2i:
	var mult := 1.0 + treasure_gold_growth * _floors_below(floor_number)
	var lo := roundi(treasure_gold_min * mult)
	return Vector2i(lo, maxi(roundi(treasure_gold_max * mult), lo))


func _growth(floor_number: int) -> int:
	return int(size_growth_per_floor * _floors_below(floor_number))


func _floors_below(floor_number: int) -> int:
	return maxi(floor_number - 1, 0)
