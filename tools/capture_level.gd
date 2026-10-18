extends SceneTree

# Render the same fixed camera for visual comparisons (requires a real renderer).
# godot --path . --script tools/capture_level.gd -- --output=validation/before.png
func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(960, 540)
	var scene = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").hide()
	scene.get_node("Player/CameraPivot/Camera3D").current = false
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(-92, 7, 54)
	camera.look_at(Vector3(-84, 1, 39))
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var output = "res://validation/level.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = "res://" + arg.trim_prefix("--output=")
		elif arg == "--pc" and scene.has_method("set_texture_profile"):
			scene.set_texture_profile(1)
	for frame in range(12):
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var error = root.get_texture().get_image().save_png(output)
	print("Capture: ", output, " (", error, ")")
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(error)
