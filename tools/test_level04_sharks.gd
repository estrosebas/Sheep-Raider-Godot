extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func step(shark,count: int):
	for i in range(count):
		shark._physics_process(1.0/60)
		await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level04_sharks_test_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	level.get_node("LevelCinematics").set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_42").set_physics_process(false); level.get_node("bull_60").set_physics_process(false)
	var player = level.player
	player.set_physics_process(false); player.cinematic_controls_locked = false
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	player.water_motion.reset(player); player.set_state(player.WolfState.IDLE)
	var sharks = get_nodes_in_group("sharks")
	check(sharks.size()==2,"Two native Shark50 controllers replace decorative actors")
	for shark in sharks:
		shark.set_physics_process(false)
		check(shark.initialized and shark.route.size()==12,"Each shark reads its own 12-waypoint WAR patrol")
		var start: Vector3 = shark.global_position
		await step(shark,60)
		print("Shark ",shark.name," patrol displacement ",shark.global_position.distance_to(start)," / speed ",shark.velocity.length())
		check(shark.state==shark.State.PATROL and shark.global_position.distance_to(start)>2.8 and absf(shark.velocity.length()-3.5)<.01,"Actual river collisions permit native 3.5m/s patrol")
		check(absf(shark.global_position.y-start.y)<.001,"Patrol holds original spawn depth, without floor snapping")
		check(shark.breath.frames.size()==3 and shark.ripples.frames.size()==3,"Native DAV bubble and ripple frames loaded")
		var visited = {shark.waypoint:true}
		var iterations = 0
		while iterations<1200:
			await step(shark,1); iterations += 1
			visited[shark.waypoint] = true
			if visited.size()==12 and shark.waypoint==0: break
		print(shark.name," patrol waypoints visited ",visited.size()," / seconds ",iterations/60.0)
		check(visited.size()==12 and shark.waypoint==0,"Complete native patrol loop crosses every waypoint without getting stuck on terrain or raft")
	var shark = level.get_node("Shark_61")
	# Safe dry bank/raft and neighboring water outside this shark's BOX.
	player.global_position = Vector3(shark.global_position.x,.1,shark.global_position.z)
	await step(shark,3)
	check(shark.state==shark.State.PATROL and shark.bite_count==0,"Standing above water never triggers a shark attack")
	player.global_position = Vector3(-50,-3,3)
	check(not shark.can_detect(),"Swimming outside the shark's native BOX does not trigger it")
	# Real native upper-river volume; >6.4m away intentionally tests the
	# recovered 9600 literal instead of silently substituting the property.
	shark.global_position = Vector3(-47.5,-2.95,-14)
	player.global_position = Vector3(-47.5,-2.95,0)
	check(shark.can_detect() and is_equal_approx(float(shark.definition.authored_detect_range),6.4),"Source uses 96m within assigned BOX, despite authored DETECTRANGE=6.4m")
	await step(shark,1)
	check(shark.state==shark.State.AIM and shark.clip=="stand1","Entering water starts original STAND1 aim")
	await step(shark,117)
	check(shark.state==shark.State.AIM,"Aim holds for two seconds, with no early lunge")
	await step(shark,4)
	check(shark.state==shark.State.WIND_UP and shark.clip=="stand2","Two-second aim transitions to native STAND2 wind-up")
	var safety = 0
	while shark.state==shark.State.WIND_UP and safety<60:
		await step(shark,1); safety += 1
	check(shark.state==shark.State.LUNGE and is_equal_approx(shark.lunge_velocity.length(),9),"STAND2 completion launches at native 9m/s")
	var captured: Vector3 = shark.lunge_to
	var aimed: Vector3 = shark.lunge_velocity
	player.global_position.x += 2
	await step(shark,1)
	check(shark.lunge_to==captured and shark.lunge_velocity==aimed,"Lunge targets the captured position without homing")
	# Miss and return across actual terrain, then resume the authored route.
	player.global_position = Vector3(7,17,17)
	await step(shark,1)
	check(shark.state==shark.State.MISS,"Leaving assigned BOX aborts with ATTACK1")
	await step(shark,240)
	check(shark.state==shark.State.PATROL and absf(shark.global_position.y-shark.home_height)<.02,"Miss/brake/reverse restores native patrol depth")
	# A nearby swimmer is bitten immediately, with paired EAT origin/pose.
	shark.global_position = Vector3(-47,-2.95,-12)
	player.global_position = shark.global_position+Vector3(.5,0,0)
	player.set_state(player.WolfState.SWIM)
	await step(shark,1)
	check(shark.state==shark.State.BITE and shark.bite_accepted and shark.bite_count==1,"Within 1.6m, the original close-bite accepts KILL_SHARK")
	check(player.current_state==player.WolfState.SAM_DEATH and player.sam_death_clip()=="shark_death","Wolf uses its extracted EAT animation, not piranha or falling death")
	check(player.global_position==shark.global_position and player.skeleton.rotation.is_equal_approx(shark.rotation),"Wolf and Shark EAT share source origin and orientation")
	check(absf(player.animation_player.get_animation("shark_death").length-float(shark.visual.rig.animations.eat.duration))<.001,"Paired native EAT animations last 5.07s")
	var fixed_view: Transform3D = player.camera.global_transform
	await step(shark,190)
	check(shark.played_cues.slice(-3)==[138,136,74],"EAT fires original bite/impact cues 138,136,74 at their native animation times")
	check(player.camera.global_transform.is_equal_approx(fixed_view),"Death camera remains fixed and clear of river walls")
	await step(shark,250)
	var before_reset: Vector3 = shark.global_position
	var index = shark.waypoint
	player.respawn_at_checkpoint()
	check(not shark.bite_accepted and shark.global_position==before_reset and shark.waypoint==index,"Checkpoint reset releases kill latch without teleporting the patrol")
	await step(shark,20)
	check(shark.state==shark.State.PATROL and shark.global_position.distance_to(before_reset)>.5,"Shark resumes swimming after death and checkpoint return")
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	shark.global_position = Vector3(-47,-2.95,-8)
	player.global_position = Vector3(-42,-2.95,-8); player.set_state(player.WolfState.SWIM)
	await step(shark,300)
	print("Natural lunge state ",shark.state," / travel ",shark.lunge_traveled," / bites ",shark.bite_count)
	check(shark.state==shark.State.BITE and shark.bite_count==2 and shark.lunge_traveled>3,"Full native aim/wind-up/lunge crosses real river geometry and kills swimmer")
	if DisplayServer.get_name()!="headless":
		player.camera.current = true
		player.camera.global_position = shark.global_position+Vector3(4,2,5)
		player.camera.look_at(shark.global_position,Vector3.UP)
		root.size = Vector2i(1280,720)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_shark_patrol.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level04 sharks failures: ",failures)
	quit(1 if failures else 0)
