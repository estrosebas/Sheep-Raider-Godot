extends SceneTree
func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.3).timeout
	var clock: OriginalTimeKeeper = level.get_node("TimeKeeper_65")
	var player: RalphController = level.player
	player.set_physics_process(false)
	player.global_position = player.respawn_ground_position(clock.global_position+Vector3(-.8,0,0))
	for i in range(8):
		await physics_frame
		player._physics_process(1.0/60)
	print("Clock native position ",clock.global_position," player ",player.global_position," floor ",player.is_on_floor()," usable ",clock.can_interact(player))
	player.hide()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = player.global_position+Vector3(-1.5,1.2,0)
	camera.look_at(clock.global_position+Vector3.UP*.6)
	camera.current = true
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/clock_original_location.png")
	player.inventory.interact_or_use()
	print("After actual E interaction: ",clock.state," reward ",OriginalProgress.has_clock("lvl_01"))
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	OriginalProgress.restore({})
	quit()
