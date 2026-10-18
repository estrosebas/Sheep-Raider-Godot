extends SceneTree
func _init() -> void: call_deferred("capture")
func snapshot(name: String) -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/"+name+".png")
func capture() -> void:
	SaveFiles.startup_offered = true
	SaveFiles.directory = "user://pause_preview_%d" % Time.get_ticks_usec()
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("CameraTraining").enabled = false
	await create_timer(.5).timeout
	var signs = level.get_node("Signposts")
	var player = level.get_node("Player")
	player.set_physics_process(false)
	var sign_position = signs.signs[0]["position"]
	player.global_position = GameSpace.from_export(Vector3(sign_position[0],sign_position[1],sign_position[2]))
	player.set_state(player.WolfState.IDLE)
	signs.interact(player)
	await snapshot("sign_original_textbox")
	signs.close_sign()
	var menu = level.get_node("PauseMenu")
	menu.open_menu()
	menu.set_process(false)
	menu.clock = .01
	await snapshot("pause_original_font")
	menu.clock = .08
	menu.canvas.queue_redraw()
	await snapshot("pause_glyph_reverse")
	menu.show_page("save")
	await snapshot("pause_save_slots")
	menu.close_menu()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	quit()
