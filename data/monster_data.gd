class_name MonsterData
extends Resource
## Definicja typu potwora. Statystyki rosną z "mocą" piętra (FloorConfig.get_monster_power).

@export var id: StringName
## Klucz nazwy w UiText (lokalizacja).
@export var name_key: StringName
@export_range(1, 100) var min_floor: int = 1

@export_group("Base stats")
@export var max_hp: int = 6
@export var attack: int = 3
@export var defense: int = 0
@export var gold_reward: int = 3
@export var exp_reward: int = 5

@export_group("Scaling per power")
@export var hp_per_power: float = 2.0
@export var attack_per_power: float = 0.5
@export var defense_per_power: float = 0.25
## Dodatkowy mnożnik nagród za każdy punkt mocy ponad 1.
@export var reward_per_power: float = 0.3

@export_group("Visuals (optional)")
@export var color := Color("b04ad6")
@export var texture: Texture2D


func create_instance(power: int) -> MonsterInstance:
	var bonus := maxi(power - 1, 0)
	var m := MonsterInstance.new()
	m.data = self
	m.max_hp = max_hp + int(hp_per_power * bonus)
	m.hp = m.max_hp
	m.attack = attack + int(attack_per_power * bonus)
	m.defense = defense + int(defense_per_power * bonus)
	var reward_mult := 1.0 + reward_per_power * bonus
	m.gold_reward = roundi(gold_reward * reward_mult)
	m.exp_reward = roundi(exp_reward * reward_mult)
	return m
