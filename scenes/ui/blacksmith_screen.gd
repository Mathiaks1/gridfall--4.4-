class_name BlacksmithScreen
extends ModalScreen
## Kowal: lista sprzętu, statystyki obecne → po ulepszeniu, koszt (złoto + surowce), przycisk „Ulepsz”.

var _player: PlayerStats
var _config: BlacksmithConfig
var _database: GameDatabase


func open_blacksmith(player: PlayerStats, config: BlacksmithConfig, database: GameDatabase) -> void:
	_player = player
	_config = config
	_database = database
	title_label.text = UiText.t(&"smith_title")
	clear_footer()
	add_footer_button(UiText.t(&"common_close"), close)
	open_modal()
	_refresh()


func _refresh() -> void:
	subtitle_label.text = UiText.t(&"smith_resources") % [_player.gold, _describe_materials(_player.inventory.materials)]
	clear_list()
	var equipment := _player.inventory.get_all_equipment()
	if equipment.is_empty():
		add_text(UiText.t(&"smith_nothing"), true)
	for inst in equipment:
		if not Blacksmith.can_upgrade(inst, _config):
			add_row(UiText.t(&"smith_row_max") % [inst.get_display_name(), _stats(inst)], UiText.t(&"smith_max"), _refresh, false)
			continue
		var next := Blacksmith.preview(inst)
		var cost := UiText.t(&"smith_gold") % _config.get_gold_cost(inst.upgrade_level)
		var materials := _config.get_material_cost(inst.upgrade_level)
		if not materials.is_empty():
			cost += ", " + _describe_materials(materials)
		var text := UiText.t(&"smith_row") % [inst.get_display_name(), _stats(inst), _stats(next), cost]
		add_row(text, UiText.t(&"smith_upgrade"), _on_upgrade.bind(inst), Blacksmith.can_afford(_player, inst, _config))


func _stats(inst: ItemInstance) -> String:
	return UiText.t(&"stat_bonus") % [inst.get_attack_bonus(), inst.get_defense_bonus()]


## "Żelazna ruda ×2, Magiczny kryształ ×1" albo "brak".
func _describe_materials(materials: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: StringName in materials:
		var mat := _database.get_material(id)
		var material_name := mat.get_display_name() if mat else String(id)
		parts.append(UiText.t(&"inv_count") % [material_name, int(materials[id])])
	return ", ".join(parts) if not parts.is_empty() else UiText.t(&"common_none")


func _on_upgrade(inst: ItemInstance) -> void:
	if Blacksmith.upgrade(_player, inst, _config):
		EventBus.message_logged.emit(UiText.t(&"log_upgraded") % inst.get_display_name())
	_refresh()
