class_name PlayerStats
extends Resource
## Statystyki bohatera. Plik .tres trzyma wartości startowe; na każdy run tworzymy kopię (duplicate()).
## Zmiany ogłaszane wbudowanym sygnałem Resource.changed.

signal leveled_up(new_level: int)

@export_group("Start")
@export var max_hp: int = 30
@export var attack: int = 5
@export var defense: int = 1

@export_group("Leveling")
@export var exp_to_level_base: int = 20
## Mnożnik wymaganego EXP na kolejny poziom.
@export_range(1.0, 3.0, 0.05) var exp_to_level_growth: float = 1.5
@export var hp_per_level: int = 5
@export var attack_per_level: int = 1
@export var defense_per_level: int = 0

var hp: int = 0
var gold: int = 0
var experience: int = 0
var level: int = 1


## Stan początkowy runu.
func start_run() -> void:
	hp = max_hp
	gold = 0
	experience = 0
	level = 1
	emit_changed()


func is_dead() -> bool:
	return hp <= 0


func take_damage(amount: int) -> void:
	hp = maxi(hp - maxi(amount, 0), 0)
	emit_changed()


## Zwraca faktycznie odzyskane HP.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + maxi(amount, 0), max_hp)
	emit_changed()
	return hp - before


func add_gold(amount: int) -> void:
	gold += amount
	emit_changed()


func get_exp_to_next_level() -> int:
	return maxi(roundi(exp_to_level_base * pow(exp_to_level_growth, level - 1)), 1)


## Dodaje EXP i obsługuje awanse (Faza 2: automatyczny przyrost statystyk + pełne HP).
## Faza 3: zamiast tego punkty atrybutów do rozdzielenia na ekranie awansu.
func add_experience(amount: int) -> void:
	experience += amount
	while experience >= get_exp_to_next_level():
		experience -= get_exp_to_next_level()
		level += 1
		max_hp += hp_per_level
		attack += attack_per_level
		defense += defense_per_level
		hp = max_hp
		leveled_up.emit(level)
	emit_changed()
