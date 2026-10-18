extends SceneTree
func _init() -> void: call_deferred("capture")
func save_image(path: String) -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var lessons = level.get_node("DaffyLessons")
	await create_timer(.4).timeout
	lessons.movies[0].finish_sequence(false)
	await process_frame
	await process_frame
	lessons.movies[4].set_process(false)
	lessons.movies[4].sample(21)
	await create_timer(1.6).timeout
	await save_image("res://validation/level01_lucas_original_intro.png")
	lessons.movies[4].finish_sequence(false)
	await create_timer(1.6).timeout
	var player = level.player
	player.set_physics_process(false)
	var sam = level.get_node("Sam_43")
	sam.set_physics_process(false)
	await create_timer(.2).timeout
	player.global_position = sam.home+Vector3(0,0,5)
	player.set_state(player.WolfState.SNEAK)
	sam.state = sam.State.GUARD
	sam.clip = "head2"
	sam.head_yaw = 0
	sam.relative_angle = 0
	sam.update_alert()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.position = sam.home+Vector3(5,3,9)
	camera.look_at(sam.home+Vector3.UP)
	camera.current = true
	await save_image("res://validation/level01_sam_orange_portrait.png")
	sam.relative_angle = PI/2
	await save_image("res://validation/level01_sam_turned_portrait.png")
	var sleepy = level.get_node("Sheep_44")
	camera.position = sleepy.global_position+Vector3(2,1.3,2)
	camera.look_at(sleepy.global_position+Vector3.UP*.4)
	await save_image("res://validation/level01_sleeping_sheep.png")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit()
