class_name Hud
extends HFlowContainer
## Górny pasek: piętro, HP, złoto, poziom, statystyki, licznik zagrożeń, tryb flagi (dotyk),
## punkty atrybutów, ekwipunek, menu.
## HFlowContainer zawija elementy na wąskich (pionowych) ekranach.

signal inventory_pressed
signal points_pressed
signal menu_pressed

var _player: PlayerStats

@onready var _floor_label: Label = $FloorLabel
@onready var _hp_bar: ProgressBar = $HpBar
@onready var _hp_label: Label = $HpBar/HpLabel
@onready var _gold_label: Label = $GoldLabel
@onready var _level_label: Label = $LevelLabel
@onready var _stats_label: Label = $StatsLabel
@onready var _hazard_label: Label = $HazardLabel
@onready var _flag_mode_button: Button = $FlagModeButton
@onready var _points_button: Button = $PointsButton
@onready var _inventory_button: Button = $InventoryButton
@onready var _menu_button: Button = $MenuButton


func _ready() -> void:
	_inventory_button.text = UiText.t(&"hud_inventory")
	_menu_button.text = UiText.t(&"hud_menu")
	_points_button.hide()
	_flag_mode_button.text = UiText.t(&"hud_flag_mode")
	_flag_mode_button.visible = DisplayServer.is_touchscreen_available()
	_flag_mode_button.toggled.connect(_on_flag_mode_toggled)
	_inventory_button.pressed.connect(inventory_pressed.emit)
	_points_button.pressed.connect(points_pressed.emit)
	_menu_button.pressed.connect(menu_pressed.emit)
	EventBus.flags_changed.connect(_on_flags_changed)
	EventBus.floor_started.connect(_on_floor_started)


## Podpina statystyki gracza nowego runu.
func bind_player(player: PlayerStats) -> void:
	if _player and _player.changed.is_connected(_refresh_player):
		_player.changed.disconnect(_refresh_player)
	_player = player
	_player.changed.connect(_refresh_player)
	_refresh_player()


func _refresh_player() -> void:
	_hp_bar.max_value = _player.get_max_hp()
	_hp_bar.value = _player.hp
	_hp_label.text = UiText.t(&"hud_hp") % [_player.hp, _player.get_max_hp()]
	_gold_label.text = UiText.t(&"hud_gold") % _player.gold
	_level_label.text = UiText.t(&"hud_level") % [_player.level, _player.experience, _player.get_exp_to_next_level()]
	_stats_label.text = UiText.t(&"hud_stats") % [_player.get_attack(), _player.get_defense()]
	_points_button.visible = _player.attribute_points > 0
	_points_button.text = UiText.t(&"hud_points") % _player.attribute_points


func _on_floor_started(floor_number: int) -> void:
	_floor_label.text = UiText.t(&"hud_floor") % floor_number


func _on_flags_changed(placed: int, hazard_total: int) -> void:
	# Pozostałe = wszystkie zagrożenia − (flagi + już odkryte); może zejść poniżej zera przy błędnych flagach
	_hazard_label.text = UiText.t(&"hud_hazards") % [hazard_total - placed, hazard_total]


func _on_flag_mode_toggled(enabled: bool) -> void:
	EventBus.flag_mode_changed.emit(enabled)
