extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool,message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func run_tests():
	SaveFiles.startup_offered = true
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	var player: RalphController = level.player
	player.set_physics_process(false)
	await frames(4)
	var clock: OriginalTimeKeeper = level.get_node("TimeKeeper_65")
	check(clock.level_id == level.manifest["level"] and clock.sound_bank_path == level.asset_directory+"/data/ai_audio.json","Level loader supplies clock's level and audio configuration")
	var native_position = Vector3(30.88,0,-26.18)
	check(Vector2(clock.global_position.x-native_position.x,clock.global_position.z-native_position.z).length() < .001,"Clock keeps native XZ placement")
	player.global_position = player.respawn_ground_position(clock.global_position+Vector3(-.8,0,0))
	for i in range(8):
		await physics_frame
		player._physics_process(1.0/60)
	check(player.is_on_floor() and clock.can_interact(player),"Original alcove has a grounded usable approach")
	check(absf(clock.visual.position.y+clock.model_bounds.position.y) < .001,"Clock mesh base is aligned with the ground")
	player.global_position = player.respawn_ground_position(clock.global_position+Vector3(-1.1,0,0))
	check(clock.can_interact(player),"Clock is reachable from its edge beyond the previous 1m origin cutoff")
	player.global_position.y += 2
	player.velocity.y = 1
	check(not clock.can_interact(player),"Clock cannot be used from above during a jump")
	player.global_position = player.respawn_ground_position(clock.global_position+Vector3(-.8,0,0))
	player.velocity = Vector3.ZERO
	var key = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key)
	check(clock.state == clock.State.RINGING and OriginalProgress.has_clock("lvl_01") and OriginalProgress.bonus_points == 1,"Normal E interaction awards original clock once")
	await create_timer(player.animation_player.get_animation("timekeeper_use").length+.2).timeout
	# Same class and assets, independent level identity; no duplicated script.
	for identity in ["lvl_02","lvl_16"]:
		var next = OriginalTimeKeeper.new()
		next.level_id = identity
		next.asset_directory = clock.asset_directory
		next.sound_bank_path = clock.sound_bank_path
		level.add_child(next)
		next.global_position = clock.global_position
		await frames(2)
		check(absf(next.global_position.y-clock.global_position.y) < .01,"Clock ground probe avoids the alcove roof")
		check(next.can_interact(player),"Previously collected clock does not disable another level: "+identity)
		var before = OriginalProgress.bonus_points
		check(next.interact(player),"Shared timekeeper works with level configuration: "+identity)
		check(OriginalProgress.bonus_points-before == (2 if identity == "lvl_16" else 1),"Original reward amount for "+identity)
		check(not next.can_interact(player),"Clock cannot award twice: "+identity)
		await create_timer(player.animation_player.get_animation("timekeeper_use").length+.2).timeout
		var restored = OriginalTimeKeeper.new()
		restored.level_id = identity
		restored.asset_directory = clock.asset_directory
		restored.sound_bank_path = clock.sound_bank_path
		level.add_child(restored)
		await frames(2)
		check(restored.state == restored.State.COLLECTED,"Re-entering a completed level leaves its clock inactive")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	OriginalProgress.restore({})
	print("Native clock approach / E interaction / reusable configuration / reward isolation: ",failures," failures")
	quit(1 if failures else 0)
