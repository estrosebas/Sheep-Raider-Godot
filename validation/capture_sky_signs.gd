extends SceneTree

func _init() -> void:
	call_deferred("capture")
func snapshot(path: String) -> Image:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	picture.save_png("res://validation/"+path+".png")
	return picture
func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("HUD").hide()
	var player = level.get_node("Player")
	var signs = level.get_node("Signposts")
	player.global_position = Vector3(-85.7,0,39.57)
	player.camera_pivot.rotation = Vector3(-0.1,PI,0)
	signs.interact(player)
	await snapshot("sign_original_text")
	signs.close_sign()
	player.global_position = Vector3(-73.91,0,39.28)
	signs.interact(player)
	signs.start_anvil()
	signs._process(0.25)
	await snapshot("sign_anvil")
	signs._process(7)
	signs.close_sign()
	var training = level.get_node("CameraTraining")
	training._show_dialogue(4)
	await snapshot("subtitles_outlined")
	training.card.hide()
	# Pixel comparison of isolated sky from translated cameras, with identical rotation.
	for child in level.get_children():
		if child is Node3D: child.hide()
	level.get_node("OriginalSky").show()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.rotation = Vector3(0.3,0.5,0)
	var first = await snapshot("sky_position_a")
	camera.position = Vector3(250,80,-150)
	var second = await snapshot("sky_position_b")
	var a = first.get_data()
	var b = second.get_data()
	var error = 0
	for i in range(a.size()): error = maxi(error,absi(int(a[i])-int(b[i])))
	# MSAA/interpolation rounding can differ by one 8-bit channel at triangle edges.
	var equal = error <= 1
	print("GPU sky translation invariance: ",equal,"; maximum channel difference = ",error,"/255")
	player.capture_mouse(false)
	level.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(0 if equal else 1)
