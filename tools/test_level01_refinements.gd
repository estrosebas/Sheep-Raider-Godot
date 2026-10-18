extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool, message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func run_tests():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var lessons = level.get_node("DaffyLessons")
	lessons.movies[0].played = true
	var player: RalphController = level.player
	await frames(60)
	var movie = lessons.movies[4]
	check(movie.start_sequence(true),"Voiced cinematic starts")
	await frames(4)
	var before = movie.elapsed
	movie._process(4)
	check(movie.elapsed-before < .15,"A stalled render frame cannot advance Lucas four seconds ahead of the voice")
	movie.voice_player.seek(10)
	await create_timer(.15).timeout
	check(absf(movie.elapsed-movie.voice_player.get_playback_position()) < .2,"Cinematic follows actual voice playback")
	movie.sample(55.256)
	var duck = movie.actors["2:63"]
	var tiptoe_length: float = duck.animation_player.get_animation("tiptoe").length
	check(duck.animation_player.current_animation == "tiptoe" and absf(duck.animation_player.current_animation_position-fmod(1.0,tiptoe_length)) < .01,"Original Lucas TIPTOE repeats across its complete cinematic interval")
	movie.finish_sequence(true)
	player.set_physics_process(false)
	var sam: OriginalSam = level.get_node("Sam_43")
	sam.set_physics_process(false)
	sam.reset_guard()
	sam.initialized = true
	player.global_position = sam.home+Vector3(0,0,5)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.SNEAK)
	sam.rotation.y = .4
	sam.head_phase = PI/2
	sam._physics_process(0)
	check(absf(sam.relative_angle-(.4-deg_to_rad(45))) < .01,"Native relative head angle accounts for reflected axes and current sweep")
	player.global_position = sam.home+Vector3(0,0,-5)
	player.set_state(player.WolfState.WALK)
	player.velocity = Vector3.ZERO
	sam.head_phase = 0
	sam.rotation.y = 0
	sam._physics_process(0)
	check(sam.state == sam.State.GUARD and sam.alert_level == 1,"Stationary hidden Ralph does not create a false red alert from stale WALK state")
	# Bring an awake sheep onto the broad spawn floor; retain actual carry input/physics.
	player.global_position = Vector3(8.91,.11,12.73)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.IDLE)
	player.skeleton.rotation.y = 0
	player.camera_pivot.rotation.y = 0
	player.set_physics_process(true)
	var sheep: OriginalSheep = level.get_node("Sheep_52")
	level.get_node("Flock").set_physics_process(false)
	sheep.global_position = player.global_position+Vector3(0,0,1)
	sheep.velocity = Vector3.ZERO
	await frames(45)
	check(sheep.interact(player),"Real TAKE2A/B pickup starts")
	await frames(110)
	check(player.carried_sheep == sheep and player.animation_player.current_animation == "sheep_carry_idle" and sheep.visual.idle_clip == "stand8","Carrying selects Ralph STAND8 and sheep STAND8 instead of one-arm STAND2")
	var overhead = sheep.global_position-player.global_position
	print("Sheep attachment relative to Ralph: ",overhead)
	var root_pose = player.skeleton.global_transform*player.legacy_skin.last_matrices[0]
	var hand_pose = player.skeleton.global_transform*player.legacy_skin.last_matrices[18]
	var expected = hand_pose.origin+root_pose.basis*GameSpace.EXPORT_TO_GODOT*Vector3(0,-.07,0)+Vector3.UP*sheep.carry_visual_lift
	check(sheep.global_position.distance_to(expected) < .025 and absf(overhead.x) < .7,"Carry attachment preserves joint18 and native offset plus measured head clearance")
	var saw_tired = false
	for i in range(430):
		await physics_frame
		saw_tired = saw_tired or player.animation_player.current_animation == "sheep_carry_tired"
	check(saw_tired,"Original STAND12 fatigue appears after STAND8 idle loops")
	Input.action_press("move_forward")
	Input.action_press("sneak")
	await frames(70)
	check(player.sneak_step_count > 0 and player.sneak_audio_player.pitch_scale < 1,"Actual carried sheep movement invokes original low-pitch sneak steps")
	check(player.current_state == player.WolfState.SNEAK and player.animation_player.current_animation == "sheep_carry_sneak" and sheep.visual.idle_clip == "run2","Ctrl uses original SNEAK2 and sheep RUN2")
	check(Vector2(player.velocity.x,player.velocity.z).length() <= 2.05,"Carry sneak uses original 200 units/s")
	Input.action_release("move_forward")
	Input.action_release("sneak")
	await frames(25)
	var takeoff = player.global_position.y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var apex = takeoff
	var jump_clips = {}
	for i in range(75):
		if i == 10: Input.action_press("jump")
		if i == 12: Input.action_release("jump")
		await physics_frame
		apex = maxf(apex,player.global_position.y)
		jump_clips[player.animation_player.current_animation] = true
	check(apex-takeoff > .9 and apex-takeoff < 1.5,"Carry jump uses original 130-unit arc and second Space cannot double jump")
	check(jump_clips.has("sheep_carry_jump") and jump_clips.has("sheep_carry_apex") and jump_clips.has("sheep_carry_land_idle"),"Carry jump, apex and landing use original mode-1 animations")
	check(player.is_on_floor() and player.carried_sheep == sheep,"Single carry jump lands without raycast death or losing sheep")
	var safe_drop = false
	for i in range(16):
		player.skeleton.rotation.y = i*TAU/16
		if not OriginalPlacement.probe(player,sheep,false).is_empty():
			safe_drop = true
			break
	check(safe_drop,"Carry jump fixture has an unobstructed putdown direction")
	check(sheep.interact(player),"Original PUT2A/B remains available after carry jump")
	await frames(60)
	check(player.carried_sheep == null and not player.cinematic_controls_locked,"Drop returns normal movement without locking Ralph")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await frames(2)
	print("Level01 synchronization / portrait / original sheep carry: ",failures," failures")
	quit(1 if failures else 0)
