class_name ShopScreen
extends ModalScreen
## Sklep: kupno z asortymentu pola sklepu, sprzedaż przedmiotów z plecaka. Ceny: Economy.

var _player: PlayerStats
## Asortyment tego sklepu (współdzielona tablica — zakupy ją uszczuplają).
var _stock: Array[ItemData] = []
var _floor_number: int = 1
var _config: FloorConfig


func open_shop(player: PlayerStats, stock: Array[ItemData], floor_number: int, config: FloorConfig) -> void:
	_player = player
	_stock = stock
	_floor_number = floor_number
	_config = config
	title_label.text = UiText.t(&"shop_title")
	clear_footer()
	add_footer_button(UiText.t(&"common_close"), close)
	open_modal()
	_refresh()


func _refresh() -> void:
	subtitle_label.text = UiText.t(&"shop_gold") % _player.gold
	clear_list()

	add_section(UiText.t(&"shop_buy_section"))
	if _stock.is_empty():
		add_text(UiText.t(&"common_empty"), true)
	for item in _stock:
		var price := Economy.buy_price(item, _floor_number, _player, _config)
		add_row(_describe(item), UiText.t(&"shop_buy") % price, _on_buy.bind(item, price), _player.gold >= price)

	add_section(UiText.t(&"shop_sell_section"))
	var inv := _player.inventory
	var any := false
	for item in inv.get_consumables():
		any = true
		var text := UiText.t(&"inv_count") % [item.get_display_name(), inv.get_count(item)]
		add_row(text, UiText.t(&"shop_sell") % Economy.sell_price(item, 0, _config), _on_sell_consumable.bind(item))
	for inst in inv.gear:
		any = true
		var price := Economy.sell_price(inst.data, inst.upgrade_level, _config)
		add_row(inst.get_display_name(), UiText.t(&"shop_sell") % price, _on_sell_gear.bind(inst))
	if not any:
		add_text(UiText.t(&"common_empty"), true)


func _describe(item: ItemData) -> String:
	var text := "%s\n%s" % [item.get_display_name(), item.get_description()]
	if item.is_equipment():
		var bonus := ItemInstance.new(item)
		text += "\n" + UiText.t(&"stat_bonus") % [bonus.get_attack_bonus(), bonus.get_defense_bonus()]
	return text


func _on_buy(item: ItemData, price: int) -> void:
	if Economy.buy(_player, item, price):
		_stock.erase(item)
		EventBus.message_logged.emit(UiText.t(&"log_bought") % item.get_display_name())
	_refresh()


func _on_sell_consumable(item: ItemData) -> void:
	var price := Economy.sell_price(item, 0, _config)
	if Economy.sell_consumable(_player, item, _config):
		EventBus.message_logged.emit(UiText.t(&"log_sold") % [item.get_display_name(), price])
	_refresh()


func _on_sell_gear(inst: ItemInstance) -> void:
	var price := Economy.sell_price(inst.data, inst.upgrade_level, _config)
	if Economy.sell_gear(_player, inst, _config):
		EventBus.message_logged.emit(UiText.t(&"log_sold") % [inst.get_display_name(), price])
	_refresh()
