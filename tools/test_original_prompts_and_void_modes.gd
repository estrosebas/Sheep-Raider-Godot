extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.2).timeout
	var player = level.player
	player.set_physics_process(false)
	var sheep = level.get_node("Sheep_52")
	var prompt = player.get_node("ActionPrompt")
	check(prompt.label_for(sheep) == "LLEVAR","Native Spanish CTX_LIFT is LLEVAR")
	sheep.carried_by = player
	check(prompt.label_for(sheep) == "COLOCAR","Native carried sheep HELD_THROWABLE is COLOCAR")
	sheep.carried_by = null
	check(prompt.label_for(level.get_node("PorkyLessons").salads[0]) == "COGER","Native pickup CTX_PICKUP is COGER")
	player.global_position = Vector3(-300,15,-300)
	player.set_state(player.WolfState.FALL)
	var camera_view = player.camera.global_transform
	var camera_local = player.camera.transform
	player.set_state(player.WolfState.PIT_FALL)
	check(player.animation_player.current_animation == "fall_death" and player.camera.top_level,"Ordinary fatal drop uses DEAD1 and frozen camera")
	check(player.camera.global_transform.is_equal_approx(camera_view),"Direct death preserves the exact trigger camera view")
	var height = player.global_position.y
	player.state_time = .5
	player.step_pit_fall(.1)
	check(player.global_position.y < height and player.velocity.y < 0,"Direct death physically descends")
	check(player.camera.global_transform.is_equal_approx(camera_view),"Direct descent does not move or rotate the camera")
	player.state_time = player.direct_fall_impact_time
	player.global_position.y -= 100 # Fixed camera is now beyond the old 30m sound range.
	player.step_pit_fall(.1)
	check(player.direct_fall_impact_played and player.velocity.y == 0,"Shorter direct fall hits at two seconds and stops descending")
	check(player.void_impact_audio is AudioStreamPlayer and player.void_impact_audio.playing and player.void_impact_audio.stream.resource_path.ends_with("original_void_impact.wav"),"Original impact plays at the shortened hit time independent of camera distance")
	player.void_impact_audio.seek(.2)
	player.state_time += .1; player.step_pit_fall(.1)
	check(player.void_impact_audio.get_playback_position() >= .19,"Impact is not retriggered during the restart transition")
	player.respawn_at_checkpoint()
	check(not player.camera.top_level and player.camera.transform.is_equal_approx(camera_local),"Respawn restores the attached gameplay camera")
	player.restart_fade_remaining = 0
	player.set_state(player.WolfState.RUN_AIR)
	player.set_state(player.WolfState.PIT_FALL)
	check(player.animation_player.current_animation == "pit_fall" and player.camera.top_level,"Air run exhaustion retains STRIKE2 and held camera")
	height = player.global_position.y
	player.state_time = .5
	player.step_pit_fall(.1)
	check(player.global_position.y == height,"Theatrical air-run reaction stays stationary")
	player.respawn_at_checkpoint()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Native Spanish prompts / direct void / air run void: ",failures," failures")
	quit(1 if failures else 0)
