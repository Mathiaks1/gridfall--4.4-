# Player.gd
extends Node2D
class_name Player

var gold = 0
var current_hp = 100
var max_hp = 100
var experience = 0
var level = 1
var attack = 10
var defense = 5

func _ready():
    add_to_group("player")
    print("Player załadowany. HP: ", current_hp)

func take_damage(amount: int):
    current_hp -= amount
    if current_hp < 0:
        current_hp = 0
    print("Gracz otrzymał ", amount, " obrażeń. HP: ", current_hp, "/", max_hp)
    
    if current_hp <= 0:
        die()

func die():
    print("💀 Gracz umarł! Restart gry.")
    get_tree().reload_current_scene()

func heal(amount: int):
    current_hp = min(max_hp, current_hp + amount)
    print("Gracz uleczony o ", amount, " HP. HP: ", current_hp, "/", max_hp)

func add_gold(amount: int):
    gold += amount
    print("Zdobyto ", amount, " złota. Razem: ", gold)

func add_experience(amount: int):
    experience += amount
    print("Zdobyto ", amount, " EXP. Razem: ", experience)
    
    # Prosty system poziomów
    if experience >= level * 100:
        level_up()

func level_up():
    level += 1
    max_hp += 10
    current_hp = max_hp
    attack += 2
    defense += 1
    print("🎉 Awans na poziom ", level, "!")
