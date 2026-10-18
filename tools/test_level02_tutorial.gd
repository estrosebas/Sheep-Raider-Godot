extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr(message)
func center(box: Dictionary) -> Vector3:
	var a = box.min; var b = box.max
	return GameSpace.original_point(Vector3((a[0]+b[0])/2.0,0,(a[2]+b[2])/2.0))
func key(code: Key):
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	return event
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level02.tscn").instantiate()
	root.add_child(level); current_scene = level
	await create_timer(.5).timeout
	var player = level.player
	player.set_physics_process(false); player.set_process(false)
	var lessons = level.get_node("DaffyLessons")
	lessons.set_process(false)
	check(not lessons.introduction_seen and not lessons.active_movie,"Tutorial waits for its native trigger")
	check(lessons.daffy.rig.animations.has("appear1") and lessons.daffy.rig.animations.has("stand1a"),"Lucas has recovered complete native animations")
	check(not level.get_node("MiscStatic_90").visible,"Cinematic demonstration bush stays out of gameplay")
	player.global_position = center(lessons.data.trigger[0])
	lessons._process(.3)
	check(lessons.active_movie == lessons.movies[1] and player.cinematic_controls_locked,"Crossing original ACTBOX starts CIN01 and freezes Ralph")
	var movie = lessons.active_movie
	movie.set_process(false)
	movie.sample(15)
	if "--capture" in OS.get_cmdline_user_args():
		movie.voice_player.seek(15)
		movie.dialogue.elapsed = 15
		movie.dialogue._process(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://level02_tutorial_intro.png")
	check(movie.camera.current and movie.voice_player.playing and movie.dialogue.visible,"Native camera, voice and subtitle framing run together")
	var final_player = movie.actors["2:50"]
	movie.sample(float(movie.data.duration))
	var destination = final_player.global_position
	movie.finish_sequence(true)
	await process_frame
	check(player.global_position.distance_to(destination)<.001,"CIN completion restores level02 Ralph resource50 position")
	check(lessons.menu.visible and lessons.asking_to_practice and player.cinematic_controls_locked,"Intro ends in the original practice question")
	var rows = lessons.menu_frame.render_lines()
	var animated = rows.filter(func(row): return row.animated)
	check(animated.size()==1 and animated[0].text==GameLocalization.ui("Sí") and not lessons.menu_label.text.contains(">"),"Only selected Yes animates; question/footer are static and there is no atlas arrow glyph")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://level02_practice_menu.png")
	lessons._input(key(KEY_DOWN))
	animated = lessons.menu_frame.render_lines().filter(func(row): return row.animated)
	check(animated.size()==1 and animated[0].text==GameLocalization.ui("No"),"Changing selection transfers animation to No")
	lessons._input(key(KEY_E))
	check(not lessons.menu.visible and not player.cinematic_controls_locked and not lessons.intro_finished,"No releases controls and leaves training available")
	player.global_position = lessons.daffy.global_position+Vector3(0,0,1)
	player.set_state(player.WolfState.IDLE)
	check(lessons.interact(player),"Lucas offers practice again after declining")
	lessons._input(key(KEY_E))
	await process_frame
	check(lessons.active_movie == lessons.movies[2],"Yes starts native rules CIN02")
	lessons.movies[2].set_process(false); lessons.movies[2].finish_sequence(true)
	check(lessons.intro_finished and lessons.game_armed and not player.cinematic_controls_locked,"Rules arm the original challenge")
	# Verify localized CIN data, not only free dialogue.
	for locale in ["en","pt_BR","it","es"]:
		GameLocalization.select(locale,false)
		var localized = GameLocalization.load_data(lessons.movies[1].sequence_path)
		check(localized.voice_path.contains("/"+locale+"/") and localized.text == GameLocalization.text("lvl_02",48,0),"CIN01 text and voice match locale "+locale)
	var start = lessons.data.start[0]
	player.global_position = center(start)
	player.global_position.x = float(start.max[0])*.01+1
	var phase_before = lessons.head_phase
	lessons._process(.1)
	check(not lessons.game_running and lessons.game_armed and lessons.head_phase>phase_before and lessons.indicator.visible,"Approaching the line previews the sweep without starting detection")
	player.global_position = center(start); lessons._process(.1)
	check(lessons.game_running,"Original start line arms detection")
	phase_before = lessons.head_phase
	var pose_before = lessons.daffy.skeleton.get_bone_pose_rotation(4)
	lessons._process(.2)
	check(lessons.head_phase>phase_before and not lessons.daffy.skeleton.get_bone_pose_rotation(4).is_equal_approx(pose_before) and not lessons.speaking,"Head bone and cone continue sweeping while Ralph waits on the safe start line")
	player.global_position.x = float(start.min[0])*.01-.1
	player.velocity = Vector3.ZERO
	phase_before = lessons.head_phase
	lessons._process(.1)
	check(lessons.game_running and lessons.head_phase>phase_before,"Leaving the line preserves a continuously moving sweep instead of a fixed gaze")
	player.global_position = lessons.daffy.global_position+Vector3(0,0,5)
	player.velocity = Vector3.RIGHT; player.set_state(player.WolfState.WALK)
	check(lessons.detect_player() == 3,"Ordinary walking is heard")
	lessons._process(.1)
	check(lessons.speaking and lessons.current_phase == 3 and lessons.voice.stream.resource_path.ends_with("cin_lvl_0203.wav"),"Noise selects the native feedback and correct voice")
	lessons._voice_finished()
	check(lessons.game_armed and not lessons.game_running,"Caught feedback requires returning to start line")
	var bush = get_nodes_in_group("bushes")[0]
	bush.wear(player); bush.rise_time = 10
	player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE)
	lessons.head_yaw = 0
	player.global_position = lessons.daffy.global_position+Vector3(0,0,5)
	check(lessons.detect_player() == 0,"Stationary disguised Ralph remains hidden inside the viewing beam")
	player.active_bush = null
	player.velocity = Vector3(0,-.2,0); player.set_state(player.WolfState.IDLE)
	for phase in [.2,.7,1.1]:
		lessons.head_phase = phase; lessons._watch_head(0)
		var forward = lessons.head_forward()
		player.global_position = lessons.daffy.global_position+forward*5
		check(lessons.detect_player()==6,"Bare Ralph on rendered head axis is seen at sweep phase "+str(phase))
		var outside = Basis(Vector3.UP,deg_to_rad(15))*forward
		player.global_position = lessons.daffy.global_position+outside*5
		check(lessons.detect_player()==0,"Residual vertical velocity cannot detect stationary Ralph outside rendered head cone")
		player.current_state = player.WolfState.SNEAK; player.velocity = outside
		check(lessons.detect_player()==0,"Sneaking outside the visible head cone stays undetected")
		check(absf(lessons.relative_view_angle())>56*TAU/4096,"HUD and detection share rendered cone angle")
		player.current_state = player.WolfState.IDLE; player.velocity = Vector3(0,-.2,0)
	player.active_bush = bush
	lessons.game_running = true
	lessons._watch_head(.1)
	if "--capture" in OS.get_cmdline_user_args():
		player.camera.current = true
		lessons.indicator.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://level02_tutorial_guard.png")
	lessons.head_yaw = 0
	lessons.head_phase = 0; lessons._watch_head(0)
	player.global_position = lessons.daffy.global_position+lessons.head_forward()*5
	player.velocity = Vector3.RIGHT; player.set_state(player.WolfState.SNEAK)
	check(lessons.detect_player() == 4,"Sneaking while the head looks at Ralph selects movement feedback")
	lessons._say_phase(4,17)
	check(player.active_bush == bush and bush.wearer == player,"Feedback freezes without destroying the worn disguise")
	GameLocalization.select("en",false); lessons.reload_localization()
	check(lessons.voice.stream.resource_path.contains("/en/") and lessons.dialogue != null,"Feedback changes language and voice in place")
	lessons._voice_finished()
	GameLocalization.select("es",false); lessons.reload_localization()
	player.global_position = center(lessons.data.start[0]); lessons._process(.1)
	player.global_position = center(lessons.data.goal[0]); lessons._process(.1)
	check(lessons.current_phase == 7 and lessons.daffy.idle_clip == "ok1","Crossing the goal selects native OK1 success animation")
	lessons._voice_finished()
	check(lessons.challenge_won,"Finishing success dialogue completes training")
	var save = level.get_node("CheckpointSave")
	save.capture_checkpoint(); var snapshot = save.snapshot.duplicate(true)
	check(snapshot.lessons.daffy_state.challenge_won,"Checkpoint captures tutorial progression")
	lessons.restore_progress({})
	check(not lessons.introduction_seen,"Restart resets tutorial")
	check(save.restore_checkpoint(snapshot) and lessons.challenge_won and lessons.intro_finished,"Checkpoint restores completed tutorial")
	player.set_physics_process(false)
	player.global_position = lessons.daffy.global_position+Vector3(0,0,1)
	player.set_state(player.WolfState.IDLE)
	check(lessons.interact(player) and lessons.menu.visible and not lessons.asking_to_practice,"Completed training opens original three-topic dialogue menu")
	lessons.selected = 0; lessons._input(key(KEY_E))
	check(lessons.voice.stream.resource_path.ends_with("cin_lvl_0212.wav"),"Bush question plays native answer0212")
	lessons._voice_finished()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level02 native tutorial failures: ",failures)
	quit(failures)
