extends SceneTree
func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(1).timeout
	var sam: OriginalSam = level.get_node("Sam_43")
	level.player.set_physics_process(false)
	level.player.global_position = Vector3(8.91,.11,12.73)
	sam.reset_guard()
	sam.set_physics_process(false)
	sam.set_process(false)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.global_position = sam.global_position+Vector3(2,1.3,3)
	camera.look_at(sam.global_position+Vector3.UP*.9)
	for angle in [-.7,0,.7]:
		sam.head_yaw = angle
		sam._process(0)
		for i in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/sam_guard_%s.png" % str(angle))
	level.queue_free()
	await process_frame
	quit()
