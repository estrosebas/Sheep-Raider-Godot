extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func clean(scene: Node) -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
func run_tests() -> void:
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: RalphController = level.player
	var lessons: OriginalLevel01Daffy = level.get_node("DaffyLessons")
	await frames(30)
	check(lessons.active_movie == lessons.movies[0] and player.cinematic_controls_locked,"Original CIN00 triggers at recovered ACTBOX580 and interrupts Ralph")
	check(level.get_node("BGMPlayer").playing and level.get_node("BGMPlayer").stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Original level01 Trip_v1 plays and loops during cinematic")
	lessons.movies[0].finish_sequence(false)
	await frames(2)
	check(lessons.active_movie == lessons.movies[4] and lessons.movies[4].voice_player.stream.resource_path.ends_with("cin_lvl_0101.wav"),"CIN00 chains original CIN04 / Spanish voice9")
	for time in [0.0,10.0,30.0,60.0]: lessons.movies[4].sample(time)
	check(not lessons.movies[4].dialogue.label.text.contains("$"),"Original dialogue removes layout/color tokens and substitutes controls")
	lessons.movies[4].finish_sequence(false)
	check(lessons.intro_finished and not player.cinematic_controls_locked and level.get_node("BGMPlayer").playing,"Original intro restores camera/control and preserves music")
	await frames(75) # Catalogued intro return opens a one-second iris before AI interaction tests.
	# Other extracted movies must resolve every actor/animation at all boundaries.
	for identity in [2,3]:
		var movie = lessons.movies[identity]
		for time in [0.0,float(movie.data["duration"])/2,float(movie.data["duration"])]: movie.sample(time)
		for actor in movie.actors.values(): actor.hide()
	player.set_physics_process(false)
	var sam: OriginalSam = level.get_node("Sam_43")
	await frames(100)
	sam.set_physics_process(false)
	check(sam.graph.get_point_count() > 20 and sam.is_on_floor(),"Sam uses recovered 58-route navigation graph and terrain")
	player.global_position = Vector3.ZERO
	sam.update_alert()
	check(sam.alert_level == -1,"Outside original green zones: portrait hidden")
	player.global_position = sam.home+Vector3(0,0,5)
	sam.state = sam.State.GUARD
	sam.update_alert()
	check(sam.alert_level == 1,"Original orange volume arms detection")
	player.set_state(player.WolfState.SNEAK)
	sam.relative_angle = PI
	check(not sam.can_detect_player(),"Sneaking behind Sam is silent")
	sam.relative_angle = 0
	check(sam.can_detect_player(),"Sneaking in front of Sam remains visible")
	sam.relative_angle = PI
	player.set_state(player.WolfState.WALK)
	player.velocity = Vector3(1,0,0)
	check(sam.can_detect_player(),"Walking is noisy even behind Sam")
	player.item_costume = "sheep"
	check(not sam.can_detect_player(),"Original sheep disguise suppresses wolf detection")
	player.item_costume = ""
	player.set_state(player.WolfState.SNEAK)
	sam.reset_guard()
	player.global_position = sam.home+Vector3(0,0,5)
	sam.initialized = true
	sam.head_phase = 0
	player.set_state(player.WolfState.WALK)
	sam.set_physics_process(true)
	await frames(15)
	check(sam.state == sam.State.CHASE and sam.alert_level == 2 and sam.global_position.distance_to(sam.home) > .5,"Sam enters red chase and moves physically at original speed")
	player.global_position = Vector3(8.91,.11,12.73)
	await frames(240)
	check(sam.state == sam.State.GUARD and sam.global_position.distance_to(sam.home) < .7,"Leaving original hit zone makes Sam return to guard post")
	sam.on_blast(sam.global_position)
	await frames(2)
	check(sam.burnt and sam.state != sam.State.STUNNED,"Original dynamite KILL_GENERIC blackens Sam; only crushing causes KO")
	player.global_position = sam.home+Vector3(0,0,5)
	player.set_state(player.WolfState.SNEAK)
	sam.on_loud_noise(sam.home,30,2)
	await frames(2)
	check(sam.forced_alert and sam.state == sam.State.CHASE,"Original authorized dynamite noise forces red alert even while sneaking")
	sam.reset_guard()
	# Shared flock reserves one sheep per lure; actual approach and eating.
	sam.set_physics_process(false)
	var flock: OriginalFlock = level.get_node("Flock")
	var sheep: OriginalSheep = level.get_node("Sheep_44")
	var lettuce = level.get_node("Salad_71")
	check(sheep.sleepy and sheep.sleeping_visual != null and sheep.sleeping_visual.idle_clip == "sleep1","Original sleepy property selects separate AMOUTO03/SLEEP1 model")
	lettuce.global_position = sheep.home+Vector3(0,0,2)
	lettuce.available = true
	lettuce.respawn_time = 0
	flock._physics_process(.016)
	check(flock.reservations.has(lettuce),"Flock selects nearest available sheep for lettuce")
	var chosen: OriginalSheep = flock.reservations.get(lettuce)
	check(chosen != null and not chosen.sleepy,"Sleeping sheep do not reserve the lettuce")
	if chosen:
		var start = chosen.global_position
		await frames(240)
		print("Lure approach: ",chosen.name," pos=",chosen.global_position," target=",lettuce.global_position," phase=",chosen.flock_phase)
		check(chosen.global_position.distance_to(start) > .5,"Sheep smells then physically approaches lettuce using original SMEL1/WALK1")
		await frames(240)
		print("Lure finish: ",chosen.global_position," phase=",chosen.flock_phase," eating=",lettuce.eat_time," available=",lettuce.available)
		check(not lettuce.available or lettuce.eat_time > 0,"Selected sheep eats the lure")
	# Grab/windup/death/fade must release controls and reset Sam on respawn.
	player.set_physics_process(true)
	player.global_position = sam.global_position+Vector3(0,0,.7)
	player.velocity = Vector3.ZERO
	sam._catch_player()
	sam.set_physics_process(true)
	await frames(240)
	check(player.current_state == player.WolfState.SAM_DEATH,"Original Sam PUNCH7 ends in Ralph DIEPNCH2")
	await frames(360)
	check(not player.cinematic_controls_locked and player.current_state != player.WolfState.SAM_DEATH and sam.state == sam.State.GUARD,"Capture fades, respawns and resets guard without a stuck lock")
	# Actual E selection and close must not reopen the conversation.
	player.set_physics_process(false)
	player.global_position = lessons.daffy.global_position+Vector3(0,0,1)
	player.restart_fade_remaining = 0
	check(lessons.interact(player),"Lucas remains available for original three-topic menu after intro")
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	check(lessons.speaking and lessons.voice.playing,"E chooses original Sam explanation voice10")
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	check(not lessons.speaking and not player.cinematic_controls_locked,"E closes dialogue and returns control")
	clean(level)
	await create_timer(.2).timeout
	level.queue_free()
	await frames(3)
	print("Level01 original music / Sam / flock / Lucas: ",failures," failures")
	quit(1 if failures else 0)
