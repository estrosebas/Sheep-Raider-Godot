extends SceneTree
var failures = 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	if not value: failures+=1; push_error(label)
func key(code: int):
	for pressed in [true,false]:
		var event = InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()
func clean(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):node.stop();node.stream=null
	scene.queue_free();await process_frame
func run():
	var identity = str(Time.get_ticks_usec())
	GameLocalization.config_path="user://onboarding_test_"+identity+".cfg"
	GameLocalization.initialized=false;GameLocalization.ensure()
	check(not GameLocalization.language_selected,"Missing language preference requires selection")
	GameLocalization.save_loading(false,"modern")
	GameLocalization.initialized=false;GameLocalization.ensure()
	check(not GameLocalization.language_selected,"Other saved options do not imply a chosen language")
	check(GameLocalization.select("es"),"Language preference saves")
	GameLocalization.initialized=false;GameLocalization.ensure()
	check(GameLocalization.language_selected and not GameLocalization.loading_enabled,"Saved language and other options survive reload")
	SaveFiles.startup_offered=true;SaveFiles.directory="user://onboarding_saves_"+identity
	SaveFiles.pending={};OriginalProgress.restore({})
	var stats = get_first_node_in_group("optional_statistics")
	stats.choice="declined"
	var help = get_first_node_in_group("first_run_help")
	help.config_path=GameLocalization.config_path
	help.automatic=true;help.acknowledged=false
	var wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel);current_scene=wheel
	check(wheel.wheel==null,"Remembered language skips native wheel actors")
	await create_timer(3,true).timeout
	check(current_scene and current_scene.scene_file_path==SaveFiles.STUDIO_SCENE,"Remembered language enters studio directly")
	check(paused and is_instance_valid(help.dialog),"First playable startup automatically shows help")
	if is_instance_valid(help.dialog):
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/first_run_help.png")
		help.close_help()
	key(KEY_H)
	check(paused and is_instance_valid(help.dialog),"H opens shared help")
	key(KEY_H)
	check(not paused and help.acknowledged,"H closes help and acknowledges onboarding")
	await process_frame
	check(not paused,"Acknowledged help is not automatically reopened")
	var settings=ConfigFile.new();settings.load(GameLocalization.config_path)
	check(settings.get_value("onboarding","controls_seen",false),"First-use help acknowledgment persists alongside locale")
	help.open_help()
	var box=help.dialog.get_child(0).get_child(0)
	box.get_child(2).pressed.emit()
	check(not paused and not is_instance_valid(help.dialog),"Native close button resumes on touch-capable devices")
	await clean(current_scene)
	var level=load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level);current_scene=level
	level.get_node("DaffyLessons").movies[0].played=true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.2).timeout
	var goal=level.get_node("Goal_115")
	goal.complete(level.get_node("Sheep_52"))
	check(SaveFiles.read_slot(SaveFiles.AUTO_SLOT).progress.completed_levels.lvl_01,"Goal still autosaves before leaving")
	await create_timer(3,true).timeout
	check(current_scene and current_scene.scene_file_path==SaveFiles.STUDIO_SCENE,"Goal returns to studio without Enter")
	await clean(current_scene)
	DirAccess.remove_absolute(GameLocalization.config_path)
	print("Remembered language / first-use help / automatic goal return: %d failures" % failures)
	quit(failures)
