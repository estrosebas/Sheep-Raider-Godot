extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://delivery_clock_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level07.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(50): await physics_frame
	var player = level.player; var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false); player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false
	player.set_physics_process(false)
	for actor in get_nodes_in_group("sam_guards")+get_nodes_in_group("sheep_targets")+get_nodes_in_group("buried_minefields"): actor.set_physics_process(false)
	var mailbox = level.get_node("Mailbox_59"); var item = mailbox.items[0]
	check(mailbox.delivery_wait_seconds()>3.5,"High delivery shot lasts through falling box and opening")
	var previous_assists = GameLocalization.camera_assists_enabled()
	GameLocalization.camera_assists = false
	mailbox._deliver(player)
	check(mailbox.delivery_camera.current,"Original delivery camera activates even when gameplay assists are disabled")
	var box = mailbox.boxes[0]; var start = box.global_position.y
	for i in range(30): await physics_frame
	check(box.global_position.y<start-3 and not item.visible,"Mailbox creates actual falling box, item stays hidden")
	for i in range(280): await physics_frame
	check(not is_instance_valid(box) and item.visible and item.available,"Box plays opening and releases detector")
	var query = PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*.2,item.global_position-Vector3.UP*.3,1)
	var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and absf(item.global_position.y-hit.position.y)<.03,"Released detector falls from upper rim to actual ground")
	mailbox._release_camera(); GameLocalization.camera_assists = previous_assists
	var ball = level.get_node("Snowball_63"); ball.set_physics_process(false)
	player.global_position = ball.global_position-Vector3(.6,.5,.6); player.set_state(player.WolfState.IDLE)
	player.velocity = Vector3.DOWN; player.move_and_slide()
	if ball.can_interact(player):
		check(ball.interact(player),"Snowball accepts diagonal approach")
		check(ball.push_direction.abs()==Vector3.RIGHT or ball.push_direction.abs()==Vector3.BACK,"Snowball matches native nearest-quarter-turn push axis")
		player.item_actions.cancel()
	else: check(false,"Player can approach snowball on actual floor")
	var clock = level.get_node("TimeKeeper_62")
	check(clock.visual.rig.animations.has("clock1") and clock.physical_root!=null,"Original clock model, animations and owned collision loaded")
	player.global_position = clock.global_position+Vector3(.6,.05,0); player.velocity = Vector3.DOWN
	player.ground_distance = 0; player.last_ground_y = player.global_position.y; player.jump_origin_y = null
	for i in range(8): player.move_and_slide(); await physics_frame
	check(clock.can_interact(player) and clock.interact(player),"Original clock is reachable and interactable in its alcove")
	check(OriginalProgress.has_clock("lvl_07"),"Clock updates the level progress flag")
	player.item_actions.cancel(); player.restart_fade.hide()
	check(level.get_node("CameraZones").data.cameras.size()==11 and level.get_node("CameraZones").data.cameras.filter(func(r): return not r.trajectory.is_empty()).size()==6,"All native eleven camera volumes and six paths present")
	for id in [36,37,39,42]: check(level.get_node("SensibleButton_%d"%id).switch_camera!=null,"Gate mechanism camera present")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.global_position = clock.global_position+Vector3(1.6,1.5,2.4); camera.look_at(clock.global_position+Vector3.UP*.8); camera.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level07_clock.png")
	for audio in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): audio.stop(); audio.stream = null
	level.queue_free(); await process_frame
	print("Level07 delivery / gravity / clock / full camera import / snowball directions: ",failures," failures")
	quit(failures)
