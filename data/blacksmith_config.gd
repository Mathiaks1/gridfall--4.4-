class_name BlacksmithConfig
extends Resource
## Koszty ulepszeń u Kowala. Indeks tablic = obecny poziom ulepszenia (0 → koszt ulepszenia do +1).

@export var max_upgrade_level: int = 5
@export var gold_costs := PackedInt32Array([15, 30, 55, 90, 140])
## Koszt w surowcach: id surowca (StringName) -> ilość.
@export var material_costs: Array[Dictionary] = []


func can_upgrade_level(level: int) -> bool:
	return level < max_upgrade_level and level < gold_costs.size()


func get_gold_cost(level: int) -> int:
	return gold_costs[level] if level >= 0 and level < gold_costs.size() else 0


func get_material_cost(level: int) -> Dictionary:
	return material_costs[level] if level >= 0 and level < material_costs.size() else {}
