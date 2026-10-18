extends SceneTree

var failures = 0
func _init() -> void:
	call_deferred("run_tests")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	var training = level.get_node("CameraTraining")
	var director = level.get_node("TutorialIntro")
	var signs = level.get_node("Signposts")
	player.set_physics_process(false)
	training.set_process(false)
	training.set_physics_process(false)
	director.set_process(false)
	signs.set_process(false)
	var sky = level.get_node("OriginalSky")
	check(sky.mesh.get_surface_count() == 1 and sky.mesh.surface_get_array_len(0) == 11094,"All nine original sky pieces are separated")
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/data/scenery_data.json"))
	var world_vertices = 0
	for i in level.get_node("Scenery").mesh.get_surface_count(): world_vertices += level.get_node("Scenery").mesh.surface_get_array_len(i)
	var raw_vertices = 0
	for group in source.values(): raw_vertices += group["verts"].size()
	check(raw_vertices == world_vertices+11094,"Sky geometry is absent from the terrain mesh, with no geometry lost")
	player.set_state(player.WolfState.RUN)
	player.velocity = Vector3(8,5,0)
	player.can_double_jump = true
	training._show_dialogue(4)
	check(player.current_state == player.WolfState.IDLE and player.velocity == Vector3.ZERO and not player.run_active and not player.can_double_jump,"Dialogue cancels movement, running and airborne jump state")
	check(player.animation_player.current_animation == "idle" and not player.loop_audio_player.playing,"Dialogue cancels running animation/audio")
	check(training.card.get_theme_stylebox("panel").bg_color.a == 0 and training.body.get_theme_color("font_color") == Color.WHITE and training.body.get_theme_constant("outline_size") > 0,"Subtitles are transparent white outlined text")
	training.card.hide()
	player.tutorial_movement_locked = false
	for i in range(3):
		var entry = signs.signs[i]
		var p = entry["position"]
		var home = Vector3(p[0],p[1],-p[2])
		player.global_position = home+Vector3(float(entry["distance"])*0.6,0,float(entry["distance"])*0.6)
		check(signs.nearest_sign(player).is_empty(),"Signs use original Manhattan distance, not a wider circular radius")
		player.global_position = home
		player.set_state(player.WolfState.WALK)
		player.inventory.interact_or_use()
		check(int(signs.active_sign.get("res",0)) == int(entry["res"]) and player.tutorial_movement_locked and player.current_state == player.WolfState.IDLE,"E inventory interaction reads nearby sign and freezes neutral Ralph")
		check(signs.read_variants[int(entry["res"])] == i,"Original first-read order selects warning/question/white-line text")
		check(signs.text_box.visible and signs.text_box.font != null and signs.text_box.frame != null,"Signs show original DAV font/frame text box")
		check(not signs.hint.visible and not signs.body.text.contains("SEGURO"),"Signs are informational with no Yes/No question")
		signs.close_sign()
		check(not player.tutorial_movement_locked,"Closing sign restores controls")
		check(signs.interact(player) and signs.read_count == i+1,"Reading the same sign retains its variant")
		var confirm = InputEventAction.new()
		confirm.action = "action"
		confirm.pressed = true
		signs._input(confirm)
		check(signs.active_sign.is_empty() and signs.trap_time < 0 and not player.tutorial_movement_locked,"E closes every sign without anvil or trapped controls")
		signs._process(8.0)
		check(signs.trap_time < 0 and not signs.anvil.visible,"No delayed anvil starts after sign closes")
		signs.close_sign()
	player.set_state(player.WolfState.JUMP)
	player.velocity = Vector3(0,10,0)
	player.jump_timer = 0.1
	player.can_double_jump = true
	check(director.start_sequence(true),"Cinematic starts")
	check(player.current_state == player.WolfState.IDLE and not player.can_double_jump and player.jump_timer == 0 and player.velocity == Vector3.ZERO,"Cinematic interrupts existing jump")
	# Avoid automatic follow-up during isolated cleanup.
	training.enabled = false
	director.finish_sequence(false)
	check(player.current_state == player.WolfState.IDLE and player.animation_player.current_animation == "idle","Cinematic does not resume interrupted action")
	player.capture_mouse(false)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await physics_frame
	await physics_frame
	level.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Sky/signs/interruptions: ",failures," failures")
	quit(failures)
