extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	var original = lab.get_node("Player")
	original.queue_free()
	await process_frame
	var camera = Camera3D.new()
	lab.add_child(camera)
	camera.position = Vector3(3.5, 2.3, 8)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	var players = []
	for index in range(4):
		var player = load("res://scenes/characters/Ralph.tscn").instantiate()
		lab.add_child(player)
		player.position = Vector3(-3.0 + index * 2.0, 0, 0)
		player.set_physics_process(false)
		player.set_process(false)
		player.capture_mouse(false)
		player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.set_state(player.WolfState.RUN)
		player.animation_player.advance(index * 0.05)
		player.apply_legacy_reaction_pose()
		players.append(player)
	camera.current = true
	lab.set_process(false)
	for fixture in lab.get_children():
		if fixture.name.begins_with("Item_") or fixture.name.begins_with("Metal_") or fixture.name in ["Sheep", "GhostTarget"]:
			fixture.hide()
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/run_corrected.png")
	for player in players:
		player.queue_free()
	await process_frame
	var actor = load("res://scenes/characters/Ralph.tscn").instantiate()
	lab.add_child(actor)
	actor.set_physics_process(false)
	actor.capture_mouse(false)
	actor.position = Vector3(-1, 0, 0)
	var sheep = lab.get_node("Item_80")
	sheep.collect(actor.inventory)
	var other = load("res://scenes/characters/Ralph.tscn").instantiate()
	lab.add_child(other)
	other.set_physics_process(false)
	other.capture_mouse(false)
	other.position = Vector3(1, 0, 0)
	lab.get_node("Item_125").collect(other.inventory)
	other.inventory.wheel.hide()
	camera.current = true
	for frame in range(12):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/costumes.png")
	actor.inventory.open_wheel()
	other.inventory.wheel.hide()
	actor.inventory.state.reset()
	for frame in range(20):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/inventory_empty.png")
	actor.inventory.close_wheel()
	other.inventory.state.reset()
	for item in lab.get_children():
		if item is GameItem:
			item.restore()
			item.collect(actor.inventory)
	actor.inventory.open_wheel()
	actor.inventory.state.select_next()
	for frame in range(20):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/inventory_shared_items.png")
	lab.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
