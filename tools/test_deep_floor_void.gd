extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool,message: String):
	if not value:
		failures += 1
		printerr(message)
func run_tests():
	var world = Node3D.new()
	root.add_child(world)
	var bottom = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(20,1,20)
	collision.shape = box
	bottom.add_child(collision)
	world.add_child(bottom)
	bottom.position.y = -31.5
	var player: RalphController = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.capture_mouse(false)
	await physics_frame
	await physics_frame
	player.floor_probe_warmup = 0
	player.coyote_remaining = 0
	player.jump_void_grace = 0
	player.last_ground_y = 0
	player.jump_origin_y = 0
	player.global_position = Vector3(0,-1.1,0)
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	check(is_finite(player.ground_drop()) and player.ground_drop() < RalphAirRules.PIT_DROP,"Ray sees finite pit bottom less than 30m below current feet")
	check(player.check_void_below() and player.current_state == player.WolfState.PIT_FALL,"31m hole remains fatal after descending below first takeoff minus 1m")
	check(player.animation_player.current_animation == "pit_fall" and player.camera.top_level,"Finite-bottom pit uses original STRIKE2 and held camera")
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 0
	player.floor_probe_warmup = 0
	player.jump_origin_y = 0
	player.global_position = Vector3(0,1,0)
	player.velocity = Vector3.UP
	player.set_state(player.WolfState.JUMP)
	check(not player.check_void_below(),"Deep finite bottom preserves jump ascent")
	player.set_state(player.WolfState.FALL)
	player.velocity = Vector3.DOWN
	player.global_position.y = -.99
	check(not player.check_void_below(),"Original takeoff margin still protects the final jump apex/descent")
	player.global_position.y = -1.1
	player.jump_void_grace = .1
	check(not player.check_void_below(),"Final second-jump grace remains protected")
	player.jump_void_grace = 0
	player.jump_origin_y = null
	player.coyote_remaining = .1
	check(not player.check_void_below(),"Walking off a deep hole preserves coyote time")
	player.coyote_remaining = 0
	check(player.check_void_below(),"Walking fall is fatal when finite bottom is too far below original ground")
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 0
	player.floor_probe_warmup = 0
	player.global_position = Vector3(0,0,0)
	player.jump_origin_y = 0
	player.last_ground_y = 0
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	bottom.position.y = -3.5
	await physics_frame
	await physics_frame
	player.global_position.y = -1.1
	check(not player.check_void_below(),"Reachable platform 3m below takeoff remains a normal fall")
	for node in world.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	world.queue_free()
	await process_frame
	await process_frame
	# Real terrain immediately beyond the secret clock's narrow ledge.
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	var ralph: RalphController = level.player
	ralph.set_physics_process(false)
	await physics_frame
	await physics_frame
	ralph.floor_probe_warmup = 0
	ralph.coyote_remaining = 0
	ralph.jump_void_grace = 0
	ralph.jump_origin_y = .05
	ralph.last_ground_y = .05
	ralph.global_position = Vector3(32,-1.1,-26)
	ralph.velocity = Vector3.DOWN
	ralph.set_state(ralph.WolfState.FALL)
	check(is_inf(ralph.ground_drop()),"Actual clock ledge has void at x32/z-26")
	check(ralph.check_void_below() and ralph.current_state == ralph.WolfState.PIT_FALL,"Clock route hole starts authored pit animation after protected jump height")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	print("Deep finite ground / takeoff depth / jump and coyote protections: ",failures," failures")
	quit(1 if failures else 0)
