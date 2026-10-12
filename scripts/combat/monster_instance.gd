class_name MonsterInstance
extends RefCounted
## Konkretny potwór na planszy (MonsterData przeskalowane mocą piętra).

var data: MonsterData
var max_hp: int = 1
var hp: int = 1
var attack: int = 0
var defense: int = 0
var gold_reward: int = 0
var exp_reward: int = 0


func get_display_name() -> String:
	return UiText.t(data.name_key) if data else "?"


## Zapis rannego potwora (gracz uciekł z walki).
func to_dict() -> Dictionary:
	return {"id": data.id if data else &"", "hp": hp}
