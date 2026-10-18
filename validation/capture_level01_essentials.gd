extends SceneTree
func _init() -> void: call_deferred("capture")
func snapshot(name: String) -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/"+name+".png")
func capture() -> void:
	SaveFiles.startup_offered = true
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	await create_timer(2).timeout
	var camera = Camera3D.new()
	level.add_child(camera)
	var ralph = level.get_node("Player")
	camera.position = ralph.position+Vector3(1,1.7,2)
	camera.look_at(ralph.position+Vector3.UP*1.4)
	camera.current = true
	await snapshot("level01_ralph_atlas_corrected")
	var sam = level.get_node("Sam_43")
	camera.position = sam.position+Vector3(4,2,6)
	camera.look_at(sam.position+Vector3.UP*.9)
	camera.current = true
	await snapshot("level01_grounded_flock")
	camera.position = Vector3(10,-8,-18)
	camera.look_at(Vector3(17,-17,-26))
	await snapshot("level01_waterfall")
	var actor = level.get_node("Player")
	actor.set_physics_process(false)
	var mailbox = level.get_node("Mailbox_61")
	mailbox._deliver(actor)
	await create_timer(2.7).timeout
	mailbox._release_camera()
	var bomb = level.get_node("Dynamite_70")
	camera.position = bomb.global_position+Vector3(3,2,3)
	camera.look_at(bomb.global_position+Vector3.UP*.6)
	camera.current = true
	await snapshot("level01_dynamite_delivery")
	bomb.ignite(bomb.global_position)
	await create_timer(.8).timeout
	await snapshot("level01_dynamite_lit")
	var telescope = level.get_node("Telescope_69")
	actor.global_position = TutorialProgress.center(telescope.definition["normal_box"])
	actor.set_state(actor.WolfState.IDLE)
	if telescope.interact(actor):
		await snapshot("level01_telescope_optical_view")
		telescope.close()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	quit()
