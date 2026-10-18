extends SceneTree
func _init():
	call_deferred("capture")
func capture():
	root.size = Vector2i(640, 640)
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.capture_mouse(false)
	player.get_node("CameraPivot/Camera3D").current = false
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(2.5, 1.4, -3.3)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.current = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.15, 0.18, 0.22)
	root.add_child(environment)
	for name in ["run_crash", "run_recover", "idle"]:
		player.play_anim(name)
		player.animation_player.advance(0.3)
		player.apply_legacy_reaction_pose()
		for frame in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/pose_" + name + ".png")
	player.queue_free()
	await create_timer(0.1).timeout
	quit()
