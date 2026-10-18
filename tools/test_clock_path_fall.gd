extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool,message: String):
	if not value:
		failures += 1
		printerr(message)
func run_tests():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	var player: RalphController = level.player
	player.set_physics_process(false)
	var zone: OriginalFallZone = level.get_node("SecretClockPathFall")
	zone.set_physics_process(false)
	await physics_frame
	await physics_frame
	# Detect shallow hidden collision below the hole, which the generic depth
	# check legitimately treats as a reachable platform.
	var bottom = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4,1,4)
	collision.shape = box
	bottom.add_child(collision)
	level.add_child(bottom)
	bottom.position = Vector3(27,-8.5,-19)
	await physics_frame
	await physics_frame
	player.floor_probe_warmup = 0
	player.restart_fade_remaining = 0
	player.coyote_remaining = 0
	player.jump_void_grace = 0
	player.jump_origin_y = 0
	player.last_ground_y = 0
	player.global_position = Vector3(27,-3.1,-19)
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	check(is_finite(player.ground_drop()) and not player.check_void_below(),"Shallow bottom reproduces missed general raycast death")
	check(zone.check_fall(),"Local boundary catches the clock-path hole despite bottom collision")
	check(player.current_state == player.WolfState.PIT_FALL and player.animation_player.current_animation == "fall_death" and player.camera.top_level,"Local fall uses original animation and held death camera")
	player.set_state(player.WolfState.FALL)
	player.global_position.y = -2.9
	check(not zone.check_fall(),"No local death above the path's lower boundary")
	player.global_position.y = -3.1
	player.jump_void_grace = .1
	check(not zone.check_fall(),"Second-jump grace survives local volume")
	player.jump_void_grace = 0
	player.coyote_remaining = .1
	check(not zone.check_fall(),"Coyote time survives local volume")
	player.coyote_remaining = 0
	player.set_state(player.WolfState.RUN_AIR)
	check(not zone.check_fall(),"Active air run is not shortened by local boundary")
	player.set_state(player.WolfState.FALL)
	player.global_position.x = 37
	check(not zone.check_fall(),"The boundary does not affect other level routes")
	# Survey the imported path: every surface reachable from ground level must
	# sit above this safety boundary; deep hidden floors may lie underneath it.
	var surfaces = 0
	var lowest = INF
	for x in range(18,37):
		for z in range(-34,-11):
			var query = PhysicsRayQueryParameters3D.create(Vector3(x,.5,z),Vector3(x,-2.99,z))
			query.exclude = [player.get_rid(),bottom.get_rid()]
			var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				surfaces += 1
				lowest = minf(lowest,hit["position"].y)
	print("Clock path survey: ",surfaces," surfaces above boundary, lowest ",lowest)
	check(surfaces > 20,"Boundary covers the imported secret path rather than an empty map region")
	# User-marked gap farther up the dark rock path. These are real original
	# cliff faces, not the synthetic pit floor used by the first fixture.
	var upper: OriginalFallZone = level.get_node("SecretPathUpperGapFall")
	upper.set_physics_process(false)
	player.jump_origin_y = -1.9
	player.last_ground_y = -1.9
	player.velocity = Vector3.DOWN
	player.global_position = Vector3(30,-3.05,0)
	var cliff = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30,-2.5,0),Vector3(30,-10,0)))
	check(not cliff.is_empty() and cliff.normal.y < .5,"Marked hole ray intersects an original steep cliff face")
	check(is_finite(player.ground_drop()) and not player.check_void_below(),"Real cliff collision reproduces the missed general fall")
	check(not zone.check_fall() and upper.check_fall(),"New local boundary catches the marked hole outside the previous patch")
	var safe_surfaces = 0
	for x in range(28,40):
		for z in range(-5,5):
			var hit = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,3,z),Vector3(x,-80,z)))
			if not hit.is_empty() and hit.normal.y >= .707:
				safe_surfaces += 1
				check(hit.position.y >= upper.fall_height,"Upper boundary stays below neighbouring walkable terrain at %s" % hit.position)
	check(safe_surfaces > 10,"Upper pit boundary is surveyed against real neighbouring platforms")
	check(player.current_state == player.WolfState.PIT_FALL and player.animation_player.current_animation == "fall_death","Marked hole starts original death animation")
	player.set_state(player.WolfState.FALL)
	player.global_position = Vector3(35,-1.9,0)
	check(not upper.check_fall(),"Neighbouring dark path platform remains safe")
	player.global_position = Vector3(30,-3.05,0)
	player.jump_void_grace = .1
	check(not upper.check_fall(),"Marked gap preserves second-jump grace")
	player.jump_void_grace = 0
	player.coyote_remaining = .1
	check(not upper.check_fall(),"Marked gap preserves coyote time")
	player.coyote_remaining = 0
	player.set_state(player.WolfState.RUN_AIR)
	check(not upper.check_fall(),"Marked gap preserves active aerial running")
	player.set_state(player.WolfState.FALL)
	player.velocity = Vector3.DOWN
	check(upper.check_fall(),"Death begins after aerial running ends and Ralph falls below path")
	# Drive real movement frames across the marked pit, rather than testing
	# only the boundary predicate with a teleported actor.
	player.set_state(player.WolfState.FALL)
	player.global_position = Vector3(30,-2.0,0)
	player.jump_origin_y = -1.9
	player.last_ground_y = -1.9
	player.velocity = Vector3.DOWN
	var caught = false
	for i in range(120):
		await physics_frame
		player._physics_process(1.0/60)
		upper.check_fall()
		if player.current_state == player.WolfState.PIT_FALL:
			caught = true
			break
	check(caught,"Physical fall at the user-marked gap reaches PIT_FALL within two seconds")
	print("Marked gap movement result: ",player.global_position," state ",player.current_state)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	print("Local clock-path fall / finite bottom / jump and air protections: ",failures," failures")
	quit(1 if failures else 0)
