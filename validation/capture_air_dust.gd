extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var world = Node3D.new()
	root.add_child(world)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12,0.2,0.12)
	world.add_child(environment)
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.capture_mouse(false)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.position = Vector3(4,3,-8)
	camera.look_at(Vector3(0,0.8,-3.2))
	camera.current = true
	player.set_state(player.WolfState.RUN)
	player.skeleton.rotation.y = PI
	for i in range(32):
		player.position.z -= 0.2
		player.animation_player.advance(1.0/60)
		player.run_dust.update_dust(1.0/60,true,player.global_position,Vector3.FORWARD,12,12)
	player.apply_legacy_reaction_pose()
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/original_run_dust.png")
	player.position = Vector3.ZERO
	camera.look_at(Vector3(0,0.8,0))
	player.set_state(player.WolfState.PIT_FALL)
	camera.current = true
	player.run_dust.clear()
	player.animation_player.seek(2.5,true)
	player.apply_legacy_reaction_pose()
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/original_pit_fall.png")
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
