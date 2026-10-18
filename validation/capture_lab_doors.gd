extends SceneTree
func _init() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.get_node("Player").set_physics_process(false)
	var camera = Camera3D.new()
	lab.add_child(camera)
	camera.position = Vector3(0,3,2)
	camera.look_at(Vector3(0,1.5,10))
	camera.current = true
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/lab_studio_doors.png")
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	for node in lab.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	lab.queue_free()
	await process_frame
	quit()
