class_name GameDatabase
extends Resource
## Rejestr wszystkich treści gry: przedmioty, surowce, potwory.
## Wyszukiwanie po id (m.in. przy wczytywaniu zapisu) i filtrowanie według piętra.

@export var items: Array[ItemData] = []
@export var materials: Array[CraftingMaterial] = []
@export var monsters: Array[MonsterData] = []


func get_item(id: StringName) -> ItemData:
	for item in items:
		if item and item.id == id:
			return item
	return null


func get_material(id: StringName) -> CraftingMaterial:
	for m in materials:
		if m and m.id == id:
			return m
	return null


func get_monster(id: StringName) -> MonsterData:
	for m in monsters:
		if m and m.id == id:
			return m
	return null


func get_monsters_for_floor(floor_number: int) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for m in monsters:
		if m and m.min_floor <= floor_number:
			result.append(m)
	return result


func get_shop_items(floor_number: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items:
		if item and item.sold_in_shop and item.min_floor <= floor_number:
			result.append(item)
	return result


func get_treasure_items(floor_number: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items:
		if item and item.found_in_treasure and item.min_floor <= floor_number:
			result.append(item)
	return result


## Surowce możliwe do znalezienia na piętrze (waga > 0); kolejność zgodna z get_material_weights.
func get_materials_for_floor(floor_number: int) -> Array[CraftingMaterial]:
	var result: Array[CraftingMaterial] = []
	for m in materials:
		if m and m.get_weight(floor_number) > 0.0:
			result.append(m)
	return result


func get_material_weights(floor_number: int) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	for m in get_materials_for_floor(floor_number):
		weights.append(m.get_weight(floor_number))
	return weights


## Losowanie ważone; zwraca indeks albo -1, gdy brak wag.
static func pick_weighted(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in range(weights.size()):
		roll -= maxf(weights[i], 0.0)
		if roll < 0.0:
			return i
	return weights.size() - 1
