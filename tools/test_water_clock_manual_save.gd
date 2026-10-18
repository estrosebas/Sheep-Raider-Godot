extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func clean(scene):
	paused = false
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.process_mode = Node.PROCESS_MODE_DISABLED; scene.queue_free(); await process_frame
func run():
	OriginalProgress.restore({}); SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_51").set_physics_process(false)
	level.get_node("LevelEnvironment").set_physics_process(false)
	var environment = level.get_node("LevelEnvironment")
	player.global_position = Vector3(-10,-8,15); player.skeleton.rotation.y = 0
	var target = player.global_position+Vector3.UP*.6
	var wall = StaticBody3D.new(); wall.collision_layer = 2
	var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = Vector3(8,8,.3); collision.shape = shape; wall.add_child(collision)
	level.add_child(wall); wall.global_position = target+Vector3(0,.8,-2)
	await physics_frame; await physics_frame
	var point = environment.clear_death_camera(target)
	var query = PhysicsRayQueryParameters3D.create(target,point,3); query.exclude = [player.get_rid()]
	check(level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Death camera selects a clear view instead of sitting behind the wall")
	wall.queue_free(); player.global_position = Vector3(100,10,100)
	var platform = level.get_node("WoodenPlatForm_46")
	var door = level.get_node("SecretDoor_73")
	var door_start = door.position.y
	var passage_ray = PhysicsRayQueryParameters3D.create(Vector3(-20,-2,5),Vector3(-18,-2,5),1)
	passage_ray.exclude = [player.get_rid()]
	check(not level.get_world_3d().direct_space_state.intersect_ray(passage_ray).is_empty(),"Closed clock door physically blocks its original passage")
	var rock = level.get_node("Rock_48"); rock.stop_push(false)
	rock.global_position = platform.global_position+Vector3(0,2,0); rock.velocity = Vector3.DOWN
	for i in range(300): await physics_frame
	check(platform.last_load==2 and absf(platform.position.y-platform.heavy_y)<.15,"Falling original rock physically lowers the weighted platform to its native endpoint")
	check(door.position.y>door_start+3 and is_equal_approx(door.position.y,platform.door_collision.position.y),"Door artwork and actual collider rise together, releasing clock passage")
	check(level.get_world_3d().direct_space_state.intersect_ray(passage_ray).is_empty(),"Original clock passage becomes physically clear after rock lowers platform")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint(); var snapshot = save.snapshot.duplicate(true)
	platform.set_height(platform.home_y)
	check(save.restore_checkpoint(snapshot) and absf(platform.position.y-platform.heavy_y)<.15,"Manual checkpoint state preserves weighted platform and opened clock door")
	var clock = level.get_node("TimeKeeper_70")
	player.global_position = clock.global_position+Vector3(.2,0,0); player.velocity = Vector3.ZERO
	player.cinematic_controls_locked = false; player.restart_fade_remaining = 0
	check(clock.interact(player) and OriginalProgress.has_clock("lvl_02"),"Released level02 clock can actually be collected with its shared interaction")
	await clean(level)
	SaveFiles.pending = {}; SaveFiles.startup_offered = true
	var one = load("res://scenes/levels/Level01.tscn").instantiate(); root.add_child(one); current_scene = one
	await create_timer(.3).timeout
	var lessons = one.get_node("DaffyLessons")
	for movie in lessons.movies.values():
		if movie.playing: movie.finish_sequence(true)
		movie.played = true
	lessons.active_movie = null; lessons.intro_finished = true; lessons.set_process(false)
	player = one.player; player.cinematic_controls_locked = false; player.restart_fade_remaining = 0; player.set_physics_process(false)
	one.get_node("Sam_43").reset_guard(); one.get_node("Sam_43").set_physics_process(false)
	var checkpoints = one.get_node("Checkpoints"); checkpoints.set_physics_process(false)
	var index = -1
	for i in range(checkpoints.entries.size()):
		if not checkpoints.entries[i].joint and not checkpoints.entries[i].wolf.is_empty(): index = i; break
	var box = checkpoints.entries[index].triggers[0]
	player.global_position = GameSpace.original_point(Vector3((box.min[0]+box.max[0])/2,(box.min[1]+box.max[1])/2,(box.min[2]+box.max[2])/2))
	checkpoints.quiet_time = 3; checkpoints._physics_process(.016); await process_frame
	var menu = one.get_node("PauseMenu"); var checkpoint = one.get_node("CheckpointSave")
	check(checkpoint.snapshot.checkpoint.index==index,"Level01 real checkpoint signal captures manual-save snapshot")
	var old_directory = SaveFiles.directory; SaveFiles.directory = "user://validation_clock_water_saves"
	for slot in range(1,4):
		var path = SaveFiles.slot_path(slot)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	menu.open_menu(); menu.show_page("save"); menu.activate("slot_1")
	check(not SaveFiles.read_slot(1).is_empty() and SaveFiles.read_slot(1).checkpoint.index==index,"Selecting a slot through the actual level01 pause menu writes its checkpoint")
	menu.activate("slot_1")
	check(menu.page=="confirm" and menu.confirmation=="save_slot","Existing manual slot asks for overwrite confirmation")
	menu.activate("confirmed")
	check(SaveFiles.valid(SaveFiles.read_slot(1)) and menu.page=="save","Overwrite confirmation writes a valid manual save")
	menu.close_menu()
	var goals = one.find_children("Goal*","",false,false)
	goals[0].complete(one.get_node("Flock").sheep[0])
	menu.open_menu(); menu.show_page("save"); menu.activate("slot_2")
	check(SaveFiles.read_slot(2).progress.completed_levels.lvl_01,"Manual save through pause menu also records level01 completion")
	SaveFiles.directory = old_directory
	await clean(one)
	print("Water camera / clock platform / actual manual-save UI: ",failures," failures"); quit(failures)
