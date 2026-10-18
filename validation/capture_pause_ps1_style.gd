extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.5).timeout
	var player = level.player
	var sam = level.get_node("Sam_43")
	sam.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = sam.home+Vector3(0,0,6)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = player.global_position+Vector3(3,2.3,5)
	camera.look_at(player.global_position+Vector3.UP)
	camera.current = true
	var menu = level.get_node("PauseMenu")
	menu.open_menu()
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/pause_ps1_style.png")
	menu.close_menu()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	quit()
