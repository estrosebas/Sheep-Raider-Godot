extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.4).timeout
	var cinematics = level.get_node("LevelCinematics")
	if cinematics.active_movie: cinematics.active_movie.finish_sequence(true)
	cinematics.set_process(false)
	var lessons = level.get_node("DaffyLessons"); lessons.set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	player.restart_fade_remaining = 0; player.cinematic_controls_locked = false; player.tutorial_movement_locked = false
	player.global_position = TutorialProgress.center(lessons.data.trigger[0]); player.set_state(player.WolfState.IDLE)
	lessons._process(.3)
	check(lessons.active_movie==lessons.movies[0] and player.cinematic_controls_locked,"Native tutorial trigger starts Lucas rock explanation CIN00")
	check(lessons.movies[0].voice_player.stream.resource_path.ends_with("cin_lvl_0301.wav") and lessons.movies[0].dialogue.pages.size()>0,"Native rock speech starts with original subtitles and voice")
	lessons.movies[0].finish_sequence(true)
	await process_frame
	check(lessons.introduction_seen and lessons.asking_to_practice and lessons.menu.visible,"Original practice question appears after demonstration")
	var event = InputEventKey.new(); event.physical_keycode = KEY_ENTER; event.pressed = true
	lessons._input(event); await process_frame
	check(lessons.active_movie==lessons.movies[3],"Accepting practice starts native CIN03 rules")
	lessons.movies[3].finish_sequence(true); await process_frame
	check(lessons.intro_finished and lessons.current_phase==8 and lessons.voice.stream.resource_path.ends_with("cin_lvl_0311.wav"),"Rules are followed by native rock-cover reminder")
	lessons._voice_finished()
	player.global_position = TutorialProgress.center(lessons.data.start[0]); player.velocity = Vector3.ZERO
	lessons._process(.016)
	check(lessons.game_running and lessons.indicator.visible,"Authored white line starts the original lookout exercise")
	lessons.game_running = false
	lessons._say_phase(3,16)
	check(lessons.voice.stream.resource_path.ends_with("cin_lvl_0303.wav") and lessons.dialogue.pages.size()>0,"Noise feedback uses level03 voice rather than bush-level voice")
	lessons._voice_finished()
	lessons._say_phase(6,19)
	check(lessons.voice.stream.resource_path.ends_with("cin_lvl_0304.wav"),"Seen feedback uses native level03 catch voice")
	lessons._voice_finished()
	player.global_position = lessons.daffy.global_position+lessons.head_forward()*2
	player.set_state(player.WolfState.SNEAK); player.velocity = Vector3.ZERO
	# Actual physical cover: no unbounded distance-only hiding state.
	var blocker = StaticBody3D.new(); level.add_child(blocker)
	var shape = CollisionShape3D.new(); shape.shape = BoxShape3D.new(); shape.shape.size = Vector3(1,2,1)
	blocker.add_child(shape); blocker.position = lessons.daffy.global_position+lessons.head_forward()+Vector3.UP*.5
	await physics_frame
	var ray = PhysicsRayQueryParameters3D.create(lessons.daffy.global_position+Vector3.UP*.7,player.global_position+Vector3.UP*.7,1)
	ray.exclude = [player.get_rid()]
	check(not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Imported cover test has a real occluding solid")
	# Evaluate the same clear/occluded head beam without borrowing bush logic.
	var original_activation = lessons.data.activation
	lessons.data.activation = [{"min":[-100000,-100000,-100000],"max":[100000,100000,100000]}]
	check(lessons.detect_player()==0,"Sneaking behind solid cover prevents Lucas sight detection")
	blocker.queue_free(); await physics_frame; await physics_frame
	check(lessons.detect_player()==6,"Visible player inside the real head beam is detected in rock tutorial")
	lessons.data.activation = original_activation
	# Feedback and tutorial progress must survive shared checkpoint capture.
	lessons.introduction_seen = true; lessons.intro_finished = true; lessons.challenge_won = true
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(save.snapshot.lessons.daffy_state.challenge_won and save.snapshot.lessons.cinematics.intro_finished,"Checkpoint captures both tutorial and entry cinematic state")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level03 native Lucas trigger / rock demo / practice / lines / voice feedback / checkpoint state: ",failures," failures")
	quit(failures)
