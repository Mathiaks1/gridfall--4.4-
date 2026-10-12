class_name LevelUpScreen
extends ModalScreen
## Ekran awansu: rozdzielanie punktów atrybutów. Zmiany są wstępne do czasu „Zatwierdź”.

const ATTRIBUTE_KEYS: Array[StringName] = [
	&"attr_strength", &"attr_vitality", &"attr_luck", &"attr_charisma", &"attr_intelligence",
]

var _player: PlayerStats
var _pending := PackedInt32Array()


func open_level_up(player: PlayerStats) -> void:
	_player = player
	_pending = PackedInt32Array()
	_pending.resize(PlayerStats.ATTRIBUTE_COUNT)
	title_label.text = UiText.t(&"lvl_title") % player.level
	clear_footer()
	add_footer_button(UiText.t(&"lvl_reset"), _on_reset)
	add_footer_button(UiText.t(&"lvl_later"), close)
	add_footer_button(UiText.t(&"lvl_confirm"), _on_confirm)
	open_modal()
	_refresh()


func _remaining() -> int:
	var used := 0
	for v in _pending:
		used += v
	return _player.attribute_points - used


func _refresh() -> void:
	subtitle_label.text = UiText.t(&"lvl_points") % _remaining()
	clear_list()
	for i in range(PlayerStats.ATTRIBUTE_COUNT):
		var key := ATTRIBUTE_KEYS[i]
		var extra := " (+%d)" % _pending[i] if _pending[i] > 0 else ""
		var text := UiText.t(&"lvl_row") % [UiText.t(key), _player.attributes[i] + _pending[i], extra, UiText.t(StringName(String(key) + "_desc"))]
		add_row(text, UiText.t(&"lvl_plus"), _on_add.bind(i), _remaining() > 0)


func _on_add(index: int) -> void:
	if _remaining() > 0:
		_pending[index] += 1
	_refresh()


func _on_reset() -> void:
	_pending.fill(0)
	_refresh()


func _on_confirm() -> void:
	_player.apply_attribute_points(_pending)
	close()
