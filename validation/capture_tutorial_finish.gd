extends SceneTree
func _init() -> void: call_deferred("capture")
func snapshot(name: String) -> void:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/"+name+".png")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("CameraTraining").enabled = false
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("HUD").hide()
	var player = level.get_node("Player")
	player.capture_mouse(false)
	var finish = level.get_node("TutorialFinish")
	var sheep = finish.sheep
	await create_timer(1.5).timeout
	player.global_position = sheep.global_position+Vector3(0,0,1)
	player.skeleton.rotation.y = PI
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.global_position = sheep.global_position+Vector3(3,1.5,4)
	camera.look_at(sheep.global_position+Vector3.UP*.6)
	camera.current = true
	await snapshot("final_sheep_grounded")
	for i in range(20): await physics_frame
	sheep.interact(player)
	await create_timer(1.7).timeout
	await snapshot("final_sheep_carried")
	sheep.drop()
	sheep.global_position += Vector3(4,0,0)
	var rocket = level.get_node("Rocket_77")
	rocket.equip_to(player)
	player.play_anim("idle")
	player.skeleton.rotation.y = 0
	camera.global_position = player.global_position+Vector3(2,1.3,-3)
	camera.look_at(player.global_position+Vector3.UP*.8)
	await snapshot("rocket_back_corrected")
	var p = finish.goal["pos"]
	var goal = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	rocket.store()
	player.global_position = goal
	await create_timer(1.1).timeout
	print("Goal standing: ",player.global_position,"bounds=",finish.bounds)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await process_frame
	quit()
