extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	GameLocalization.ensure()
	var saved_config = GameLocalization.config_path
	var saved_language = GameLocalization.locale
	var saved_enabled = GameLocalization.loading_enabled
	var saved_style = GameLocalization.loading_style
	GameLocalization.config_path = "user://validation_loading_options.cfg"
	check(GameLocalization.save_loading(false,"modern"),"Loading settings save to the shared config")
	check(GameLocalization.select("en"),"Changing language persists successfully")
	var config = ConfigFile.new(); config.load(GameLocalization.config_path)
	check(config.get_value("loading","enabled")==false and config.get_value("loading","style")=="modern" and config.get_value("language","locale")=="en","Language save preserves loading settings")
	GameLocalization.initialized = false; GameLocalization.ensure()
	check(not GameLocalization.loading_enabled and GameLocalization.loading_style=="modern" and GameLocalization.locale=="en","Restart loads language and both loading settings")
	var overlay = root.get_node("LevelLoading")
	var touch_controls = root.get_node("MobileControls")
	touch_controls.set_enabled(true)
	check(overlay.bar_frame.get_width()==211 and overlay.bar_frame.resource_path.ends_with("bar_frame.png"),"Loading border uses recovered original chalk texture")
	check(overlay.target.is_empty() and not overlay.visible,"Starting directly in editor does not display loading art")
	check(overlay.image_paths("res://scenes/levels/Level02.tscn","modern").art.ends_with("modern/LEV02.jpg"),"Modern uses compatible remaster without modifying user source")
	check(overlay.image_paths("res://scenes/levels/Level17.tscn","modern").art.ends_with("pantallas_carga/LEV17.png"),"Missing remaster safely falls back to classic artwork")
	for locale in ["es","en","it","pt_BR"]:
		GameLocalization.select(locale,false)
		check(overlay.image_paths("res://scenes/levels/Level02.tscn","classic").combined.contains("/"+locale+"/LEV02_ready.png"),"Classic combined image follows locale "+locale)
	GameLocalization.select("en",false)
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	var menu = OriginalPauseMenu.new(); lab.add_child(menu)
	menu.show_page("options")
	check(menu.actions.has("loading_enabled") and menu.actions.has("loading_style"),"Options menu exposes loading on/off and classic/modern")
	menu.activate("loading_enabled"); menu.activate("loading_style")
	check(GameLocalization.loading_enabled and GameLocalization.loading_style=="classic","Both options switch and persist")
	menu.queue_free()
	for style in ["classic","modern"]:
		if style=="modern":
			GameLocalization.loading_enabled = false
			overlay.enter_from_door("res://scenes/testing/ItemLab.tscn")
			await scene_changed; await process_frame
			lab = current_scene
		GameLocalization.save_loading(true,style)
		var actor = lab.get_node("Player")
		actor.global_position = Vector3(20,0,20); actor.set_state(actor.WolfState.IDLE); actor.restart_fade_remaining = 0
		var door = lab.get_node("LevelDoor_02")
		if style=="classic":
			check(door.interact(actor),"Real level door accepts interaction")
			door.time = float(door.visual.rig.animations.open.duration)+.5
			door._process(.01)
		else: overlay.enter_from_door("res://scenes/levels/Level02.tscn")
		check(overlay.visible and paused and overlay.target.ends_with("Level02.tscn"),"Door launches the paused loading screen "+style)
		check(overlay.modern==(style=="modern"),"Selected style reaches overlay")
		check(not overlay.ready_to_enter,"Continue is gated until simulated bar and actual load complete")
		check(not overlay.request_touch_continue(),"Early taps cannot skip preparation")
		for i in range(1000):
			overlay._process(.02)
			await process_frame
			if overlay.ready_to_enter: break
		check(overlay.ready_to_enter and overlay.fraction==1,"Bar reaches completion only after threaded scene is ready")
		check(overlay.preparation_complete and current_scene!=lab and current_scene.asset_directory.ends_with("lvl_02") and paused,"Level _ready/setup completes behind loading screen before confirmation")
		var prepared_id = current_scene.get_instance_id()
		if "--capture" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1280,720))
			root.size = Vector2i(1280,720)
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://loading_"+style+".png")
			DisplayServer.window_set_size(Vector2i(1024,768))
			root.size = Vector2i(1024,768)
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://loading_"+style+"_4x3.png")
		# A tap in the centre, outside every control, confirms on a phone.
		var tap = InputEventScreenTouch.new(); tap.index=30; tap.pressed=true
		tap.position = root.get_final_transform()*(root.get_visible_rect().size/2)
		Input.parse_input_event(tap); Input.flush_buffered_events()
		await process_frame; await process_frame
		check(current_scene.get_instance_id()==prepared_id and not paused and not overlay.visible,"Confirmation reveals existing prepared scene without loading/instancing again")
		var new_actor = current_scene.get_node("Player")
		check(new_actor.restart_fade.iris_enabled and new_actor.restart_fade_remaining>0,"Level entry starts original respawn-style outward iris")
		if "--capture" in OS.get_cmdline_user_args() and style=="modern":
			await create_timer(.4).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://loading_entry_iris.png")
			await create_timer(.7).timeout
			check(new_actor.restart_fade_remaining==0 and not new_actor.restart_fade.iris_enabled,"Outward iris completes and restores normal controls")
		print("Load timings ",style,": ",overlay.timing)
		check(overlay.timing.confirm_ms<100,"Confirmation path remains under 100ms without scene setup")
	check(GameLocalization.ui("Pulsa E para continuar")=="Press E to continue","Modern loading text follows selected locale")
	GameLocalization.loading_enabled = false
	check(overlay.enter_from_door("res://scenes/testing/ItemLab.tscn"),"Disabled setting accepts direct transition")
	await process_frame; await process_frame
	check(overlay.target.is_empty() and not overlay.visible and current_scene.name=="ItemLab","Disabled loading skips artwork and fictitious delay")
	check(current_scene.get_node("Player").restart_fade.iris_enabled,"Disabled loading still gets the same outward entry iris")
	for node in current_scene.find_children("*","AudioStreamPlayer",true,false)+current_scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	current_scene.queue_free(); await process_frame
	GameLocalization.config_path = saved_config
	GameLocalization.loading_enabled = saved_enabled; GameLocalization.loading_style = saved_style
	GameLocalization.select(saved_language,false)
	touch_controls.set_enabled(false)
	print("Loading art / settings / languages / real door transitions: ",failures," failures"); quit(failures)
