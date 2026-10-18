extends SceneTree

var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func finish_move(training) -> void:
	for tick in range(160):
		if training.phase != training.Phase.MOVING:
			return
		training._process(0.1)
	check(false,"Original HIDE2 movement must finish")

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var director = level.get_node("TutorialIntro")
	var training = level.get_node("CameraTraining")
	training.continue_after_camera = false
	var player = level.get_node("Player")
	check(training.data["voices"]["81"]["name"] == "txt_lvl_0010.wav","Race voice remains reserved for original voice ID 81")
	check(training.data["tutorial_voice_catalog"][11]["voice_id"] == 81 and training.data["tutorial_voice_catalog"][11]["text_id"] == 9,"Original later race lesson selects race voice")
	check(training.data["voices"]["91"]["name"] == "txt_lvl_005.wav","Archived internal-view line resolves its correct file")
	player.capture_mouse(false)
	director.set_process(false)
	training.set_process(false)
	training.set_physics_process(false)
	check(director.start_sequence(true),"Start original intro")
	director.finish_sequence(false)
	check(training.phase == training.Phase.FOLLOW and int(director.data["cine_id"]) == 5 and director.playing,"CIN 1 chains into original spoken CIN 5")
	check(director.voice_player.playing and director.voice_player.stream.resource_path.ends_with("txt_lvl_001.wav"),"Voice 80 uses original one-based bank: post-curtain line, not race voice 81")
	director.finish_sequence(false)
	check(training.phase == training.Phase.DIALOGUE and training.step_index == 0,"Original first camera lesson begins after follow sequence")
	check(player.tutorial_movement_locked and not player.cinematic_controls_locked and not player.can_use_inventory(),"Only movement/inventory lock; camera remains controllable")
	check(training.voice_pending and not training.voice.playing and "\n".join(training.dialogue_pages).contains("cámara"),"Original camera introduction text loads and voice waits for opening bars")
	training.letterbox._process(1.5)
	training._process(.016)
	check(training.voice.playing,"Original camera voice starts when letterbox is open")
	check(training.voice.stream.resource_path.ends_with("txt_lvl_002.wav"),"Camera introduction uses voice 88, not shifted voice 89")
	var yaw = player.camera_pivot.rotation.y
	player.capture_mouse(true)
	var event = InputEventMouseMotion.new()
	event.relative = Vector2(30,-10)
	player._unhandled_input(event)
	check(player.camera_pivot.rotation.y != yaw,"Third-person camera rotates during locked lesson")
	training._begin_move()
	finish_move(training)
	check(training.phase == training.Phase.DIALOGUE and training.step_index == 1,"Original path brings Lucas behind player for second instruction")
	check(training.voice.stream.resource_path.ends_with("txt_lvl_003.wav"),"Behind-you instruction uses voice 89")
	training._begin_move()
	check(training.phase == training.Phase.LOOK and training.pending_dialogue == 2,"Original warp enters look-at-Lucas condition")
	var actor = training.actor
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = actor.global_position+Vector3(0,1.1,3)
	camera.look_at(actor.global_position+Vector3.UP*1.1)
	camera.current = true
	await physics_frame
	training.probe.camera = camera
	check(not training.probe.evaluate(0.4) and training.probe.focus_seconds > 0,"Real camera ray hits Lucas and accumulates dwell")
	camera.look_at(actor.global_position+Vector3(5,1.1,0))
	check(not training.probe.evaluate(0.2) and training.probe.focus_seconds == 0,"Looking away resets continuous focus")
	camera.look_at(actor.global_position+Vector3.UP*1.1)
	var wall = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2,3,0.3)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	wall.global_position = actor.global_position+Vector3(0,1.1,1.5)
	await physics_frame
	check(not training.probe.evaluate(1.2) and training.probe.focus_seconds == 0,"A wall blocks gaze; Lucas cannot be detected through terrain")
	wall.queue_free()
	await physics_frame
	shape = null
	training._physics_process(0.6)
	training._physics_process(0.41)
	check(training.phase == training.Phase.DIALOGUE and training.step_index == 2,"One second of third-person focus advances original VIEW lesson")
	check(not training.voice.playing and not training.body.text.contains("interna"),"Adapted instruction never orders internal view")
	training._begin_move()
	finish_move(training)
	check(training.phase == training.Phase.LOOK and actor.global_position.y > 6,"Original HIDE2 route moves Lucas up onto the roof")
	player.camera.current = true
	for attempt in range(4):
		player.camera_pivot.look_at(actor.global_position+Vector3.UP*1.6-player.camera_pivot.global_basis.x*player.camera.h_offset)
	await physics_frame
	await physics_frame
	training.probe.camera = player.camera
	check(rad_to_deg(player.camera_pivot.rotation.x) < 65 and player.camera.global_position.y > 0.2,"Normal third-person camera can frame roof without clipping into floor")
	training._physics_process(1.01)
	check(training.phase == training.Phase.DIALOGUE and training.step_index == 3,"Camera ray finds elevated Lucas without first-person mode")
	check(training.voice.stream.resource_path.ends_with("txt_lvl_004.wav"),"Original praise voice 90 remains intact")
	training._begin_move()
	finish_move(training)
	check(training.phase == training.Phase.COMPLETE and not player.tutorial_movement_locked,"Final original return path ends camera lesson and restores movement")
	check(not training.crosshair.visible and player.can_use_inventory() and player.camera.h_offset == 0,"Gaze UI/camera offset restore and inventory is available again")
	player.capture_mouse(false)
	await physics_frame
	await physics_frame
	training.voice.stop()
	for sound in player.animation_sfx_players:
		sound.stop()
		sound.stream = null
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(0.3).timeout
	level.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Camera training: ",failures," failures")
	quit(1 if failures else 0)
