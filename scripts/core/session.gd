extends Node
## Run selection persists across scene changes; the round owns all gameplay state.

var notice := ""
var survivor: String = "christian"
var needs_survivor_selection := false
## F8: local meta progress and whether this run is today's Daily Night.
var profile := CampProfile.new()
var daily := false

func _ready() -> void:
	RoundPlan.force_all_escapes = "--all-escapes" in OS.get_cmdline_user_args()
	if "--no-modifiers" in OS.get_cmdline_user_args():
		RoundPlan.force_modifiers = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--headline="):
			RoundPlan.force_headline = argument.get_slice("=", 1)
	var saved := ConfigFile.new()
	if saved.load("user://survivor.cfg") == OK:
		var previous := str(saved.get_value("player", "role", "christian"))
		needs_survivor_selection = previous not in SurvivorRoster.IDS
		survivor = SurvivorRoster.valid(previous)
		if needs_survivor_selection: notice = "New four-survivor roster: choose your character."

func select_survivor(id: String) -> void:
	survivor = SurvivorRoster.valid(id)
	needs_survivor_selection = false
	var saved := ConfigFile.new()
	saved.set_value("player", "role", survivor)
	saved.save("user://survivor.cfg")

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
