class_name SaveSystem
extends RefCounted
## Zapis runu w trybie „zapisz i wyjdź”: jeden slot, kasowany po wczytaniu i po śmierci (permadeath).
## Format binarny store_var — natywnie obsługuje Packed*Array, Vector2i i StringName.

const DEFAULT_PATH := "user://savegame.dat"
const SAVE_VERSION := 1

## Ścieżka podmieniana w testach.
static var save_path: String = DEFAULT_PATH


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: nie można zapisać %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	var payload := data.duplicate()
	payload["version"] = SAVE_VERSION
	file.store_var(payload)
	return true


## Zwraca pusty słownik, gdy brak zapisu albo wersja nie pasuje.
static func read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if data is Dictionary and int((data as Dictionary).get("version", 0)) == SAVE_VERSION:
		return data
	return {}


static func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
