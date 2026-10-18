extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func dispose(scene):
	get_tree_unpaused()
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.queue_free(); await process_frame
func get_tree_unpaused(): paused = false
func studio():
	var scene = load(SaveFiles.STUDIO_SCENE).instantiate()
	root.add_child(scene); current_scene = scene
	await create_timer(.25).timeout
	return scene
func run():
	GameLocalization.select("es",false)
	SaveFiles.directory = "user://studio_progress_test_%d"%Time.get_ticks_usec()
	SaveFiles.pending = {}; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_initialized = false
	OriginalProgress.restore({})
	var wheel = OriginalLanguageWheel.new()
	check(wheel.next_scene == SaveFiles.STUDIO_SCENE,"Language selection starts in the studio")
	wheel.free()
	var scene = await studio()
	check(scene.crowd.size()==2 and scene.panel.rig.animations.has("17"),"Studio imports original crowds and sheep counter")
	check(scene.returned_sheep.is_empty() and scene.panel.animation_player.current_animation=="17","New game has zero captured sheep and native remaining17 display")
	check(scene.player.is_on_floor(),"Native studio spawn is grounded on original collision")
	for i in range(3): check(scene.get_node("LevelDoor_%02d"%i).level_scene==SaveFiles.scene_for_level("lvl_%02d"%i),"Studio door opens implemented level "+str(i))
	check(scene.get_node("LevelDoor_00").is_unlocked() and scene.get_node("LevelDoor_01").is_unlocked() and not scene.get_node("LevelDoor_02").is_unlocked(),"New game opens tutorial00 and level01; later levels remain sequential")
	var door02 = scene.get_node("LevelDoor_02")
	var prior_position = scene.player.global_position
	scene.player.set_physics_process(false); scene.player.current_state = scene.player.WolfState.IDLE
	var door01 = scene.get_node("LevelDoor_01")
	scene.player.global_position = door01.global_position+Vector3.RIGHT
	check(door01.can_interact(scene.player),"Fresh save can actually interact with level01 without completing tutorial00")
	scene.player.global_position = door02.global_position+Vector3.RIGHT
	check(not door02.interact(scene.player) and not door02.entering,"E cannot bypass a locked studio level door")
	scene.player.global_position = prior_position; scene.player.set_physics_process(true)
	OriginalProgress.complete_level("lvl_00")
	check(scene.get_node("LevelDoor_01").is_unlocked() and not door02.is_unlocked(),"Completing00 unlocks01 but keeps02 locked")
	OriginalProgress.restore({})
	check(scene.get_node("LaboratoryDoor").level_scene=="res://scenes/testing/ItemLab.tscn","Studio connects to existing laboratory")
	OriginalProgress.complete_level("lvl_01"); OriginalProgress.complete_level("lvl_01"); scene.refresh_progress()
	check(door02.is_unlocked() and scene.get_node("LevelDoor_01").is_unlocked(),"Completing01 unlocks02 and keeps the completed level replayable")
	check(scene.returned_sheep.size()==1 and scene.returned_sheep.has("lvl_01"),"One sheep per completed level, replay cannot duplicate it")
	var pen = scene.source.sheep_collection_box
	check(TutorialProgress.contains(pen,scene.returned_sheep.lvl_01.global_position),"Recovered sheep is displayed in the original sheep collection area")
	check(scene.panel.animation_player.current_animation=="16","Native panel now displays16 remaining")
	await physics_frame
	check(not scene.world_doors["40"].visible and scene.get_node("GateCollision_40").get_child(0).get_child(0).disabled,"Completed level01 opens its original world passage and collider")
	check(not FileAccess.file_exists(SaveFiles.slot_path(1)),"Completing a level does not automatically write a save")
	# An incomplete checkpoint remains resumable separately from the hub flags.
	SaveFiles.resume_checkpoint = {"version":1,"level":"lvl_02","checkpoint":{"index":0,"position":[5.2,.55,-45.1],"facing":0.0,"camera":[0,0,0]},"inventory":[],"world":{"items":[],"sheep":[],"mailboxes":[]},"lessons":{}}
	check(SaveFiles.valid(SaveFiles.resume_checkpoint),"Checkpoint fixture uses existing imported schema")
	var menu = scene.get_node("PauseMenu")
	menu.open_menu(); menu.show_page("save"); menu.activate("slot_1")
	var saved = SaveFiles.read_slot(1)
	check(not saved.is_empty() and saved.level=="studio" and saved.progress.completed_levels.lvl_01,"Manual pause save records hub completion flags")
	check(saved.resume_checkpoint.level=="lvl_02","Hub save retains the incomplete level checkpoint")
	menu.close_menu()
	var malformed = saved.duplicate(true); malformed.resume_checkpoint = saved.duplicate(true)
	check(not SaveFiles.valid(malformed),"Recursive nested hub saves are rejected")
	await dispose(scene)
	SaveFiles.studio_initialized = false; SaveFiles.resume_checkpoint = {}; OriginalProgress.restore({})
	var restored = await studio()
	check(OriginalProgress.extracted_sheep_count()==1 and restored.returned_sheep.size()==1,"Fresh startup restores captured sheep from most recent manual slot")
	check(restored.get_node("LevelDoor_02").is_unlocked(),"Loading saved completion01 also unlocks02")
	check(SaveFiles.resume_checkpoint.level=="lvl_02","Fresh startup remembers the level checkpoint without sending player to that level")
	OriginalProgress.complete_level("lvl_02")
	await dispose(restored)
	var returned = await studio()
	check(OriginalProgress.extracted_sheep_count()==2 and returned.returned_sheep.size()==2,"Return to studio preserves newly won unsaved progress")
	check(SaveFiles.read_slot(1).progress.sheep_extracted==1,"Unsaved win remains absent from disk until manually saved")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_gameplay.png")
		var camera = Camera3D.new(); returned.add_child(camera)
		camera.position = Vector3(-7.0,5,5); camera.look_at(Vector3(-8,2,-6)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_progress.png")
	await dispose(returned)
	# Legacy level-only slots also initialize the studio and preserve progress.
	var legacy = saved.resume_checkpoint.duplicate(true)
	OriginalProgress.restore(saved.progress)
	check(SaveFiles.write_slot(2,legacy)==OK,"Existing level-only save schema remains supported")
	SaveFiles.studio_initialized = false; SaveFiles.resume_checkpoint = {}; OriginalProgress.restore({})
	var recent = SaveFiles.initialize_studio()
	check(recent.level=="lvl_02" and OriginalProgress.is_completed("lvl_01"),"Newest legacy slot restores its progress into studio")
	OriginalProgress.restore({})
	print("Native studio / unique sheep / manual save / startup restore / legacy slots: ",failures," failures")
	quit(failures)
