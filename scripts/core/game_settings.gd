class_name GameSettings
extends RefCounted
## Ustawienia gracza (dźwięk, ekran, sterowanie) zapisywane w user://settings.cfg.

const PATH := "user://settings.cfg"

static var master_volume: float = 0.8
static var fullscreen: bool = false
static var vibration: bool = true
static var long_press_time: float = 0.4

static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		vibration = bool(cfg.get_value("input", "vibration", vibration))
		long_press_time = clampf(float(cfg.get_value("input", "long_press_time", long_press_time)), 0.2, 1.0)
	_loaded = true
	apply()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("input", "vibration", vibration)
	cfg.set_value("input", "long_press_time", long_press_time)
	cfg.save(PATH)


static func apply() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	# Tryb okna tylko na PC i tylko przy zmianie (okno osadzone w edytorze nie lubi przełączania)
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var current := DisplayServer.window_get_mode()
		var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if is_full != fullscreen:
			DisplayServer.window_set_mode(wanted)
