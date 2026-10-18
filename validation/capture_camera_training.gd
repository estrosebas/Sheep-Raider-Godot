extends SceneTree

func _init() -> void:
	call_deferred("capture")

func snapshot(name: String) -> void:
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/%s.png" % name)

func finish_move(training) -> void:
	for tick in range(160):
		if training.phase != training.Phase.MOVING:
			return
		training._process(0.1)

func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var director = level.get_node("TutorialIntro")
	var training = level.get_node("CameraTraining")
	var player = level.get_node("Player")
	director.set_process(false)
	training.set_process(false)
	training.set_physics_process(false)
	director.start_sequence(true)
	director.finish_sequence(false)
	director.sample(6.0)
	await snapshot("training_follow")
	director.finish_sequence(false)
	training._process(1.0)
	await snapshot("training_camera_dialogue")
	training._begin_move()
	finish_move(training)
	training._begin_move()
	for attempt in range(4):
		player.camera_pivot.look_at(training.actor.global_position+Vector3.UP*1.6-player.camera_pivot.global_basis.x*player.camera.h_offset)
	await physics_frame
	await physics_frame
	training._physics_process(0.5)
	await snapshot("training_camera_focus")
	training._physics_process(0.6)
	training._begin_move()
	finish_move(training)
	for attempt in range(4):
		player.camera_pivot.look_at(training.actor.global_position+Vector3.UP*1.6-player.camera_pivot.global_basis.x*player.camera.h_offset)
	await physics_frame
	await physics_frame
	training._physics_process(0.5)
	await snapshot("training_roof_focus")
	player.capture_mouse(false)
	level.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
