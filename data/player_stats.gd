class_name PlayerStats
extends Resource
## Bohater: atrybuty, statystyki pochodne, poziom, złoto i ekwipunek.
## Plik .tres trzyma wartości startowe i współczynniki balansu; na każdy run tworzymy kopię (duplicate()).
## Zmiany ogłaszane wbudowanym sygnałem Resource.changed.

signal leveled_up(new_level: int)

enum Attribute { STRENGTH, VITALITY, LUCK, CHARISMA, INTELLIGENCE }
const ATTRIBUTE_COUNT := 5

@export_group("Start")
@export var base_max_hp: int = 25
@export var base_attack: int = 4
@export var base_defense: int = 1
## Startowe atrybuty w kolejności enum Attribute.
@export var starting_attributes := PackedInt32Array([1, 1, 1, 1, 1])
@export var starting_gold: int = 0
## Broń i zbroja zakładane automatycznie, reszta trafia do plecaka.
@export var starting_items: Array[ItemData] = []

@export_group("Attribute effects")
@export var hp_per_vitality: int = 5
@export var attack_per_strength: int = 1
@export var crit_chance_per_luck: float = 0.03
@export var max_crit_chance: float = 0.5
@export var crit_multiplier: float = 1.5
@export var trap_dodge_per_luck: float = 0.04
@export var max_trap_dodge: float = 0.5
## Mnożnik złota i szans na łup za punkt Szczęścia.
@export var loot_bonus_per_luck: float = 0.05
@export var price_discount_per_charisma: float = 0.03
@export var max_price_discount: float = 0.45
@export var item_power_per_intelligence: float = 0.1
## Co ile punktów Inteligencji zwój odkrycia dostaje +1 do promienia.
@export var intelligence_per_scry_radius: int = 4
@export var flee_chance_base: float = 0.35
@export var flee_chance_per_luck: float = 0.05

@export_group("Leveling")
@export var exp_to_level_base: int = 20
@export_range(1.0, 3.0, 0.05) var exp_to_level_growth: float = 1.5
@export var attribute_points_per_level: int = 3

var hp: int = 0
var gold: int = 0
var experience: int = 0
var level: int = 1
var attribute_points: int = 0
var attributes := PackedInt32Array()
var inventory: Inventory


## Stan początkowy runu.
func start_run() -> void:
	attributes = PackedInt32Array()
	attributes.resize(ATTRIBUTE_COUNT)
	for i in range(ATTRIBUTE_COUNT):
		attributes[i] = starting_attributes[i] if i < starting_attributes.size() else 0
	gold = starting_gold
	experience = 0
	level = 1
	attribute_points = 0
	_set_inventory(Inventory.new())
	for item in starting_items:
		if item:
			inventory.add_item(item)
	hp = get_max_hp()
	emit_changed()


# --- Statystyki pochodne -----------------------------------------------------

func get_attribute(attribute: Attribute) -> int:
	return attributes[attribute] if attribute < attributes.size() else 0


func get_max_hp() -> int:
	return base_max_hp + get_attribute(Attribute.VITALITY) * hp_per_vitality


func get_attack() -> int:
	return base_attack + get_attribute(Attribute.STRENGTH) * attack_per_strength + inventory.get_attack_bonus()


func get_defense() -> int:
	return base_defense + inventory.get_defense_bonus()


func get_crit_chance() -> float:
	return minf(get_attribute(Attribute.LUCK) * crit_chance_per_luck, max_crit_chance)


func get_trap_dodge_chance() -> float:
	return minf(get_attribute(Attribute.LUCK) * trap_dodge_per_luck, max_trap_dodge)


func get_loot_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.LUCK) * loot_bonus_per_luck


func get_flee_chance() -> float:
	return minf(flee_chance_base + get_attribute(Attribute.LUCK) * flee_chance_per_luck, 0.9)


## Mnożnik cen w sklepie (Charyzma obniża ceny).
func get_price_multiplier() -> float:
	return 1.0 - minf(get_attribute(Attribute.CHARISMA) * price_discount_per_charisma, max_price_discount)


## Mnożnik siły mikstur i granatów (Inteligencja).
func get_item_power_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.INTELLIGENCE) * item_power_per_intelligence


func get_scry_radius_bonus() -> int:
	@warning_ignore("integer_division")
	return get_attribute(Attribute.INTELLIGENCE) / maxi(intelligence_per_scry_radius, 1)


# --- Zmiany stanu ------------------------------------------------------------

func is_dead() -> bool:
	return hp <= 0


func take_damage(amount: int) -> void:
	hp = maxi(hp - maxi(amount, 0), 0)
	emit_changed()


## Zwraca faktycznie odzyskane HP.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + maxi(amount, 0), get_max_hp())
	emit_changed()
	return hp - before


func add_gold(amount: int) -> void:
	gold += amount
	emit_changed()


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	emit_changed()
	return true


func get_exp_to_next_level() -> int:
	return maxi(roundi(exp_to_level_base * pow(exp_to_level_growth, level - 1)), 1)


## Awans daje punkty atrybutów do rozdzielenia i pełne HP.
func add_experience(amount: int) -> void:
	experience += amount
	while experience >= get_exp_to_next_level():
		experience -= get_exp_to_next_level()
		level += 1
		attribute_points += attribute_points_per_level
		hp = get_max_hp()
		leveled_up.emit(level)
	emit_changed()


## Rozdziela punkty: allocation[i] = ile punktów dodać do atrybutu i. Zwraca false, gdy za mało punktów.
func apply_attribute_points(allocation: PackedInt32Array) -> bool:
	var total := 0
	for v in allocation:
		if v < 0:
			return false
		total += v
	if total > attribute_points:
		return false
	var old_max_hp := get_max_hp()
	for i in range(mini(allocation.size(), ATTRIBUTE_COUNT)):
		attributes[i] += allocation[i]
	attribute_points -= total
	# Witalność podnosi też bieżące HP
	hp += get_max_hp() - old_max_hp
	emit_changed()
	return true


# --- Zapis -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"hp": hp,
		"gold": gold,
		"experience": experience,
		"level": level,
		"attribute_points": attribute_points,
		"attributes": attributes,
		"inventory": inventory.to_dict(),
	}


func load_from_dict(data: Dictionary, database: GameDatabase) -> void:
	hp = int(data.get("hp", 1))
	gold = int(data.get("gold", 0))
	experience = int(data.get("experience", 0))
	level = int(data.get("level", 1))
	attribute_points = int(data.get("attribute_points", 0))
	attributes = data.get("attributes", starting_attributes)
	_set_inventory(Inventory.from_dict(data.get("inventory", {}), database))
	emit_changed()


func _set_inventory(value: Inventory) -> void:
	if inventory and inventory.changed.is_connected(emit_changed):
		inventory.changed.disconnect(emit_changed)
	inventory = value
	inventory.changed.connect(emit_changed)
