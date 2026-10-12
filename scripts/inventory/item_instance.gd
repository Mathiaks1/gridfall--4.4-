class_name ItemInstance
extends RefCounted
## Konkretna sztuka broni/zbroi z poziomem ulepszenia u Kowala.

var data: ItemData
var upgrade_level: int = 0


func _init(p_data: ItemData = null, p_upgrade_level: int = 0) -> void:
	data = p_data
	upgrade_level = p_upgrade_level


func get_attack_bonus() -> int:
	return data.attack_bonus + data.attack_per_upgrade * upgrade_level


func get_defense_bonus() -> int:
	return data.defense_bonus + data.defense_per_upgrade * upgrade_level


func get_display_name() -> String:
	var base := data.get_display_name()
	return base if upgrade_level == 0 else "%s +%d" % [base, upgrade_level]


func to_dict() -> Dictionary:
	return {"id": data.id, "level": upgrade_level}


static func from_dict(d: Dictionary, database: GameDatabase) -> ItemInstance:
	var item := database.get_item(d.get("id", &""))
	if item == null:
		return null
	return ItemInstance.new(item, int(d.get("level", 0)))
