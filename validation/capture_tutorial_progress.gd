extends SceneTree

func _init() -> void:
	call_deferred("capture")

func snapshot(name: String) -> void:
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/%s.png" % name)

func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	var progress = level.get_node("TutorialProgress")
	var director = level.get_node("TutorialIntro")
	var training = level.get_node("CameraTraining")
	player.set_physics_process(false)
	player.capture_mouse(false)
	progress.set_physics_process(false)
	director.set_process(false)
	training.enabled = false
	level.get_node("HUD").hide()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.position = Vector3(23.56,9,43.28)
	camera.look_at(Vector3(15.07,8,43.28))
	camera.current = true
	await snapshot("checkpoint_rock_before")
	progress.activate_checkpoint(2)
	for tick in range(5):
		progress._physics_process(0.04)
	await snapshot("checkpoint_rock_after")
	director.switch_sequence("res://assets/cinematics/tutorial_intro/platform_sequence.json")
	director.start_sequence(true)
	director.sample(16.0)
	await snapshot("tutorial_seesaw_cinematic")
	director.finish_sequence(false)
	training.actor.global_position = Vector3(-48.59,0,46.51)
	training.actor.show()
	player.global_position = Vector3(-49.61,0,45.47)
	training._show_dialogue(4)
	training.actor.sample_animation("talk1",0.5,true)
	player.camera.current = true
	await snapshot("tutorial_jump_instruction")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(0.3).timeout
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
