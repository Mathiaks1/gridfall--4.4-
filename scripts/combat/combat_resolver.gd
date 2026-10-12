class_name CombatResolver
extends RefCounted
## Walka automatyczna (Faza 2): czysta funkcja, bez węzłów i bez losowości — łatwa do testów.
## Faza 3 (walka interaktywna) użyje tych samych wzorów obrażeń.

const MAX_ROUNDS := 100


class Result:
	extends RefCounted
	var won: bool = false
	var rounds: int = 0
	var damage_taken: int = 0
	var damage_dealt: int = 0


static func hit_damage(attack: int, defense: int) -> int:
	return maxi(attack - defense, 1)


## Gracz uderza pierwszy; tury naprzemiennie aż ktoś padnie. Nie modyfikuje argumentów.
static func resolve(player: PlayerStats, monster: MonsterInstance) -> Result:
	var result := Result.new()
	var player_hp := player.hp
	var monster_hp := monster.hp
	var player_hit := hit_damage(player.attack, monster.defense)
	var monster_hit := hit_damage(monster.attack, player.defense)
	while result.rounds < MAX_ROUNDS:
		result.rounds += 1
		var dealt := mini(player_hit, monster_hp)
		monster_hp -= dealt
		result.damage_dealt += dealt
		if monster_hp <= 0:
			result.won = true
			break
		var taken := mini(monster_hit, player_hp)
		player_hp -= taken
		result.damage_taken += taken
		if player_hp <= 0:
			break
	return result
