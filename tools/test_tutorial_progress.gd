extends SceneTree

const ProgressRules = preload("res://scripts/levels/tutorial_progress.gd")
var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func finish_move(training) -> void:
	for tick in range(500):
		if training.phase != training.Phase.MOVING:
			return
		training._process(0.05)
	check(false,"Original NPC movement must finish")

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var training = level.get_node("CameraTraining")
	var progress = level.get_node("TutorialProgress")
	var player = level.get_node("Player")
	var music = level.get_node("BGMPlayer")
	var director = level.get_node("TutorialIntro")
	training.set_process(false)
	training.set_physics_process(false)
	progress.set_physics_process(false)
	player.capture_mouse(false)
	player.set_physics_process(false)
	check(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.stream.loop_end > 0,"Level music is explicitly looped")
	director.set_process(false)
	director.start_sequence(true)
	director.finish_sequence(false)
	director.finish_sequence(false)
	check(music.playing,"Music survives both cinematic transitions")
	check(progress.rocks.size() == 3 and progress.data["checkpoints"].size() == 6,"All original rock/checkpoint records recovered")
	for rock in progress.rocks.values():
		check(not rock["body"].visible and not rock["active"],"Falling rocks begin hidden")
		for shape in rock["body"].get_children():
			if shape is CollisionShape3D:
				check(shape.disabled,"Hidden rock cannot block the path")
	var rock = progress.rocks[58]
	progress.activate_checkpoint(2)
	await physics_frame
	check(rock["active"] and rock["body"].visible and player.checkpoint_position != null,"Only original checkpoint 634 reveals its rock")
	check(not progress.rocks[59]["active"] and not progress.rocks[60]["active"],"Other rocks remain absent before their checkpoints")
	for step in range(6):
		progress._physics_process(0.04)
	check(rock["ticks"] == 5 and rock["body"].position == rock["home"],"Rock drops in five original 400u steps and lands")
	progress.activate_checkpoint(2)
	check(rock["ticks"] == 5,"Passing same checkpoint cannot drop another rock")
	var saved = player.checkpoint_position
	player.global_position = Vector3(200,-50,200)
	player.respawn_at_checkpoint()
	check(player.global_position == saved,"Respawn uses saved checkpoint destination")
	# Resume from completed camera block into real jump and double-jump stages.
	training.step_index = 3
	training._move_finished()
	check(training.phase == training.Phase.WAIT_STAGE and training.step_index == 4 and not player.tutorial_movement_locked,"Camera block now continues into jump tutorial")
	player.global_position = ProgressRules.center(training.data["slots"][4]["box"])
	training._physics_process(0.016)
	check(training.phase == training.Phase.DIALOGUE and training.voice.stream.resource_path.ends_with("txt_lvl_006.wav") and "\n".join(training.dialogue_pages).contains("Espacio"),"Entering original jump box plays correct voice and PC control")
	training._begin_move()
	finish_move(training)
	# Slot 5 is an empty automatic path; it leads directly to double-jump slot 6.
	finish_move(training)
	check(training.step_index == 6 and training.phase == training.Phase.WAIT_STAGE,"NPC original walk/jump paths lead to double-jump checkpoint")
	player.global_position = ProgressRules.center(training.data["slots"][6]["box"])
	training._physics_process(0.016)
	check(training.voice.stream.resource_path.ends_with("txt_lvl_007.wav"),"Double-jump explanation uses original voice 93")
	check(training.phase == training.Phase.DIALOGUE and not director.playing,"Double-jump lesson does not play the later seesaw cinematic")
	# Exercise the original race timing: crossing start, success, failure/retry.
	training._enter_stage(11)
	player.global_position = ProgressRules.center(training.data["slots"][11]["box"])
	training._physics_process(0.016)
	check(training.voice.stream.resource_path.ends_with("txt_lvl_0010.wav") and training.dialogue_pages.size() > 1,"Race voice appears only at race lesson; long instructions are paged")
	training.phase = training.Phase.WAIT_STAGE
	player.tutorial_movement_locked = false
	player.global_position = ProgressRules.center(training.data["race"]["start"])
	training._physics_process(0.016)
	player.global_position += Vector3.RIGHT*20
	training._physics_process(0.016)
	check(training.race_active and training.race_time == 50,"Leaving original start box starts 50-second race")
	training._process(50.1)
	check(not training.race_active and training.retrying_race and training.voice.stream.resource_path.ends_with("txt_lvl_0011.wav"),"Race failure restores checkpoint and plays retry voice")
	training._begin_move()
	check(not training.retrying_race and training.voice.stream.resource_path.ends_with("txt_lvl_0010.wav"),"Retry returns to race briefing")
	training.race_active = true
	training.phase = training.Phase.WAIT_STAGE
	player.global_position = ProgressRules.center(training.data["race"]["finish"])
	training._physics_process(0.016)
	check(training.race_finished and training.step_index == 13 and training.voice.stream.resource_path.ends_with("txt_lvl_0012.wav"),"Original finish box ends race and plays success explanation")
	training._enter_stage(14)
	player.global_position = ProgressRules.center(training.data["slots"][14]["box"])
	training._physics_process(0.016)
	check(training.phase == training.Phase.DEMO and director.playing and int(director.data["cine_id"]) == 3,"Seesaw stage uses original ACTBOX 651/CIN 3")
	var before_demo = player.global_position
	director.finish_sequence(true)
	await physics_frame
	check(player.global_position == before_demo and training.phase == training.Phase.DIALOGUE,"Seesaw demo preserves Ralph position and returns to explanation")
	check(director.persistent_platforms.size() == 22,"All original construction pieces remain after cinematic")
	for key in director.persistent_platforms:
		if director.persistent_platforms[key]:
			check(director.actors[key].visible and director.actors[key].static_shape == null,"Original decorative fragments remain visible without invented colliders")
	var wheel = player.inventory.wheel
	wheel.cloud_elapsed = 0
	wheel._process(0.19)
	check(int(wheel.cloud_elapsed/wheel.cloud_frame_seconds) == 0,"Cloud animation holds first frame for 0.2 seconds")
	wheel._process(0.02)
	check(int(wheel.cloud_elapsed/wheel.cloud_frame_seconds) == 1,"Cloud animation is time-based at five frames per second")
	await physics_frame
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(0.3).timeout
	level.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Tutorial progression: ",failures," failures")
	quit(1 if failures else 0)
