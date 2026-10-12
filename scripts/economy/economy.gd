class_name Economy
extends RefCounted
## Ceny w sklepie i kupno/sprzedaż. Czyste funkcje — balans w FloorConfig i ItemData.


static func buy_price(item: ItemData, floor_number: int, player: PlayerStats, config: FloorConfig) -> int:
	var base := item.price * (1.0 + config.shop_price_growth * maxi(floor_number - 1, 0))
	return maxi(roundi(base * player.get_price_multiplier()), 1)


## Ulepszony sprzęt sprzedaje się drożej (+50% ceny bazowej za poziom).
static func sell_price(item: ItemData, upgrade_level: int, config: FloorConfig) -> int:
	return maxi(roundi(item.price * (1.0 + 0.5 * upgrade_level) * config.sell_price_ratio), 1)


static func buy(player: PlayerStats, item: ItemData, price: int) -> bool:
	if not player.spend_gold(price):
		return false
	player.inventory.add_item(item)
	return true


static func sell_consumable(player: PlayerStats, item: ItemData, config: FloorConfig) -> bool:
	if not player.inventory.remove_consumable(item):
		return false
	player.add_gold(sell_price(item, 0, config))
	return true


static func sell_gear(player: PlayerStats, inst: ItemInstance, config: FloorConfig) -> bool:
	if not player.inventory.remove_gear(inst):
		return false
	player.add_gold(sell_price(inst.data, inst.upgrade_level, config))
	return true
