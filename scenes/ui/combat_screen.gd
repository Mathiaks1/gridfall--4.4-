class_name CombatScreen
extends ModalScreen
## Ekran walki turowej. Logika w CombatSession — tu tylko przyciski i dziennik.

signal combat_finished(session: CombatSession)

const MAX_LOG_LINES := 8
const HERO_SHEET_PATH := "res://assets/art/hero/hero_battle_idle.png"
const HERO_FRAMES := 4
const HERO_FPS := 5.0

var _session: CombatSession
var _log := PackedStringArray()
var _showing_items: bool = false
var _hero_sprite: BattleSprite
var _monster_sprite: BattleSprite


func start(session: CombatSession) -> void:
	_session = session
	_log.clear()
	_showing_items = false
	title_label.text = UiText.t(&"combat_title") % session.monster.get_display_name()
	_show_portraits(session.monster.data)
	_append(PackedStringArray([UiText.t(&"combat_intro") % session.monster.get_display_name()]))
	open_modal()
	_refresh()


## Bohater po lewej, potwór po prawej (nad statystykami). Tworzone przy pierwszej walce.
func _show_portraits(data: MonsterData) -> void:
	if _hero_sprite == null:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 96)
		_hero_sprite = BattleSprite.new()
		_monster_sprite = BattleSprite.new()
		row.add_child(_hero_sprite)
		row.add_child(_monster_sprite)
		var content := subtitle_label.get_parent()
		content.add_child(row)
		content.move_child(row, subtitle_label.get_index())
	var hero_sheet: Texture2D = load(HERO_SHEET_PATH) if ResourceLoader.exists(HERO_SHEET_PATH) else null
	_hero_sprite.play(hero_sheet, HERO_FRAMES, HERO_FPS)
	if data and data.battle_sheet:
		_monster_sprite.play(data.battle_sheet, data.battle_frames, data.battle_fps)
	else:
		_monster_sprite.play(null, 1, 1.0)


## Trwająca walka (null, gdy ekran zamknięty).
func get_session() -> CombatSession:
	return _session if visible else null


func _refresh() -> void:
	var p := _session.player
	var m := _session.monster
	subtitle_label.text = UiText.t(&"combat_status") % [
		p.hp, p.get_max_hp(), p.get_attack(), p.get_defense(),
		m.get_display_name(), maxi(m.hp, 0), m.max_hp, m.attack, m.defense,
	]
	clear_list()
	clear_footer()
	if _showing_items:
		_build_item_list()
		add_footer_button(UiText.t(&"combat_back"), _on_back)
		return
	for line in _log:
		add_text(line)
	if _session.is_over():
		add_footer_button(UiText.t(&"combat_continue"), _on_continue)
	else:
		add_footer_button(UiText.t(&"combat_attack"), _on_attack)
		add_footer_button(UiText.t(&"combat_item"), _on_items)
		add_footer_button(UiText.t(&"combat_flee") % roundi(p.get_flee_chance() * 100.0), _on_flee)
		add_footer_button(UiText.t(&"combat_auto"), _on_auto)


func _build_item_list() -> void:
	var any := false
	for item in _session.player.inventory.get_consumables():
		if not item.usable_in_combat():
			continue
		any = true
		var text := UiText.t(&"inv_count") % [item.get_display_name(), _session.player.inventory.get_count(item)]
		add_row("%s\n%s" % [text, item.get_description()], UiText.t(&"combat_use"), _on_use_item.bind(item))
	if not any:
		add_text(UiText.t(&"combat_no_items"), true)


func _append(lines: PackedStringArray) -> void:
	_log.append_array(lines)
	while _log.size() > MAX_LOG_LINES:
		_log.remove_at(0)


func _after_action() -> void:
	_append(_session.take_messages())
	_showing_items = false
	_refresh()


func _on_attack() -> void:
	_session.attack()
	_after_action()


func _on_items() -> void:
	_showing_items = true
	_refresh()


func _on_back() -> void:
	_showing_items = false
	_refresh()


func _on_use_item(item: ItemData) -> void:
	_session.use_item(item)
	_after_action()


func _on_flee() -> void:
	_session.flee()
	_after_action()


func _on_auto() -> void:
	_session.auto_resolve()
	_after_action()


func _on_continue() -> void:
	var session := _session
	close()
	combat_finished.emit(session)
