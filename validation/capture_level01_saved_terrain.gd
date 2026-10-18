extends SceneTree

func _init(): call_deferred("capture")

func capture():
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	# Inspect only the saved scene, as in the editor: no gameplay import.
	level.set_script(null)
	for child in level.get_children():
		if child.name not in ["Scenery","WorldEnvironment","Collision"]:
			child.free()
	root.add_child(level)
	current_scene = level
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = Vector3(5,35,35)
	camera.look_at(Vector3(8,0,-7))
	camera.current = true
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/level01_saved_terrain.png")
	print("Saved scene terrain surfaces: ",level.get_node("Scenery").mesh.get_surface_count(),"; no gameplay importer executed")
	level.queue_free()
	await process_frame
	quit()
