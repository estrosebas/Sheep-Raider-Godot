extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://seesaw03_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_63").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var environment = level.get_node("LevelEnvironment")
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false; player.tutorial_movement_locked = false
	var board = environment.seesaws.filter(func(b): return int(b.definition.res)==52)[0]
	var rock = level.get_node("Rock_60")
	player.global_position = Vector3(100,10,100)
	for i in range(90): await physics_frame
	check(rock.seesaw_support==board,"Second rock starts supported on the correct native seesaw")
	var trigger = board.definition.ejection_boxes[0]
	player.global_position = TutorialProgress.center(trigger)
	await physics_frame; await physics_frame
	check(board.timers[0]>3.9,"Source upper-left trigger arms Ralph's incoming landing")
	var near_edge = "--edge" in OS.get_cmdline_user_args()
	player.global_position = board.global_position+(Vector3(-4.1,0,.85) if near_edge else Vector3(-3,0,.12))
	player.global_position.y = board.surface_height(player.global_position)+.4
	player.velocity = Vector3.DOWN*8; player.set_state(player.WolfState.FALL); player.set_physics_process(true)
	var launched_rock = false; var launched_player = false; var highest = player.global_position.y
	var free_camera = "--free-camera" in OS.get_cmdline_user_args()
	var trace = PackedStringArray()
	for i in range(210):
		await physics_frame
		launched_rock = launched_rock or not rock.arc.is_empty()
		if free_camera and is_instance_valid(environment.launch_camera):
			environment.launch_camera.close()
		if near_edge and i==30: player.global_position.z = board.global_position.z+1.1
		launched_player = launched_player or not environment.arc.is_empty()
		highest = maxf(highest,player.global_position.y)
		if not environment.arc.is_empty() and environment.arc.time>.25 and environment.arc.time<.9:
			var target = OriginalSeesaw.arc_point(environment.arc.start,environment.arc.middle,environment.arc.end,environment.arc.time/1.024)
			check(player.global_position.distance_to(target)<.05,"Launch arc owns Ralph's position even after the camera is dismissed")
		if i<85: trace.append("t=%d p=%s pv=%s r=%s rv=%s impact=%f ra=%f pa=%f contacts=%d tilt=%f"%[i,player.global_position,player.velocity,rock.global_position,rock.velocity,rock.landed_speed,rock.arc.get("time",-1),environment.arc.get("time",-1),board.contact_ids.size(),board.tilt])
	check(launched_rock,"Ralph's landing launches the source rock upward")
	check(launched_player,"Returning rock launches Ralph toward the next section")
	check(highest>10,"Ralph reaches the upper section along authored trajectory")
	var expected = OriginalSeesaw.source_point(board.definition.trajectories[0][2])
	check(environment.arc.is_empty() and Vector2(player.global_position.x-expected.x,player.global_position.z-expected.z).length()<.25,"Full flight finishes at the original next-section endpoint")
	check(board.launch_count==2,"One rock impact launches each participant once")
	check(player.is_on_floor() and player.current_state in [player.WolfState.IDLE,player.WolfState.LAND],"Ralph actually lands on the next ledge instead of freezing in FALL above it")
	check(not player.launch_controls_locked and not is_instance_valid(environment.launch_camera),"Landing releases the launch camera and its input lock without pressing a skip key")
	if is_instance_valid(environment.launch_camera):
		environment.launch_camera.close(); await process_frame
	check(not player.cinematic_controls_locked and not player.tutorial_movement_locked and not player.seesaw_launching and player.camera.current,"Closing native launch camera restores gameplay at the destination")
	check(not player.get_collision_exceptions().has(board) and environment.launch_support==null,"Takeoff exception is removed after leaving the plank")
	var before_move = player.global_position
	Input.action_press("move_right")
	for i in range(10): await physics_frame
	Input.action_release("move_right")
	check(player.global_position.distance_to(before_move)>.1 and player.can_use_inventory(),"Actual movement input works immediately after automatic landing/camera return")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900); player.set_process(true)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.global_position = player.global_position+Vector3(-3,2.6,4)
		camera.look_at(player.global_position+Vector3.UP*.85); camera.current = true
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_seesaw_landed.png")
		camera.queue_free(); player.camera.current = true
	# A cinematic/death/respawn can interrupt an external launch. It must
	# release both its movement ownership and temporary support exception.
	player.global_position = board.global_position+Vector3(-3,3,0)
	board.contact_ids[player.get_instance_id()] = true
	environment.launch(player,board.definition.trajectories[0])
	check(player.seesaw_launching and player.get_collision_exceptions().has(board),"Native takeoff initially excludes only its launching plank")
	player.interrupt_actions(); await physics_frame; await physics_frame
	check(environment.arc.is_empty() and not player.seesaw_launching and not player.tutorial_movement_locked and not player.get_collision_exceptions().has(board),"Interrupting launch restores normal movement and collision")
	if failures: printerr("\n".join(trace))
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level03 second seesaw / returning rock / Ralph launch: ",failures," failures")
	quit(failures)
