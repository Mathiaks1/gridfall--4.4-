extends Control
## Menu główne: nowa gra, kontynuacja zapisu, opcje, wyjście.

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_screen: OptionsScreen = %OptionsScreen


func _ready() -> void:
	GameSettings.ensure_loaded()
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(false)
	_title_label.text = UiText.t(&"menu_title")
	_subtitle_label.text = UiText.t(&"menu_subtitle")
	_new_game_button.text = UiText.t(&"menu_new")
	_continue_button.text = UiText.t(&"menu_continue")
	_options_button.text = UiText.t(&"menu_options")
	_quit_button.text = UiText.t(&"menu_quit")
	_continue_button.disabled = not SaveSystem.has_save()
	# Na iOS i w przeglądarce aplikacji się nie zamyka
	_quit_button.visible = not (OS.has_feature("ios") or OS.has_feature("web"))

	_new_game_button.pressed.connect(func() -> void: GameFlow.new_game(get_tree()))
	_continue_button.pressed.connect(func() -> void: GameFlow.continue_game(get_tree()))
	_options_button.pressed.connect(_options_screen.open_options)
	_quit_button.pressed.connect(get_tree().quit)
	(_continue_button if not _continue_button.disabled else _new_game_button).grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _options_screen.visible:
			_options_screen.close()
		else:
			get_tree().quit()
