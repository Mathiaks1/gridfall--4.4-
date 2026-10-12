class_name Blacksmith
extends RefCounted
## Ulepszanie broni i zbroi za złoto + surowce. Czyste funkcje — koszty w BlacksmithConfig.


static func can_upgrade(inst: ItemInstance, config: BlacksmithConfig) -> bool:
	return inst != null and inst.data.is_equipment() and config.can_upgrade_level(inst.upgrade_level)


static func can_afford(player: PlayerStats, inst: ItemInstance, config: BlacksmithConfig) -> bool:
	return player.gold >= config.get_gold_cost(inst.upgrade_level) \
		and player.inventory.has_materials(config.get_material_cost(inst.upgrade_level))


static func upgrade(player: PlayerStats, inst: ItemInstance, config: BlacksmithConfig) -> bool:
	if not can_upgrade(inst, config) or not can_afford(player, inst, config):
		return false
	var level := inst.upgrade_level
	player.spend_gold(config.get_gold_cost(level))
	player.inventory.remove_materials(config.get_material_cost(level))
	inst.upgrade_level += 1
	player.inventory.notify_changed()
	return true


## Statystyki przedmiotu po ulepszeniu (do podglądu w UI).
static func preview(inst: ItemInstance) -> ItemInstance:
	return ItemInstance.new(inst.data, inst.upgrade_level + 1)
