extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func load_level():
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.25).timeout
	return level
func cleanup(level):
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
func run():
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true
	SaveFiles.directory = "user://progress_goal_test_%d"%Time.get_ticks_msec()
	OriginalProgress.restore({})
	check(OriginalProgress.TOTAL_SHEEP == 17,"Native initial sheepToCatch is17")
	check(OriginalProgress.complete_level("lvl_00") and not OriginalProgress.complete_level("lvl_00"),"Completion is unique per level")
	check(OriginalProgress.extracted_sheep_count() == 1,"Counter derives from completed flags")
	OriginalProgress.restore({})
	var level = await load_level()
	var checkpoint = level.get_node("CheckpointSave")
	check(SaveFiles.valid(checkpoint.snapshot),"Level01 initial checkpoint uses valid shared save schema")
	check(not FileAccess.file_exists(SaveFiles.slot_path(1)),"Checkpoint does not automatically write a save file")
	var player = level.player
	player.set_physics_process(false)
	level.get_node("Sam_43").set_physics_process(false)
	var goal = level.get_node("Goal_115")
	goal.set_physics_process(false)
	check(goal.qualifies(player.respawn_ground_position(goal.global_position),true),"Goal trigger includes the real terrain surface")
	for sheep in level.get_node("Flock").sheep:
		sheep.set_physics_process(false)
		sheep.global_position = Vector3(200,0,200)
	var sheep = level.get_node("Sheep_52")
	player.global_position = goal.global_position
	player.current_state = player.WolfState.IDLE
	player.cinematic_controls_locked = false
	player.restart_fade_remaining = 0
	goal._physics_process(0)
	check(not goal.completed,"Ralph alone cannot complete sheep goal")
	sheep.global_position = goal.global_position
	sheep.dead = true
	goal._physics_process(0)
	check(not goal.completed,"Dead sheep cannot complete goal")
	sheep.dead = false
	goal._physics_process(0)
	check(goal.completed and OriginalProgress.is_completed("lvl_01"),"Native Goal115 accepts Ralph and living sheep and marks level complete")
	check(OriginalProgress.extracted_sheep_count() == 1,"Successful extraction increments once")
	goal.complete(sheep)
	check(OriginalProgress.extracted_sheep_count() == 1,"Repeated goal does not duplicate sheep counter")
	check(not FileAccess.file_exists(SaveFiles.slot_path(1)),"Victory autosave leaves manual slot untouched")
	check(SaveFiles.read_slot(SaveFiles.AUTO_SLOT).progress.completed_levels.lvl_01,"Victory automatically persists completion in its additional slot")
	var dynamite = level.get_node("Dynamite_70")
	dynamite.available = false
	dynamite.store()
	player.inventory.add_item({"id":dynamite.item_id,"class_id":2,"label":"Dinamita","kept":true},dynamite,false)
	var rock_name = ""
	for child in level.get_children():
		if child is OriginalBreakableRocks:
			rock_name = str(child.name)
			child.restore_saved_state(true)
			break
	checkpoint.capture_checkpoint()
	check(SaveFiles.write_slot(1,checkpoint.snapshot) == OK,"Manual save supports Level01")
	var record = SaveFiles.read_slot(1)
	check(not record.is_empty() and record.progress.completed_levels.lvl_01,"Slot includes completion flags")
	check(record.inventory.size() == 1,"Checkpoint inventory is serialized")
	await cleanup(level)
	OriginalProgress.restore({})
	SaveFiles.pending = record
	var restored = await load_level()
	check(OriginalProgress.is_completed("lvl_01") and OriginalProgress.extracted_sheep_count() == 1,"Fresh level load restores progress counter and flags")
	check(restored.player.inventory.state.count_class(2) == 1 and not restored.get_node("Dynamite_70").visible,"Fresh load restores inventory without a world duplicate")
	check(restored.player.global_position.distance_to(SaveFiles.to_vector(record.checkpoint.position)) < .5,"Load resumes checkpoint position")
	if not rock_name.is_empty(): check(restored.get_node(rock_name).broken,"Destroyed obstacle persists across fresh load")
	check(not OriginalProgress.complete_level("lvl_01"),"Loaded completed level cannot increment twice")
	var corrupt = record.duplicate(true)
	corrupt.checkpoint.position = [1,2]
	check(not SaveFiles.valid(corrupt),"Malformed imported checkpoint is rejected")
	await cleanup(restored)
	OriginalProgress.restore({})
	print("Level completion /17 sheep / native goal / manual save / fresh restore: ",failures," failures")
	quit(1 if failures else 0)
