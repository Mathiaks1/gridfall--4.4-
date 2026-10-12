class_name InventoryScreen
extends ModalScreen
## Ekwipunek: założony sprzęt, plecak (zakładanie), przedmioty użytkowe (użycie na planszy), surowce.

signal item_use_requested(item: ItemData)

var _player: PlayerStats
var _database: GameDatabase


func open_inventory(player: PlayerStats, database: GameDatabase) -> void:
	_player = player
	_database = database
	title_label.text = UiText.t(&"inv_title")
	clear_footer()
	add_footer_button(UiText.t(&"common_close"), close)
	open_modal()
	_refresh()


func _refresh() -> void:
	var p := _player
	var inv := p.inventory
	subtitle_label.text = "%s · %s · %s" % [
		UiText.t(&"hud_hp") % [p.hp, p.get_max_hp()],
		UiText.t(&"hud_stats") % [p.get_attack(), p.get_defense()],
		UiText.t(&"hud_gold") % p.gold,
	]
	clear_list()

	add_section(UiText.t(&"inv_equipped"))
	add_text(UiText.t(&"inv_weapon") % _describe_slot(inv.weapon))
	add_text(UiText.t(&"inv_armor") % _describe_slot(inv.armor))

	add_section(UiText.t(&"inv_bag"))
	if inv.gear.is_empty():
		add_text(UiText.t(&"common_empty"), true)
	for inst in inv.gear:
		var text := "%s (%s)" % [inst.get_display_name(), UiText.t(&"stat_bonus") % [inst.get_attack_bonus(), inst.get_defense_bonus()]]
		add_row(text, UiText.t(&"inv_equip"), _on_equip.bind(inst))

	add_section(UiText.t(&"inv_items"))
	var consumables := inv.get_consumables()
	if consumables.is_empty():
		add_text(UiText.t(&"common_empty"), true)
	for item in consumables:
		var text := "%s\n%s" % [UiText.t(&"inv_count") % [item.get_display_name(), inv.get_count(item)], item.get_description()]
		add_row(text, UiText.t(&"inv_use"), _on_use.bind(item), item.usable_on_board())

	add_section(UiText.t(&"inv_materials"))
	if inv.materials.is_empty():
		add_text(UiText.t(&"common_empty"), true)
	for id: StringName in inv.materials:
		var mat := _database.get_material(id)
		add_text(UiText.t(&"inv_count") % [mat.get_display_name() if mat else String(id), inv.get_material_count(id)])


func _describe_slot(inst: ItemInstance) -> String:
	if inst == null:
		return "%s (%s)" % [UiText.t(&"common_none"), UiText.t(&"stat_bonus") % [0, 0]]
	return "%s (%s)" % [inst.get_display_name(), UiText.t(&"stat_bonus") % [inst.get_attack_bonus(), inst.get_defense_bonus()]]


func _on_equip(inst: ItemInstance) -> void:
	if _player.inventory.equip(inst):
		EventBus.message_logged.emit(UiText.t(&"log_equipped") % inst.get_display_name())
	_refresh()


func _on_use(item: ItemData) -> void:
	close()
	item_use_requested.emit(item)
