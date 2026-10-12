class_name CombatSession
extends RefCounted
## Walka turowa: akcja gracza (atak / przedmiot / ucieczka), potem odpowiedź potwora.
## Bez węzłów — UI (CombatScreen) tylko wywołuje akcje i wyświetla komunikaty. Losowość z przekazanego RNG.

enum Outcome { ONGOING, WON, LOST, FLED }

const AUTO_MAX_ROUNDS := 200

var player: PlayerStats
var monster: MonsterInstance
var outcome: Outcome = Outcome.ONGOING
var rounds: int = 0
var damage_taken: int = 0

var _rng: RandomNumberGenerator
var _messages := PackedStringArray()


func _init(p_player: PlayerStats, p_monster: MonsterInstance, p_rng: RandomNumberGenerator) -> void:
	player = p_player
	monster = p_monster
	_rng = p_rng


static func hit_damage(attack: int, defense: int) -> int:
	return maxi(attack - defense, 1)


func is_over() -> bool:
	return outcome != Outcome.ONGOING


## Komunikaty od ostatniego wywołania (dla dziennika walki).
func take_messages() -> PackedStringArray:
	var result := _messages
	_messages = PackedStringArray()
	return result


func attack() -> void:
	if is_over():
		return
	rounds += 1
	_player_strike()
	_monster_turn()


## Zużywa przedmiot z ekwipunku. Zwraca false, jeśli nie można go użyć.
func use_item(item: ItemData) -> bool:
	if is_over() or not item.usable_in_combat() or not player.inventory.remove_consumable(item):
		return false
	rounds += 1
	var power := roundi(item.power * player.get_item_power_multiplier())
	match item.effect:
		ItemData.Effect.HEAL:
			_log(UiText.t(&"combat_heal") % player.heal(power))
		ItemData.Effect.GRENADE:
			var dealt := mini(power, monster.hp)
			monster.hp -= dealt
			_log(UiText.t(&"combat_grenade") % dealt)
			if monster.hp <= 0:
				_win()
		ItemData.Effect.RETURN:
			outcome = Outcome.FLED
			_log(UiText.t(&"combat_return"))
			return true
	_monster_turn()
	return true


## Ucieczka: szansa zależna od Szczęścia; nieudana = potwór atakuje.
func flee() -> void:
	if is_over():
		return
	rounds += 1
	if _rng.randf() < player.get_flee_chance():
		outcome = Outcome.FLED
		_log(UiText.t(&"combat_flee_ok"))
		return
	_log(UiText.t(&"combat_flee_fail"))
	_monster_turn()


## Rozgrywa resztę walki samymi atakami.
func auto_resolve() -> void:
	var guard := 0
	while not is_over() and guard < AUTO_MAX_ROUNDS:
		attack()
		guard += 1


func _player_strike() -> void:
	var damage := hit_damage(player.get_attack(), monster.defense)
	var crit := _rng.randf() < player.get_crit_chance()
	if crit:
		damage = roundi(damage * player.crit_multiplier)
	damage = mini(damage, monster.hp)
	monster.hp -= damage
	_log(UiText.t(&"combat_crit" if crit else &"combat_hit") % damage)
	if monster.hp <= 0:
		_win()


func _monster_turn() -> void:
	if is_over():
		return
	var damage := mini(hit_damage(monster.attack, player.get_defense()), player.hp)
	player.take_damage(damage)
	damage_taken += damage
	_log(UiText.t(&"combat_monster_hit") % [monster.get_display_name(), damage])
	if player.is_dead():
		outcome = Outcome.LOST
		_log(UiText.t(&"combat_lost"))


func _win() -> void:
	outcome = Outcome.WON
	_log(UiText.t(&"combat_won") % monster.get_display_name())


func _log(text: String) -> void:
	_messages.append(text)
