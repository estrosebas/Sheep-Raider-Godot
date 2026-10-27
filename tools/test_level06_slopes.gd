extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://slopes06_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level06.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var player = level.player
	var cine = level.get_node("LevelCinematics")
	if cine.active_movie: cine.active_movie.finish_sequence(true)
	cine.set_process(false); level.get_node("Sam_41").set_physics_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false
	var slopes = level.get_node("SlopeZones")
	var cameras = level.get_node("CameraZones")
	check(slopes.data.slide_boxes.size()==8 and slopes.data.ice_boxes.is_empty(),"Eight original SLIDEBOX regions, no invented ICEBOX")
	check(player.animation_player.has_animation("slope_slide") and player.animation_player.has_animation("sheep_carry_slide"),"Native SLIDE3/SLIDE4 imported for normal and carrying modes")
	if "--probe" in OS.get_cmdline_user_args():
		for z in range(-41,-8,2):
			var row = []
			for x in range(86,108,2):
				var ray = PhysicsRayQueryParameters3D.create(Vector3(x,25,z),Vector3(x,-15,z),1)
				ray.exclude = [player.get_rid()]
				var h = level.get_world_3d().direct_space_state.intersect_ray(ray)
				row.append("%d:%.1f"%[x,h.position.y] if not h.is_empty() else "%d:x"%x)
			print(z," "," ".join(row))
		quit(); return
	player.global_position = Vector3(94,13.5,-36.5)
	player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE)
	var slid = false; var reached = false; var start = player.global_position; var shot = -1
	var path = [Vector3(99,0,-32),Vector3(102,0,-28),Vector3(102,0,-23),Vector3(99,0,-20),Vector3(94,0,-17),Vector3(89,0,-15),Vector3(83,0,-14),Vector3(79,0,-13),Vector3(76,0,-12)]
	var waypoint = 0
	for i in range(600):
		var difference = path[waypoint]-player.global_position; difference.y = 0
		if difference.length()<1.8 and waypoint<path.size()-1: waypoint += 1
		var input = player.movement_camera_basis().inverse()*difference.normalized()
		for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
		Input.action_press("move_left",maxf(0,-input.x)); Input.action_press("move_right",maxf(0,input.x))
		Input.action_press("move_forward",maxf(0,-input.z)); Input.action_press("move_backward",maxf(0,input.z))
		await physics_frame
		slid = slid or slopes.active
		if cameras.camera_rule!=-1: shot = cameras.camera_rule
		reached = reached or (player.global_position.y<3 and player.global_position.x<78)
		if reached: break
	for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	print("slide final=",player.global_position," active=",slopes.active," camera=",shot)
	check(slid and player.global_position.distance_to(start)>5 and reached and player.current_state!=player.WolfState.PIT_FALL,"Ralph steers down the actual curved ramp using collision and native slope physics")
	check(shot in [85,87,101],"Original snowy slope camera restriction activates")
	# The native carrying bank selects SLIDE4 while the sheep stays attached.
	var sheep = level.get_node("Flock").sheep[0]
	sheep.set_physics_process(false); sheep.carried_by = player; player.carried_sheep = sheep
	player.global_position = Vector3(94,13.5,-36.5); player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE)
	slopes.reset(); cameras.release_camera()
	for i in range(35): await physics_frame
	check(slopes.active and player.animation_player.current_animation=="sheep_carry_slide" and sheep.carried_by==player,"Carrying Ralph slides using original mode1 pose without releasing the sheep")
	player.carried_sheep = null; sheep.carried_by = null
	slopes.reset(); cameras.release_camera()
	player.set_physics_process(false); player.global_position = Vector3(120,2,-90)
	cameras._process(.1)
	check(cameras.camera_rule==-1 and cameras.saved_camera.is_empty(),"Outside restriction volumes the player regains the original free camera settings")
	# Camera restriction enter AND exit must interpolate all lens/pose values.
	cameras.set_process(false)
	player.global_position = Vector3(-7.5,0,-37.8) # Native narrow bomb-area camera102.
	player.camera_pivot.rotation = Vector3(-.3,.8,0); player.camera_pivot.spring_length = 6; player.camera.fov = 70
	var baseline = cameras.camera_snapshot()
	cameras._process(.016)
	check(cameras.camera_rule==102 and absf(player.camera.fov-70)<.1 and absf(player.camera_pivot.spring_length-6)<.02,"Zone entry starts gently; focal length and distance do not jump")
	for i in range(60): cameras._process(.016)
	check(absf(player.camera_pivot.spring_length-3.4)<.01 and player.camera.fov<60,"Entry reaches the native bomb-area distance/focal after the blend")
	var inside = cameras.camera_snapshot()
	player.global_position = Vector3(120,2,-90)
	cameras._process(.016)
	check(cameras.camera_returning and absf(player.camera.fov-inside.fov)<.1 and absf(player.camera_pivot.rotation.y-inside.rotation.y)<.01,"Leaving starts a smooth return instead of assigning the saved free view")
	for i in range(65): cameras._process(.016)
	check(cameras.saved_camera.is_empty() and absf(player.camera.fov-baseline.fov)<.01 and absf(player.camera_pivot.spring_length-baseline.length)<.01,"Return finishes at original free camera values and releases ownership")
	# Re-enter during an unfinished exit without a jump or replacing free baseline.
	player.global_position = Vector3(-7.5,0,-37.8)
	for i in range(30): cameras._process(.016)
	player.global_position = Vector3(120,2,-90); cameras._process(.1)
	var reversing = cameras.camera_snapshot()
	player.global_position = Vector3(-7.5,0,-37.8); cameras._process(.016)
	check(not cameras.camera_returning and absf(player.camera.fov-reversing.fov)<.1 and absf(cameras.saved_camera.fov-baseline.fov)<.01,"Re-entering during return blends from the displayed pose and preserves free-view baseline")
	slopes.reset(); cameras.release_camera()
	# Active shot, not the free spring arm, defines the input frame.
	var view = Camera3D.new(); level.add_child(view)
	view.rotation.y = PI/2; view.make_current()
	player.camera_pivot.rotation.y = 0
	check(player.movement_camera_basis().x.dot(view.global_basis.x)>.99,"Controls adapt to the active launch shot instead of the hidden free camera")
	player.global_position = Vector3(81,14.05,-55)
	player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE); player.set_physics_process(true)
	var before = player.global_position
	Input.action_press("move_forward")
	for i in range(15): await physics_frame
	Input.action_release("move_forward")
	check((player.global_position-before).dot(-view.global_basis.z)>.2,"Actual forward input follows the visible camera while the free pivot faces elsewhere")
	view.rotation.x = -PI/2
	check(player.movement_camera_basis().x.is_finite() and absf(player.movement_camera_basis().determinant()-1)<.01,"Top-down restrictions retain a valid horizontal control basis")
	view.queue_free(); player.camera.make_current()
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level06 native slope zones / poses / camera / relative controls: ",failures," failures")
	quit(failures)
