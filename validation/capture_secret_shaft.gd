extends SceneTree
func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1000,800)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	level.set_script(null)
	for child in level.get_children():
		if child.name not in ["Scenery","WorldEnvironment","Collision"]: child.free()
	root.add_child(level)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(27,1,20)
	camera.look_at(Vector3(27,-9.51,20),Vector3.FORWARD)
	camera.fov = 70
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/secret_shaft.png")
	level.queue_free()
	await process_frame
	quit()
