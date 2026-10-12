extends SceneTree
## Runner testów. Uruchomienie (z katalogu projektu):
##   godot --headless --path . -s res://tests/run_tests.gd
## Kod wyjścia 0 = wszystko zielone, 1 = są błędy.

const SUITES: Array[String] = [
	"res://tests/test_grid_model.gd",
	"res://tests/test_rpg.gd",
]


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var suite: RefCounted = script.new()
			suite.call(method_name)
			var failures: PackedStringArray = suite.get("failures")
			if failures.is_empty():
				passed += 1
				print("  PASS  %s" % method_name)
			else:
				failed += 1
				print("  FAIL  %s" % method_name)
				for f in failures:
					print("        - %s" % f)
	print("Wynik: %d ok, %d błędów" % [passed, failed])
	quit(1 if failed > 0 else 0)
