extends RefCounted
## Bazowa klasa zestawu testów: metody test_* + proste asercje zbierające błędy.

var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (oczekiwano %s, jest %s)" % [message, str(expected), str(actual)])
