extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://elastic_clock05_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({})
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level); current_scene = level; await frames(30)
	var cine = level.get_node("LevelCinematics")
	if cine.active_movie: cine.active_movie.finish_sequence(true)
	cine.set_process(false)
	level.get_node("Sam_56").set_physics_process(false)
	level.get_node("bull_60").set_physics_process(false)
	var actor = level.player
	var elastic = level.get_node("elastic_86").controller
	var a = level.get_node("ElasticTree_62"); var b = level.get_node("ElasticTree_67")
	check(elastic.max_length==10 and elastic.projection_distance==32 and elastic.projection_height==12 and elastic.projection_speed==10,"Keep native Level05 dimensions, range, height and speed")
	# A small step or jump used to launch at16% tension: a5.25m/1.97m arc.
	# Level05 uses the same full-charge guard as Level03, without changing force.
	elastic.reset_item(); elastic.tie_first(a,actor); elastic.tree_b = b; elastic.mode = "strung"
	actor.set_physics_process(false); actor.cinematic_controls_locked = false
	actor.global_position = (a.anchor()+b.anchor())*.5+Vector3(0,.3,3)
	actor.set_state(actor.WolfState.JUMP); actor.velocity = Vector3.ZERO; actor.ground_distance = INF
	elastic.engaged = true; elastic.engaged_side = elastic.project(actor.global_position).side
	elastic.modify_move(actor,1.0/60)
	check(elastic.tension>0 and elastic.tension<1 and elastic.flight.is_empty(),"Brief airborne contact at partial tension cannot fire a short shot")
	elastic.reset_item(); elastic.tie_first(a,actor); elastic.tree_b = b; elastic.mode = "strung"
	actor.interrupt_actions(); actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	var midpoint = (a.global_position+b.global_position)*.5
	var clock = level.get_node("TimeKeeper_61")
	var retreat = midpoint-Vector3(0,0,-25); retreat.y = 0; retreat = retreat.normalized()
	actor.global_position = midpoint-retreat*.15+Vector3.UP*.08
	actor.camera_pivot.rotation.y = atan2(-retreat.x,-retreat.z); actor.velocity = Vector3.ZERO
	actor.jump_origin_y = null; actor.floor_probe_warmup = 3
	actor.set_state(actor.WolfState.IDLE); actor.set_physics_process(true)
	await frames(6)
	Input.action_press("move_forward"); Input.action_press("run")
	var launched = false; var furthest = actor.global_position.z; var charge = 0.0
	var full_frame = -1; var launch_frame = -1; var landing = Vector3.ZERO
	for i in range(500):
		# Original turbo uses repeated taps; holding Shift alone expires.
		if i%15==0: Input.action_release("run")
		if i%15==1: Input.action_press("run")
		await physics_frame
		if full_frame<0 and elastic.tension>=1: full_frame = i
		if not elastic.flight.is_empty() and not launched:
			launched = true; charge = elastic.flight.charge; launch_frame = i
			print("LAUNCH ",elastic.flight)
			check(elastic.flight.distance==40 and elastic.flight.height==12,"Only this spring uses the40m access profile and native12m peak")
			Input.action_release("move_forward"); Input.action_release("run")
		if launched: furthest = minf(furthest,actor.global_position.z)
		if launched and elastic.flight.is_empty():
			landing = actor.global_position
			print("END ",landing," full-charge hold=",(launch_frame-full_frame)/60.0); break
	Input.action_release("move_forward"); Input.action_release("run")
	check(launched and charge==1,"Level05 spring reaches full force before launch")
	check(full_frame>=0 and launch_frame-full_frame>=58,"Full stretch leaves about one second to keep running and aim")
	check(furthest<-20 and landing.x<3 and landing.y>7,"Arc reaches the actual entrance above the clock chamber")
	actor.camera_pivot.rotation.y = 0
	Input.action_press("move_forward")
	for i in range(90):
		await physics_frame
		if actor.global_position.y<0 and actor.is_on_floor(): break
	Input.action_release("move_forward")
	check(actor.is_on_floor() and actor.global_position.y<-3 and actor.current_state!=actor.WolfState.PIT_FALL,"Entrance allows the actual descent to the chamber floor")
	var direction = clock.global_position-actor.global_position; direction.y = 0
	actor.camera_pivot.rotation.y = atan2(-direction.x,-direction.z)
	Input.action_press("move_forward")
	for i in range(100):
		await physics_frame
		if clock.can_interact(actor): break
	Input.action_release("move_forward")
	print("CLOCK ACCESS ",actor.global_position," usable=",clock.can_interact(actor))
	check(clock.can_interact(actor),"After the spring and descent, Ralph can actually interact with the clock")
	check(elastic.projection_for(level.get_node("Flock").sheep[0]).distance==32,"Slingshot cargo retains native32m distance")
	elastic.tree_b = level.get_node("ElasticTree_65")
	check(elastic.projection_for(actor).distance==32,"Other tree combinations retain native32m distance")
	# Complete the round trip: the clock chamber's native CLIMBBOXES exit.
	var zone = level.get_node("ClimbZone_0")
	check(zone.bounds.position.is_equal_approx(Vector3(-4,-4.13,-23.25)) and is_equal_approx(zone.bounds.end.y,6.86),"Climb region has native coordinates, direction and height")
	direction = Vector3(1,-3.99,-22.6)-actor.global_position; direction.y = 0
	actor.camera_pivot.rotation.y = atan2(-direction.x,-direction.z)
	Input.action_press("move_forward")
	for i in range(120):
		await physics_frame
		if zone.can_interact(actor): break
	Input.action_release("move_forward")
	check(actor.inventory.interaction_target()==zone,"Native contextual action finds vines inside the chamber")
	actor.inventory.interact_or_use(); await frames(8)
	check(actor.current_state==actor.WolfState.CLIMB and actor.climb_motion.climbing(),"E grabs the vines through the shared inventory/action route")
	check(actor.animation_player.current_animation=="climb_idle" and actor.loop_audio_player.playing,"Original idle grip animation and SND_SCOCOLD loop")
	var start_y = actor.global_position.y
	Input.action_press("move_forward"); await frames(35); Input.action_release("move_forward")
	check(actor.global_position.y>start_y+.4 and actor.animation_player.current_animation=="climb_up","W climbs at native profile6 speed")
	start_y = actor.global_position.y
	Input.action_press("move_backward"); await frames(20); Input.action_release("move_backward")
	check(actor.global_position.y<start_y-.2 and actor.animation_player.current_animation=="climb_down","S descends with originalCLIMB2")
	Input.action_press("move_left"); await frames(20); Input.action_release("move_left")
	check(actor.animation_player.current_animation=="climb_left","A selects originalCLIMB3")
	Input.action_press("move_right"); await frames(20); Input.action_release("move_right")
	check(actor.animation_player.current_animation=="climb_right","D selects originalCLIMB4")
	actor.inventory.interact_or_use(); await frames(1)
	check(not actor.climb_motion.active() and actor.current_state!=actor.WolfState.CLIMB and not actor.loop_audio_player.playing,"E releases the grip and stops the idle sound")
	check(zone.interact(actor),"Can re-grip while falling inside the native zone")
	Input.action_press("jump"); await frames(4); Input.action_release("jump")
	check(actor.current_state==actor.WolfState.JUMP and not actor.climb_motion.active() and actor.velocity.y>0,"Jump releases into normal jump state")
	# Reset within the actual zone after this deliberate jump-away check.
	actor.global_position = Vector3(1,-3.98,-22.7); actor.velocity = Vector3.ZERO
	actor.set_state(actor.WolfState.FALL); actor.floor_probe_warmup = 3; await frames(4)
	check(zone.interact(actor),"Grab again for complete chamber exit")
	actor.camera_pivot.rotation.y = PI*.5 # Looking sideways must not change W into horizontal motion.
	Input.action_press("move_forward")
	var top_exit = false
	for i in range(850):
		await physics_frame
		if i==350 and DisplayServer.get_name()!="headless":
			root.size = Vector2i(1280,720)
			var preview = Camera3D.new(); level.add_child(preview)
			preview.global_position = actor.global_position+Vector3(-2.5,1.2,-4.5)
			preview.look_at(actor.global_position+Vector3.UP*.8); preview.current = true
			actor.set_physics_process(false)
			for frame in range(5): await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/level05_climbing.png")
			actor.camera.current = true; preview.queue_free(); actor.set_physics_process(true)
		if actor.climb_motion.state==actor.climb_motion.State.TOP_EXIT: top_exit = true
		if top_exit and not actor.climb_motion.active(): break
	Input.action_release("move_forward"); await frames(4)
	print("CLOCK EXIT ",actor.global_position," grounded=",actor.is_on_floor()," state=",actor.current_state)
	check(top_exit and not actor.climb_motion.active() and actor.is_on_floor() and actor.global_position.z>-21 and actor.global_position.y>1,"Native top transition clears the window and returns Ralph to playable terrain")
	check(actor.can_use_inventory(),"Climb exit restores inventory and normal controls")
	actor.global_position = Vector3(1,0,-22.7); actor.velocity = Vector3.ZERO
	actor.set_state(actor.WolfState.FALL); zone.interact(actor)
	actor.interrupt_actions()
	check(not actor.climb_motion.active() and actor.current_state==actor.WolfState.IDLE,"Cinematic interruption clears grip, sounds and animation state")
	zone.interact(actor); actor.set_state(actor.WolfState.SAM_DEATH)
	check(not actor.climb_motion.active(),"Death clears the climb controller before respawn")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level05 elastic clock: ",failures," failures"); quit(failures)
