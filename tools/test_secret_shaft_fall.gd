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
	var zone: OriginalFallZone = level.get_node("SecretPathEntryShaftFall")
	zone.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.floor_probe_warmup = 0
	player.jump_void_grace = 0
	player.coyote_remaining = 0
	player.jump_origin_y = -1.5
	player.last_ground_y = -1.5
	player.global_position = Vector3(27,-2.7,20)
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	var bottom = player.global_position.y-player.ground_drop()
	check(absf(bottom+9.51) < .01,"Exact rectangular shaft has original green bottom at -9.51m")
	check(not player.check_void_below(),"Original green floor is too shallow to trigger the general 30m pit rule")
	check(not zone.check_fall(),"A remaining 1.35m second-jump rise still permits recovery near the lip")
	player.global_position.y = -2.9
	check(zone.check_fall(),"Below first takeoff minus second-jump reach triggers authored fall")
	check(player.animation_player.current_animation == "fall_death" and player.camera.top_level,"Shaft uses original fall animation and fixed death camera")
	player.set_state(player.WolfState.FALL)
	player.global_position.y = -3.2
	player.jump_void_grace = .1
	check(not zone.check_fall(),"Second-jump grace remains protected")
	player.jump_void_grace = 0
	player.coyote_remaining = .1
	check(not zone.check_fall(),"Coyote time remains protected")
	player.coyote_remaining = 0
	player.set_state(player.WolfState.JUMP)
	check(not zone.check_fall(),"Jump ascent remains protected")
	player.set_state(player.WolfState.RUN_AIR)
	check(not zone.check_fall(),"Running flight remains protected")
	player.set_state(player.WolfState.FALL)
	player.velocity = Vector3.DOWN
	player.global_position = Vector3(28.5,-3.2,20)
	check(not zone.check_fall(),"Shaft boundary does not kill Ralph on a neighbouring route")
	player.global_position = Vector3(27,-1.5,20)
	check(not zone.check_fall(),"Shaft boundary stays below the walking surface")
	player.jump_origin_y = -.5
	player.global_position.y = -1.8
	check(not zone.check_fall(),"A different first takeoff changes the recovery threshold")
	player.global_position.y = -1.9
	check(zone.check_fall(),"Recovery threshold follows first takeoff rather than a fixed world height")
	# Test a player already grounded on the decorative green bottom.
	player.set_state(player.WolfState.IDLE)
	player.global_position = Vector3(27,-9.505,20)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	player.velocity = Vector3.ZERO
	player.jump_origin_y = null
	player.last_ground_y = -9.51
	player.coyote_remaining = player.coyote_time
	check(player.is_on_floor(),"Fixture lands on the original green bottom")
	check(zone.check_fall(),"Landing on the pit bottom cannot reset the fatal-drop origin")
	# Run actual gravity and collision frames at the confirmed hole.
	player.set_state(player.WolfState.FALL)
	player.global_position = Vector3(27,-1.55,20)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	player.jump_origin_y = -1.5
	player.last_ground_y = -1.5
	player.coyote_remaining = 0
	player.jump_void_grace = 0
	var death_position = Vector3.ZERO
	for i in range(120):
		await physics_frame
		player._physics_process(1.0/60)
		zone.check_fall()
		if player.current_state == player.WolfState.PIT_FALL:
			death_position = player.global_position
			break
	check(death_position.y < -2.85 and death_position.y > -9,"Physical fall dies after recovery height and before reaching the green floor")
	var death_frames = ceili((player.direct_fall_impact_time+OriginalRestartFade.DURATION+.2)*60)
	for i in range(death_frames):
		await physics_frame
		player._physics_process(1.0/60)
		zone.check_fall()
		if player.current_state != player.WolfState.PIT_FALL: break
	check(player.current_state != player.WolfState.PIT_FALL and player.global_position.distance_to(death_position) > 3,"Authored death completes and returns Ralph to checkpoint")
	print("Confirmed shaft physics death at ",death_position,"; respawn ",player.global_position)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	print("Exact entry shaft / jump recovery / aerial guards / original death and respawn: ",failures," failures")
	quit(1 if failures else 0)
