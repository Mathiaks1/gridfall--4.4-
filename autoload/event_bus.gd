extends Node
## Globalna magistrala zdarzeń rozgrywki (autoload "EventBus"). Tylko sygnały, bez stanu.
## Zasada: zdarzenia gry → EventBus; polecenia rodzic ↔ dziecko → zwykłe sygnały węzłów.

@warning_ignore("unused_signal")
signal run_started(run_seed: int)

@warning_ignore("unused_signal")
signal cells_revealed(cells: Array[Vector2i])

@warning_ignore("unused_signal")
signal hazard_triggered(cell: Vector2i)

@warning_ignore("unused_signal")
signal flags_changed(placed: int, hazard_total: int)

@warning_ignore("unused_signal")
signal grid_cleared

@warning_ignore("unused_signal")
signal flag_mode_changed(enabled: bool)
