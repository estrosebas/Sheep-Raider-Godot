extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func spawn_studio():
	var studio = load(SaveFiles.STUDIO_SCENE).instantiate()
	root.add_child(studio); current_scene = studio
	await create_timer(.25).timeout
	studio.player.set_physics_process(false)
	studio.player.current_state = studio.player.WolfState.IDLE
	studio.player.cinematic_controls_locked = false
	return studio
func stop_scene(scene):
	paused = false
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.queue_free(); await process_frame
func run():
	SaveFiles.directory = "user://studio_door_status_%d"%Time.get_ticks_usec()
	SaveFiles.pending = {}; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_initialized = false
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	var scene = await spawn_studio()
	var player = scene.player
	var door = scene.get_node("LevelDoor_01")
	var display = scene.get_node("DoorStatus")
	check(not scene.has_node("ProgressHUD") and not player.get_node("ActionPrompt").visible and scene.get_node("HUD/Label").text.is_empty(),"Studio has no top-left progress/action legend")
	player.global_position = door.global_position+Vector3.RIGHT
	display._process(.016)
	check(display.text=="nivel 1: nivel no superado" and display.target==door,"Locked nearby door displays exact original MLT171 text")
	check(not door.interact(player),"Showing status does not allow entering a locked level")
	OriginalProgress.award_clock("lvl_01")
	check(door.status_text()=="nivel 1: nivel no superado","Clock alone does not complete a level")
	OriginalProgress.complete_level("lvl_01")
	display._process(.016)
	check(display.text=="nivel 1: nivel completamente superado","Sheep plus clock selects original fully completed status")
	OriginalProgress.restore({}); OriginalProgress.complete_level("lvl_01")
	display._process(.016)
	check(display.text=="nivel 1: nivel superado","Sheep without clock selects original completed status")
	OriginalProgress.complete_level("lvl_00")
	check(scene.get_node("LevelDoor_00").status_text()=="nivel 0: nivel completamente superado","Native tutorial00 exception needs no clock")
	for locale in ["en","it","pt_BR","es"]:
		GameLocalization.select(locale,false); scene.reload_localization(); display.reload_localization()
		check(display.text=="%s 1: %s"%[GameLocalization.text("scene",171,1),GameLocalization.text("scene",171,3)],"Door uses original localized strings: "+locale)
	OriginalProgress.award_clock("lvl_01")
	var menu = scene.get_node("PauseMenu")
	menu.open_menu(); menu.show_page("save"); menu.activate("slot_1"); menu.close_menu()
	var record = SaveFiles.read_slot(1)
	check(record.progress.clocks.has("lvl_01") and record.progress.completed_levels.lvl_01,"Manual slot stores both completion and clock flags")
	await stop_scene(scene)
	OriginalProgress.restore({}); SaveFiles.resume_checkpoint = {}; SaveFiles.studio_initialized = false
	var restored = await spawn_studio()
	var restored_door = restored.get_node("LevelDoor_01")
	check(restored_door.status_text()=="nivel 1: nivel completamente superado","Fresh startup restores full door status from saved progress")
	var restored_display = restored.get_node("DoorStatus")
	restored.player.global_position = restored_door.global_position+Vector3.RIGHT
	restored_display._process(.016)
	check(restored_display.text==restored_door.status_text(),"HUD immediately reflects loaded door status")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); restored.add_child(camera)
		camera.position = restored_door.global_position+Vector3(3,2.3,4)
		camera.look_at(restored_door.global_position+Vector3.UP*1.2); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_door_status.png")
	restored.player.global_position = Vector3(-4.62,0,-4.55)
	restored_display._process(.016)
	check(restored_display.text.is_empty(),"Native door text disappears away from the door")
	await stop_scene(restored)
	OriginalProgress.restore({})
	print("Studio original door strings / 3 states / native tutorial / languages / manual save restore / clean HUD: ",failures," failures")
	quit(failures)
