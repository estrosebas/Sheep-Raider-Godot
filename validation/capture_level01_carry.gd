extends SceneTree
func _init(): call_deferred("capture")
func save_image(path: String):
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
	await create_timer(.3).timeout
	var player = level.player
	player.set_physics_process(false)
	player.global_position = Vector3(-33,1.3,-49)
	player.skeleton.rotation.y = 0
	var sheep = level.get_node("Sheep_52")
	sheep.carried_by = player
	player.carried_sheep = sheep
	sheep.carry_heading = 0
	sheep.visual.idle("stand8")
	for other in get_nodes_in_group("grounded_npcs"):
		if other != sheep: other.hide()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.position = player.global_position+Vector3(2,1.4,3)
	camera.look_at(player.global_position+Vector3.UP*.9)
	camera.current = true
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["sheep_carry_idle","sheep_carry_tired","sheep_carry_sneak","sheep_carry_jump"]:
		player.play_anim(clip)
		player.animation_player.seek(.15,true)
		player.animation_player.advance(0)
		player.legacy_skin.update_pose()
		await save_image("res://validation/level01_%s.png" % clip)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(.2).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit()
