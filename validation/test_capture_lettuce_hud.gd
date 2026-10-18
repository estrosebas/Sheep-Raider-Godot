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
	var hud: OriginalLettucePrompt
	for child in player.get_children():
		if child is OriginalActionPrompt:
			for widget in child.get_children():
				if widget is OriginalLettucePrompt: hud = widget
	var failures = 0
	if not hud or hud.result.is_empty() or not hud.result.sheep:
		printerr("HUD must select the available sheep"); failures += 1
	for candidate in level.get_node("Flock").sheep:
		candidate.global_position = Vector3(200,0,200)
	for leaf in pig.salads:
		if leaf != salad: leaf.global_position = Vector3(210,0,200)
	var next_leaf = pig.salads[1]
	next_leaf.global_position = player.global_position + Vector3(2,0,0)
	await create_timer(.6).timeout
	if hud.result.is_empty() or hud.result.sheep or hud.result.target != next_leaf:
		printerr("HUD must switch to the closest lettuce"); failures += 1
	await save_image("res://validation/lettuce_hud_chain.png")
	next_leaf.global_position = player.global_position + Vector3(5.5,0,0)
	await create_timer(.1).timeout
	if hud.result.is_empty() or not hud.result.near_limit or hud.prompt_tint().r <= hud.prompt_tint().b:
		printerr("HUD must warn in red near the original range limit"); failures += 1
	await save_image("res://validation/lettuce_hud_warning.png")
	next_leaf.global_position += Vector3(10,0,0)
	await create_timer(.6).timeout
	if hud.visible or not hud.result.is_empty():
		printerr("HUD must disappear outside original range"); failures += 1
	print("Original lettuce HUD failures: ", failures)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
