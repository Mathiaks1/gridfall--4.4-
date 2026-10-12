class_name Inventory
extends RefCounted
## Ekwipunek: założona broń i zbroja, plecak (sprzęt), przedmioty użytkowe (stosy) i surowce (stosy).

signal changed

## ItemData -> ilość (przedmioty użytkowe).
var consumables: Dictionary = {}
## Niezałożony sprzęt.
var gear: Array[ItemInstance] = []
var weapon: ItemInstance
var armor: ItemInstance
## id surowca (StringName) -> ilość.
var materials: Dictionary = {}


## Sprzęt trafia do pustego slotu albo do plecaka; przedmioty użytkowe się stackują.
func add_item(item: ItemData, count: int = 1) -> void:
	if item.is_equipment():
		for i in range(count):
			var inst := ItemInstance.new(item)
			if get_slot(item.kind) == null:
				_set_slot(item.kind, inst)
			else:
				gear.append(inst)
	else:
		consumables[item] = get_count(item) + count
	changed.emit()


func get_count(item: ItemData) -> int:
	return int(consumables.get(item, 0))


func remove_consumable(item: ItemData, count: int = 1) -> bool:
	var have := get_count(item)
	if have < count:
		return false
	if have == count:
		consumables.erase(item)
	else:
		consumables[item] = have - count
	changed.emit()
	return true


## Przedmioty użytkowe w stałej kolejności (alfabetycznie po id).
func get_consumables() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in consumables:
		result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool: return String(a.id) < String(b.id))
	return result


func get_slot(kind: ItemData.Kind) -> ItemInstance:
	match kind:
		ItemData.Kind.WEAPON:
			return weapon
		ItemData.Kind.ARMOR:
			return armor
	return null


## Zakłada sprzęt z plecaka; poprzedni wraca do plecaka.
func equip(inst: ItemInstance) -> bool:
	if not gear.has(inst):
		return false
	gear.erase(inst)
	var old := get_slot(inst.data.kind)
	_set_slot(inst.data.kind, inst)
	if old:
		gear.append(old)
	changed.emit()
	return true


func remove_gear(inst: ItemInstance) -> bool:
	if not gear.has(inst):
		return false
	gear.erase(inst)
	changed.emit()
	return true


## Cały sprzęt: założony + plecak.
func get_all_equipment() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	if weapon:
		result.append(weapon)
	if armor:
		result.append(armor)
	result.append_array(gear)
	return result


func get_attack_bonus() -> int:
	return (weapon.get_attack_bonus() if weapon else 0) + (armor.get_attack_bonus() if armor else 0)


func get_defense_bonus() -> int:
	return (weapon.get_defense_bonus() if weapon else 0) + (armor.get_defense_bonus() if armor else 0)


func add_material(id: StringName, count: int = 1) -> void:
	materials[id] = get_material_count(id) + count
	changed.emit()


func get_material_count(id: StringName) -> int:
	return int(materials.get(id, 0))


## cost: id surowca -> ilość.
func has_materials(cost: Dictionary) -> bool:
	for id: StringName in cost:
		if get_material_count(id) < int(cost[id]):
			return false
	return true


func remove_materials(cost: Dictionary) -> bool:
	if not has_materials(cost):
		return false
	for id: StringName in cost:
		var left := get_material_count(id) - int(cost[id])
		if left <= 0:
			materials.erase(id)
		else:
			materials[id] = left
	changed.emit()
	return true


## Dla zmian dokonanych z zewnątrz (np. ulepszenie u Kowala).
func notify_changed() -> void:
	changed.emit()


func to_dict() -> Dictionary:
	var consumable_ids := {}
	for item: ItemData in consumables:
		consumable_ids[item.id] = consumables[item]
	var gear_list: Array = []
	for inst in gear:
		gear_list.append(inst.to_dict())
	return {
		"consumables": consumable_ids,
		"materials": materials.duplicate(),
		"weapon": weapon.to_dict() if weapon else {},
		"armor": armor.to_dict() if armor else {},
		"gear": gear_list,
	}


static func from_dict(d: Dictionary, database: GameDatabase) -> Inventory:
	var inv := Inventory.new()
	var consumable_ids: Dictionary = d.get("consumables", {})
	for id: StringName in consumable_ids:
		var item := database.get_item(id)
		if item:
			inv.consumables[item] = int(consumable_ids[id])
	inv.materials = (d.get("materials", {}) as Dictionary).duplicate()
	inv.weapon = ItemInstance.from_dict(d.get("weapon", {}), database)
	inv.armor = ItemInstance.from_dict(d.get("armor", {}), database)
	for entry: Dictionary in d.get("gear", []):
		var inst := ItemInstance.from_dict(entry, database)
		if inst:
			inv.gear.append(inst)
	return inv


func _set_slot(kind: ItemData.Kind, inst: ItemInstance) -> void:
	match kind:
		ItemData.Kind.WEAPON:
			weapon = inst
		ItemData.Kind.ARMOR:
			armor = inst
