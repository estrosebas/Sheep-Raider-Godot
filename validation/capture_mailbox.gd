extends SceneTree

func _init() -> void: call_deferred("capture")
func snapshot(path: String) -> void:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/"+path+".png")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("CameraTraining").enabled = false
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("HUD").hide()
	var player = level.get_node("Player")
	var mailbox = level.get_node("Mailbox_54")
	var rocket = level.get_node("Rocket_77")
	player.capture_mouse(false)
	player.global_position = mailbox.global_position+Vector3(0,0,1)
	player.skeleton.rotation.y = PI
	for i in range(12): await physics_frame
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = player.global_position+Vector3(3,2,4)
	camera.look_at(mailbox.global_position+Vector3.UP*.8)
	camera.current = true
	await snapshot("mailbox_request")
	mailbox.interact(player)
	await create_timer(.7).timeout
	await snapshot("mailbox_delivery")
	await create_timer(3.8).timeout
	player.global_position = rocket.global_position+Vector3(0,0,.7)
	for i in range(12): await physics_frame
	camera.global_position = player.global_position+Vector3(3,2,4)
	camera.look_at(player.global_position+Vector3.UP*.9)
	camera.current = true
	rocket.collect(player.inventory)
	await create_timer(.2).timeout
	await snapshot("mailbox_pickup")
	await create_timer(1).timeout
	player.inventory.open_wheel()
	player.inventory.state.select_class(10)
	player.inventory.close_wheel()
	await create_timer(.6).timeout
	camera.global_position = player.global_position+Vector3(2,1.3,-3)
	camera.look_at(player.global_position+Vector3.UP*.8)
	await snapshot("rocket_back")
	level.queue_free()
	await process_frame
	quit()
