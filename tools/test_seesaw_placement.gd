extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var player = level.player
	var environment = level.get_node("LevelEnvironment"); environment.set_physics_process(false)
	level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_51").set_physics_process(false)
	var board = environment.seesaw
	var lettuce = level.get_node("Salad_74")
	for side in [-1,1]:
		board.tilt = 0; board.tilt_velocity = 0; board.rotation = Vector3.ZERO; board.contact_ids.clear()
		board.timers = [0.0,0.0]
		player.cinematic_controls_locked = false; player.restart_fade_remaining = 0
		player.set_state(player.WolfState.FALL)
		player.global_position = board.global_position+Vector3(side*(board.half_length-.25),0,0)
		player.global_position.y = board.surface_height(player.global_position)+.1
		for i in range(30): await physics_frame
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		for i in range(35): environment._physics_process(.04); await physics_frame
		var before = board.tilt
		player.tutorial_movement_locked = true
		for i in range(20): environment._physics_process(.04); await physics_frame
		check(absf(board.tilt)>=absf(before)*.9 and board.contact_ids.has(player.get_instance_id()),"Placing/locked Ralph retains seesaw weight at side "+str(side))
		var placement = OriginalPlacement.probe(player,lettuce,true)
		check(not placement.is_empty() and placement.support==board,"Lettuce placement accepts tilted edge at side "+str(side))
		if not placement.is_empty():
			lettuce.holder = null; lettuce.available = true; lettuce.deployed = true; lettuce.global_position = placement.position
			OriginalPlacement.follow_support(lettuce,placement)
			var local_point = board.to_local(lettuce.global_position)
			board.rotation.z += .05
			await physics_frame; await physics_frame
			var expected = board.to_global(local_point)
			var ray = PhysicsRayQueryParameters3D.create(lettuce.global_position+Vector3.UP*.3,lettuce.global_position-Vector3.UP*.3)
			ray.exclude = [player.get_rid()]
			var hit = level.get_world_3d().direct_space_state.intersect_ray(ray)
			check(Vector2(lettuce.global_position.x-expected.x,lettuce.global_position.z-expected.z).length()<.01 and not hit.is_empty() and absf(lettuce.global_position.y-hit.position.y-.005)<.02,"Placed lettuce follows rotation and rests on the actual inclined collider")
		player.tutorial_movement_locked = false; player.set_physics_process(true)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED; level.queue_free(); await process_frame
	print("Seesaw edge placement / rider weight / attached lettuce: ",failures," failures"); quit(failures)
