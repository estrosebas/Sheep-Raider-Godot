extends SceneTree
func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var duck = level.get_node("DaffyLessons")
	duck.movies[0].played = true
	duck.intro_finished = true
	var pig = level.get_node("PorkyLessons")
	pig.set_process(false)
	await create_timer(.4).timeout
	var player = level.player
	level.get_node("Sam_43").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	player.global_position = Vector3(15.62,.07,-56.73)
	var sheep = level.get_node("Sheep_52")
	sheep.global_position = player.global_position+Vector3(0,0,1)
	pig.try_lesson()
	duck.movies[3].finish_sequence(false)
	var salad = pig.salads[0]
	player.global_position = player.respawn_ground_position(salad.global_position+Vector3(.6,0,0))
	player.velocity = Vector3.ZERO
	await create_timer(.5).timeout
	player.set_physics_process(false)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.fov = 55
	camera.global_position = Vector3(18,3,-51)
	camera.look_at(Vector3(15.4,.35,-56))
	camera.current = true
	player.camera_pivot.set_process(false)
	await create_timer(.6).timeout
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/porky_field_action_prompt.png")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit()
