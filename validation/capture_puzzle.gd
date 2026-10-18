extends SceneTree
func _init() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("CameraTraining").enabled = false
	level.get_node("TutorialIntro").set_process(false)
	var director = level.get_node("TutorialIntro")
	director.switch_sequence("res://assets/cinematics/tutorial_intro/platform_sequence.json")
	director.start_sequence(true)
	director.finish_sequence(false)
	level.get_node("HUD").hide()
	var player = level.get_node("Player")
	player.set_physics_process(false)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.position = Vector3(-34,11,-23)
	camera.look_at(Vector3(-32,4,-23))
	camera.current = true
	for i in range(180): await physics_frame
	var puzzle = level.get_node("TutorialPuzzle")
	for rock in puzzle.rocks:
		print("Rock: ",rock.name," pos=",rock.global_position," ground=",rock.is_on_floor()," feet=",rock.bottom())
		for i in rock.get_slide_collision_count(): print("Contact: ",rock.get_slide_collision(i).get_collider().get_path())
	for seesaw in puzzle.seesaws: print("Seesaw: ",seesaw.name," tilt=",seesaw.tilt)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/puzzle_dynamic.png")
	var training = level.get_node("CameraTraining")
	training._show_dialogue(14)
	training.letterbox._process(1.5)
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/original_letterbox.png")
	player.capture_mouse(false)
	level.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit()
