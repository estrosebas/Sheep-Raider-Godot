extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var director = level.get_node("TutorialIntro")
	level.get_node("CameraTraining").enabled = false
	director.set_process(false)
	director.start_sequence(true)
	var samples = {"intro_anvil":1.2,"intro_squashed":3.2,"intro_curtain":10.0,"intro_daffy":17.4}
	for name in samples:
		director.sample(samples[name])
		for frame in range(8):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/%s.png" % name)
	director.finish_sequence(false)
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
