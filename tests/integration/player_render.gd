extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(64,64)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for role in SurvivorRoster.IDS:
		var actor: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
		actor.role=role
		actor.position=Vector2(32,50)
		actor.local_input=false
		actor.get_node("Camera2D").enabled=false
		viewport.add_child(actor)
		actor.set_physics_process(false)
		for frame in range(6): await process_frame
		_check(actor.sheet!=null and actor.sheet.get_width()==72,"retained_sheet_"+role)
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw(true)
			var pixels := viewport.get_texture().get_image()
			var colors := {}
			for y in range(23,42):
				for x in range(20,44):
					var color := pixels.get_pixel(x,y)
					if color.a>0.9: colors[color.to_html()]=true
			_check(colors.size()>8,"actual_textured_survivor_"+role)
			pixels.save_png("res://artifacts/verification/survivor_render_"+role+".png")
		actor.queue_free()
		await process_frame
	var hud: CanvasLayer=load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var actor := CampPlayer.new()
	hud.update_belt(actor)
	_check(hud.belt_labels[0].text==">1 FLARE","belt_has_no_trailing_count")
	actor.free()
	hud.queue_free()
	viewport.queue_free()
	await process_frame
	print(JSON.stringify({"event":"test_result","suite":"player_render","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
