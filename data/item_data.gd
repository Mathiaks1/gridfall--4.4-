class_name ItemData
extends Resource
## Definicja przedmiotu: mikstury, zwoje, granaty, broń, zbroja.

enum Kind { CONSUMABLE, WEAPON, ARMOR }
enum Effect { NONE, HEAL, SCRY, RETURN, GRENADE }

@export var id: StringName
## Klucze tekstów w UiText.
@export var name_key: StringName
@export var desc_key: StringName
@export var kind: Kind = Kind.CONSUMABLE
@export var effect: Effect = Effect.NONE
## Siła efektu: leczenie (HP), obrażenia granatu w walce, promień zwoju odkrycia / wybuchu granatu.
@export var power: int = 0
## Promień działania na planszy (zwój odkrycia, granat).
@export_range(0, 4) var radius: int = 1
@export var price: int = 10
@export_range(1, 100) var min_floor: int = 1
@export var sold_in_shop: bool = true
@export var found_in_treasure: bool = true

@export_group("Equipment")
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var attack_per_upgrade: int = 0
@export var defense_per_upgrade: int = 0

@export_group("Visuals (optional)")
@export var color := Color.WHITE
@export var icon: Texture2D


func is_equipment() -> bool:
	return kind != Kind.CONSUMABLE


## Przedmiot wymaga wskazania pola na planszy.
func needs_target() -> bool:
	return effect == Effect.SCRY or effect == Effect.GRENADE


func usable_in_combat() -> bool:
	return effect == Effect.HEAL or effect == Effect.GRENADE or effect == Effect.RETURN


func usable_on_board() -> bool:
	return effect == Effect.HEAL or effect == Effect.SCRY or effect == Effect.GRENADE


func get_display_name() -> String:
	return UiText.t(name_key)


func get_description() -> String:
	return UiText.t(desc_key) if desc_key != &"" else ""
