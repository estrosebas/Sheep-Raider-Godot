extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool, message: String):
	if not value:
		failures += 1
		printerr(message)
func native_basis(encoded: Array) -> Basis:
	# Independent transcription of clockwise key helpers + Mat44::SetRotYXZ.
	var x = -float(encoded[0])
	var y = float(encoded[1])
	var z = float(encoded[2])
	var cx = cos(x); var sx = sin(x)
	var cy = cos(y); var sy = sin(y)
	var cz = cos(z); var sz = sin(z)
	var native = Basis(Vector3(cy*cz-sx*sy*sz,cy*sz+sx*sy*cz,-cx*sy),Vector3(-cx*sz,cx*cz,sx),Vector3(sy*cz+sx*cy*sz,sy*sz-sx*cy*cz,cx*cy))
	var reflection = Basis.from_scale(Vector3(1,-1,1))
	return reflection*native*reflection
func run_tests():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	for i in range(60): await physics_frame
	var player: RalphController = level.player
	var sam: OriginalSam = level.get_node("Sam_43")
	player.set_physics_process(false)
	player.global_position = Vector3(8.91,.11,12.73)
	sam.set_physics_process(false)
	sam.set_process(false)
	sam.reset_guard()
	sam.initialized = true
	sam.head_yaw = 0
	sam.clip_time = 0
	sam._process(0)
	for joint in [11,12,13,15,17,18,19]:
		var source = sam.visual.rig["animations"]["head2"]["frames"][0]["joints"][joint]["rot"]
		var expected = native_basis(source).get_rotation_quaternion()
		check(absf(expected.dot(sam.visual.skeleton.get_bone_pose_rotation(joint))) > .99999,"Sam joint %d matches original clockwise YXZ matrix" % joint)
	var skin = sam.visual.legacy_skin
	check(skin.last_matrices[15].origin.y > 1.3 and absf(skin.last_matrices[15].origin.x) < .25,"HEAD2 hand touches forehead, not a T pose")
	check(skin.last_matrices[19].origin.y < .9 and absf(skin.last_matrices[19].origin.x) < .2,"HEAD2 other hand rests at waist")
	sam.head_yaw = .7
	sam._process(0)
	check(absf(sam.visual.skeleton.get_bone_pose_rotation(9).dot(Quaternion(Vector3.UP,.7))) > .99999,"SetJointOverride follows positive native override angle")
	check(skin.last_matrices[15].origin.distance_to(skin.last_matrices[21].origin) < .5,"Forehead hand follows upper-body sweep")
	sam._enter(sam.State.CHASE,"run1")
	check(is_equal_approx(sam.movement_speed(),11),"Original level 01 chase speed is 1100 units/s")
	sam._enter(sam.State.RETURN_HOME,"run2")
	check(is_equal_approx(sam.movement_speed(),11),"CHASE_CAMERA does not select ALT_BEHAVIOUR's 200 units/s return")
	var original_mode = sam.rules["mode"]
	sam.rules["mode"] = 0x20000
	sam.global_position = sam.home+Vector3(1,0,1)
	check(is_equal_approx(sam.movement_speed(),2),"Alternate behaviour walks only near home")
	sam.global_position = sam.home+Vector3(5,0,1)
	check(is_equal_approx(sam.movement_speed(),11),"Alternate behaviour runs when far from home")
	sam.rules["mode"] = original_mode
	sam.reset_guard()
	player.global_position = sam.home+Vector3(0,0,5)
	var chase_origin = sam.global_position
	sam._enter(sam.State.CHASE,"start")
	sam.set_physics_process(true)
	for i in range(6): await physics_frame
	sam.set_physics_process(false)
	var traveled = Vector2(sam.global_position.x-chase_origin.x,sam.global_position.z-chase_origin.z).length()
	check(traveled > .8 and traveled < 1.3,"Actual collision movement covers ~1.1m in 100ms at native chase speed")
	player.global_position = Vector3(8.91,.11,12.73)
	# Real collision-world returns from different sides of the territory.
	for position in [Vector3(-41.14,1,-42.94),Vector3(-44.91,1,-46.18),Vector3(-32.69,1,-51.45),Vector3(-5.95,1,-44.04),Vector3(7.34,1,-37.95),Vector3(10.06,1,-52.05)]:
		sam.reset_guard()
		var ground = sam._ground(position)
		check(ground != null,"Navigation fixture has ground %s" % position)
		if ground == null: continue
		sam.global_position = ground+Vector3.UP*.01
		print("Start ground ",ground)
		sam._enter(sam.State.RETURN_HOME,"run2")
		sam.set_physics_process(true)
		var frames = 0
		while sam.state != sam.State.GUARD and frames < 1800:
			await physics_frame
			frames += 1
		sam.set_physics_process(false)
		print("Return from ",position," frames ",frames," end ",sam.global_position," remaining ",sam.global_position.distance_to(sam.home))
		check(sam.state == sam.State.GUARD and sam.global_position.distance_to(sam.home) < .7,"Sam returns without teleporting from %s" % position)
	sam.reset_guard()
	player.global_position = Vector3(-50,1,-50)
	sam._enter(sam.State.CHASE,"start")
	sam.set_physics_process(true)
	var gave_up = false
	for i in range(900):
		await physics_frame
		if sam.state in [sam.State.RETURN_HOME,sam.State.GUARD]: gave_up = true
		if gave_up and sam.state == sam.State.GUARD: break
	check(gave_up and sam.state == sam.State.GUARD,"Actual pursuit to unreachable/outside territory returns to guard without getting stranded")
	sam.set_physics_process(false)
	# A wall appears across an already selected route: native stall recovery
	# must search another approach, rather than replaying the same waypoint.
	sam.reset_guard()
	player.global_position = Vector3(8.91,.11,12.73)
	var obstacle = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3,2,.4)
	collision.shape = box
	obstacle.add_child(collision)
	level.add_child(obstacle)
	obstacle.global_position = sam.home+Vector3(0,1,3)
	var origin = sam._ground(sam.home+Vector3(0,0,6))
	check(origin != null,"Blocked-route fixture has terrain")
	if origin != null:
		sam.global_position = origin+Vector3.UP*.01
		sam._enter(sam.State.RETURN_HOME,"run2")
		sam.path.append(sam.home)
		sam.route_target = sam.home
		sam.set_physics_process(true)
		var recovered = false
		for i in range(1200):
			await physics_frame
			if not sam.blocked_nodes.is_empty(): recovered = true
			if sam.state == sam.State.GUARD: break
		print("Wall recovery ",recovered," state ",sam.state," position ",sam.global_position," route ",sam.path)
		check(recovered and sam.state == sam.State.GUARD,"Blocked route recovers through authored nodes and returns around a solid wall")
		sam.set_physics_process(false)
	obstacle.queue_free()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop()
	level.queue_free()
	await process_frame
	print("Sam navigation / native speeds / authored guard pose: ",failures," failures")
	quit(1 if failures else 0)
