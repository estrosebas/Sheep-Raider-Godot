extends SceneTree
func _init(): call_deferred("capture")
func save_image(path):
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture():
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	var pig = level.get_node("PorkyLessons")
	pig.set_process(false)
	await create_timer(.4).timeout
	var player = level.player
	level.get_node("Sam_43").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var sheep = level.get_node("Sheep_52")
	player.global_position = Vector3(15.62,.07,-56.73)
	player.velocity = Vector3.ZERO
	sheep.global_position = Vector3(17.8,.01,-57)
	for salad in pig.salads: salad.reveal_from_lesson()
	await create_timer(.5).timeout
	player.set_physics_process(false)
	var salad = pig.salads[0]
	player.inventory.animate_selection = false
	player.inventory.add_item({"id":salad.item_id,"class_id":3,"label":"Lechuga","icon":salad.icon_path,"kept":false},salad)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = Vector3(19,3,-52)
	camera.look_at(Vector3(15.7,.5,-56))
	camera.current = true
	await create_timer(.4).timeout
	await save_image("res://validation/lettuce_distance_and_sheep.png")
	player.inventory.use_selected()
	player.item_actions.set_process(false)
	player.item_actions._process(.25)
	await save_image("res://validation/lettuce_native_put1a.png")
	player.item_actions.cancel()
	salad.store()
	player.global_position = Vector3(7,.05,-25)
	var bridge = level.get_node("bridge_40")
	bridge.set_physics_process(false)
	camera.global_position = Vector3(15,7,-23)
	camera.look_at(Vector3(7,0,-25))
	await save_image("res://validation/bridge_native_pose1.png")
	bridge.state = "breaking"
	bridge._physics_process(1.5)
	await save_image("res://validation/bridge_native_brake2.png")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit()
