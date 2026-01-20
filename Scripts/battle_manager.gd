# BattleManager.gd
extends Node2D
class_name BattleManager

@onready var battle_log = $BattleUI/BattleLog

var player_node: Player
var current_monster = null
var is_battle_active = false

func _ready():
    visible = false
    print("BattleManager gotowy")

func start_battle(monster_data: Dictionary):
    print("🎯 Rozpoczynam walkę z ", monster_data["name"])
    
    player_node = get_tree().get_first_node_in_group("player")
    if not player_node:
        print("❌ Nie znaleziono gracza!")
        return
    
    # Stwórz potwora
    current_monster = {
        "name": monster_data["name"],
        "health": monster_data["health"],
        "max_health": monster_data["health"],
        "attack": monster_data["attack"],
        "defense": monster_data["defense"],
        "gold_drop": monster_data["gold_drop"],
        "exp_drop": monster_data["exp_drop"]
    }
    
    is_battle_active = true
    visible = true
    
    if battle_log:
        battle_log.text = "Walka z " + current_monster["name"] + "!\n"
    
    # Rozpocznij walkę
    start_battle_sequence()

func start_battle_sequence():
    while is_battle_active and player_node.current_hp > 0 and current_monster["health"] > 0:
        # Tura gracza
        await player_turn()
        if not is_battle_active:
            break
            
        # Tura potwora
        await monster_turn()
    
    end_battle()

func player_turn():
    if battle_log:
        battle_log.text += "\n--- Twoja tura ---"
        battle_log.text += "\nWybierz akcję: [1] Atak [2] Mikstura [3] Ucieczka"
    
    # Czekaj na input gracza (tymczasowo automatyczny atak)
    await get_tree().create_timer(1.0).timeout
    
    # Automatyczny atak
    var damage = max(1, player_node.attack - current_monster["defense"])
    current_monster["health"] -= damage
    
    if battle_log:
        battle_log.text += "\nAtakujesz! Zadajesz " + str(damage) + " obrażeń."

func monster_turn():
    if battle_log:
        battle_log.text += "\n--- Tura potwora ---"
    
    await get_tree().create_timer(1.0).timeout
    
    var damage = max(1, current_monster["attack"] - player_node.defense)
    player_node.take_damage(damage)
    
    if battle_log:
        battle_log.text += "\n" + current_monster["name"] + " atakuje! Zadaje " + str(damage) + " obrażeń."

func end_battle():
    is_battle_active = false
    
    if player_node.current_hp <= 0:
        if battle_log:
            battle_log.text += "\n💀 Zostałeś pokonany!"
        await get_tree().create_timer(2.0).timeout
        player_node.die()
    elif current_monster["health"] <= 0:
        if battle_log:
            battle_log.text += "\n🎉 Pokonałeś " + current_monster["name"] + "!"
        player_node.add_gold(current_monster["gold_drop"])
        player_node.add_experience(current_monster["exp_drop"])
        await get_tree().create_timer(2.0).timeout
        visible = false
    
    current_monster = null
