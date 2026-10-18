extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.directory = "user://studio_door_test_%d"%Time.get_ticks_usec()
	SaveFiles.startup_offered = true; SaveFiles.studio_initialized = true
	OriginalProgress.restore({}); OriginalProgress.complete_level("lvl_01")
	var original = load("res://scenes/levels/Level02.tscn").instantiate()
	root.add_child(original); current_scene = original
	await create_timer(.3).timeout
	original.get_node("DaffyLessons").restore_progress({"introduction_seen":true,"intro_finished":true,"challenge_won":true})
	var checkpoints = original.get_node("Checkpoints")
	checkpoints.current_index = 0
	original.player.checkpoint_position = checkpoints.destination_point(checkpoints.entries[0].wolf[0])
	original.get_node("CheckpointSave").capture_checkpoint()
	SaveFiles.remember_level_exit(original)
	check(SaveFiles.valid(SaveFiles.resume_checkpoint),"Level exit remembers actual native checkpoint in memory")
	stop_audio(original); original.queue_free(); await process_frame
	var studio = load(SaveFiles.STUDIO_SCENE).instantiate()
	root.add_child(studio); current_scene = studio
	await create_timer(.3).timeout
	check(studio.returned_sheep.size()==1,"Studio return retains captured sheep")
	var player = studio.player
	var door = studio.get_node("LevelDoor_02")
	player.set_physics_process(false)
	player.global_position = door.global_position+Vector3.RIGHT
	player.current_state = player.WolfState.IDLE
	player.cinematic_controls_locked = false
	check(door.interact(player),"Original level door accepts Ralph interaction")
	GameLocalization.loading_enabled = false
	stop_audio(studio)
	door._process(float(door.visual.rig.animations.open.duration)+.51)
	await scene_changed; await create_timer(.5).timeout
	check(current_scene.scene_file_path=="res://scenes/levels/Level02.tscn","Studio door enters the actual level02 scene")
	check(SaveFiles.pending.is_empty() and current_scene.get_node("DaffyLessons").intro_finished and current_scene.get_node("Checkpoints").current_index==0,"Door restores checkpoint rather than replaying the entrance tutorial")
	check(OriginalProgress.is_completed("lvl_01") and OriginalProgress.extracted_sheep_count()==1,"Restored checkpoint keeps captured sheep from other levels")
	check(not FileAccess.file_exists(SaveFiles.slot_path(1)),"Hub/door/checkpoint transitions never autosave")
	stop_audio(current_scene); current_scene.queue_free(); await process_frame
	OriginalProgress.restore({})
	print("Studio original door / native checkpoint resume / preserve progress: ",failures," failures")
	quit(failures)
