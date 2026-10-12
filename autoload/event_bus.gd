extends Node
## Globalna magistrala zdarzeń rozgrywki (autoload "EventBus"). Tylko sygnały, bez stanu.
## Zasada: zdarzenia gry → EventBus; polecenia rodzic ↔ dziecko → zwykłe sygnały węzłów.

@warning_ignore("unused_signal")
signal run_started(run_seed: int)

@warning_ignore("unused_signal")
signal floor_started(floor_number: int)

@warning_ignore("unused_signal")
signal cells_revealed(cells: Array[Vector2i])

## Pole wymaga reakcji gry: uruchomione zagrożenie albo dotknięte pole specjalne.
@warning_ignore("unused_signal")
signal cell_activated(cell: Vector2i, content: GridModel.Content)

@warning_ignore("unused_signal")
signal flags_changed(placed: int, hazard_total: int)

@warning_ignore("unused_signal")
signal flag_mode_changed(enabled: bool)

## Wpis do dziennika komunikatów (już przetłumaczony tekst).
@warning_ignore("unused_signal")
signal message_logged(text: String)

@warning_ignore("unused_signal")
signal player_died
