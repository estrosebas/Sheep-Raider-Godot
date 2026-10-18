extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.directory = "user://rock_delivery_test_%d"%Time.get_ticks_usec()
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	var player = level.player
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	var environment = level.get_node("LevelEnvironment")
	var native_camera = environment.seesaws[1].definition.launch_cameras[0]
	environment.start_launch_camera(native_camera,false)
	var shot = environment.launch_camera
	check(shot.camera.current and player.launch_controls_locked and not player.cinematic_controls_locked and shot.camera.global_position.distance_to(GameSpace.original_point(Vector3(460,-1874,2145)))<.01,"Native CamSetup600 freezes input while keeping Ralph physics active")
	shot.elapsed = 1.1
	var cancel = InputEventAction.new(); cancel.action = "cancel"; cancel.pressed = true
	level.get_node("PauseMenu")._input(cancel)
	check(not player.launch_controls_locked and not player.cinematic_controls_locked and not level.get_node("PauseMenu").opened,"Native camera skip returns gameplay rather than opening pause")
	await process_frame
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_63").set_physics_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	check(level.get_node_or_null("box_90")==null and level.get_node_or_null("box_91")==null,"No decorative OPEN1-loop duplicates")
	var mailbox = level.get_node("Mailbox_79"); var rock = level.get_node("Rock_55")
	mailbox._deliver(player); mailbox._release_camera()
	check(mailbox.boxes.all(func(box):return box.state=="fall" and box.held_for_rock),"Authored puzzle boxes start falling rather than appearing sealed on the plank")
	var spawn_heights = mailbox.boxes.map(func(box):return box.global_position.y)
	for index in range(mailbox.boxes.size()):
		check(is_equal_approx(mailbox.boxes[index].global_position.y,mailbox.spawn_positions[index].y),"Mailbox delivery starts at original item height")
	await create_timer(.4).timeout
	for index in range(mailbox.boxes.size()):
		check(mailbox.boxes[index].global_position.y<spawn_heights[index]-2,"Delivered box visibly descends at original 800 units per second")
	check(mailbox.items.all(func(item):return not item.available),"Falling puzzle boxes keep their contents stored")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	var falling_snapshot = save.snapshot.duplicate(true)
	check(SaveFiles.valid(falling_snapshot) and save.restore_checkpoint(falling_snapshot),"Checkpoint accepts and restores containers while the delivery is falling")
	await process_frame
	check(mailbox.boxes.all(func(box):return box.state=="fall" and box.held_for_rock),"Restoring an in-flight delivery continues falling rather than sealing it in midair")
	await create_timer(3).timeout
	check(mailbox.boxes.size()==2 and mailbox.boxes.all(func(box): return box.state=="sealed"),"Native containers stay sealed on seesaw")
	check(mailbox.items.all(func(item): return not item.available) and rock.box_delivered,"Contents stay stored and rock receives MSG_MAILBOX_DELIVERED")
	save.capture_checkpoint()
	var snapshot = save.snapshot.duplicate(true)
	check(SaveFiles.write_slot(1,snapshot)==OK and save.restore_checkpoint(SaveFiles.read_slot(1)),"Sealed containers can be persisted/reloaded")
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	await process_frame
	check(rock.box_delivered and mailbox.boxes.all(func(box): return box.state=="sealed"),"Reload retains unopened puzzle and pending rock variant")
	player.global_position = TutorialProgress.center(rock.definition.cine_camera_box[0])
	rock.global_position = TutorialProgress.center(rock.definition.cine_trigger[0])
	check(rock.try_native_cinematic() and manager.active_movie==manager.movies[1],"Rock box612 selects CIN ROCK2C after delivery")
	var movie = manager.movies[1]
	check(not player.cinematic_controls_locked and player.visible and player.is_physics_processing() and movie.camera.current,"CINE_NO_WOLF_FREEZE preserves gameplay with authored camera")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		await create_timer(2.45).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_native_rock_launch.png")
		await create_timer(5.35).timeout
	else: await create_timer(7.8).timeout
	check(not movie.playing and mailbox.items.all(func(item): return item.available),"Native launch trajectories land both containers and release contents")
	check(mailbox.boxes.all(func(box): return not is_instance_valid(box)),"OPEN1 runs once and all delivered containers disappear")
	rock.global_position = TutorialProgress.center(rock.definition.cine_trigger[0]); rock.box_delivered = false
	player.restart_fade_remaining = 0
	check(rock.try_native_cinematic() and manager.active_movie==manager.movies[4],"Undelivered rock selects native ROCKA variant")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Native level03 rock / authored containers / single opening / cameras / save: ",failures," failures")
	quit(failures)
