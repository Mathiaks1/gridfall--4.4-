class_name UiText
extends RefCounted
## Wszystkie teksty UI w jednym miejscu. Przy lokalizacji podmieniamy to na tr() + pliki tłumaczeń.

const _TEXTS := {
	&"hud_floor": "Piętro %d",
	&"hud_hazards": "Zagrożenia: %d / %d",
	&"hud_flag_mode": "Tryb flagi",
	&"hud_restart": "Restart",
	&"result_lost": "GAME OVER",
	&"result_won": "Piętro oczyszczone!",
	&"result_info": "Piętro: %d\nSeed: %d",
	&"result_restart": "Zagraj ponownie",
}


static func t(key: StringName) -> String:
	return str(_TEXTS.get(key, String(key)))
