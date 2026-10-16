extends Node
## Run selection persists across scene changes; the round owns all gameplay state.

var mode: String = "woods"
var next_seed: int = 0
var current_seed: int = 0


func begin_run() -> int:
	if next_seed > 0:
		current_seed = next_seed
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var previous := current_seed
		current_seed = rng.randi_range(1, 2147483646)
		while current_seed == previous:
			current_seed = rng.randi_range(1, 2147483646)
	next_seed = 0
	return current_seed


func load_game(retry: bool = false) -> void:
	next_seed = current_seed if retry else next_seed
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
