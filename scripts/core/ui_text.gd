class_name UiText
extends RefCounted
## Wszystkie teksty UI w jednym miejscu. Przy lokalizacji podmieniamy to na tr() + pliki tłumaczeń.

const _TEXTS := {
	# HUD
	&"hud_floor": "Piętro %d",
	&"hud_hazards": "Zagrożenia: %d / %d",
	&"hud_hp": "HP %d / %d",
	&"hud_gold": "Złoto: %d",
	&"hud_level": "Poz. %d  (%d / %d EXP)",
	&"hud_stats": "ATK %d  DEF %d",
	&"hud_flag_mode": "Tryb flagi",
	&"hud_restart": "Restart",
	# Dziennik
	&"log_run_start": "Schodzisz do lochów. Piętro %d.",
	&"log_descend": "Schodzisz niżej: piętro %d. Odzyskujesz %d HP.",
	&"log_exit_found": "Widzisz schody w dół. Dotknij ich, by zejść niżej.",
	&"log_trap": "Pułapka! Tracisz %d HP.",
	&"log_combat_win": "%s pokonany (%d rund). Tracisz %d HP, +%d złota, +%d EXP.",
	&"log_combat_lose": "%s zadaje ci śmiertelny cios.",
	&"log_treasure": "Skarb! +%d złota.",
	&"log_level_up": "Awans na poziom %d! Pełne HP.",
	# Ekran końca gry
	&"result_lost": "GAME OVER",
	&"result_info": "Piętro: %d   Poziom: %d   Złoto: %d\nSeed: %d",
	&"result_restart": "Zagraj ponownie",
	# Potwory
	&"monster_rat": "Szczur",
	&"monster_goblin": "Goblin",
	&"monster_skeleton": "Szkielet",
	&"monster_orc": "Ork",
}


static func t(key: StringName) -> String:
	return str(_TEXTS.get(key, String(key)))
