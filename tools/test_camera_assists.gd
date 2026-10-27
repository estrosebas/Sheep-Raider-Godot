extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var prior_path = GameLocalization.config_path
	GameLocalization.config_path = "user://camera_assists_test_%d.cfg"%Time.get_ticks_usec()
	GameLocalization.initialized = false; GameLocalization.ensure()
	check(not GameLocalization.camera_assists_enabled(),"First installation defaults to assists OFF")
	var config = ConfigFile.new()
	config.set_value("language","locale","es"); config.set_value("loading","style","modern")
	config.save(GameLocalization.config_path)
	GameLocalization.initialized = false; GameLocalization.ensure()
	check(not GameLocalization.camera_assists_enabled(),"Configs without a camera preference default to assists OFF")
	check(GameLocalization.save_camera_assists(false),"Assist preference writes successfully")
	GameLocalization.initialized = false; GameLocalization.ensure()
	check(not GameLocalization.camera_assists_enabled() and GameLocalization.locale=="es" and GameLocalization.loading_style=="modern","Off survives a config reload without losing language/loading preferences")
	check(GameLocalization.save_camera_assists(true),"Assist preference can be enabled again")
	GameLocalization.initialized = false; GameLocalization.ensure()
	check(GameLocalization.camera_assists_enabled(),"Previously saved ON choice survives reload")
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://camera_assist_slots_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var total = 0; var paths = 0
	for index in range(7):
		var level = load("res://scenes/levels/Level%02d.tscn"%index).instantiate(); root.add_child(level); current_scene = level
		await process_frame; await physics_frame
		var player = level.get_node("Player")
		for movie in level.find_children("*","Node",true,false):
			if movie is OriginalSequence:
				if movie.playing: movie.finish_sequence(true)
				movie.set_process(false)
		player.set_physics_process(false); player.cinematic_controls_locked = false; player.restart_fade_remaining = 0
		player.camera.make_current()
		var controller = level.get_node_or_null("CameraZones")
		check(controller is OriginalCameraZones,"Level%02d installs the shared camera controller"%index)
		if controller:
			controller.set_process(false)
			var records = controller.data.cameras
			total += records.size()
			for record in records: if not record.trajectory.is_empty(): paths += 1
			var eligible = records.filter(func(rule): return rule.follow and not rule.boxes.is_empty())
			check(not eligible.is_empty(),"Level%02d has native follow-camera volumes"%index)
			if not eligible.is_empty():
				player.global_position = TutorialProgress.center(eligible[0].boxes[0])
				for i in range(65): controller._process(.016)
				check(controller.camera_rule!=-1 and player.camera_pivot.rotation.is_finite() and player.camera_pivot.spring_length>=0,"Level%02d activates a valid imported camera"%index)
				var before = controller.camera_snapshot()
				GameLocalization.save_camera_assists(false)
				controller._process(.016)
				check(controller.camera_rule==-1 and controller.camera_returning,"Disabling assists returns smoothly even inside a native zone")
				for i in range(70): controller._process(.016)
				check(controller.saved_camera.is_empty(),"Free mode releases the camera after return")
				var free_view = controller.camera_snapshot()
				for i in range(8): controller._process(.1)
				check(player.camera_pivot.rotation.is_equal_approx(free_view.rotation),"Free mode does not reapply zone angles")
				GameLocalization.save_camera_assists(true)
		var menu = level.get_node("PauseMenu")
		menu.show_page("options")
		check(menu.actions.has("camera_assists"),"Options exposes camera assists")
		menu.activate("camera_assists")
		check(not GameLocalization.camera_assists_enabled(),"Pause option toggles and persists assists")
		menu.activate("camera_assists")
		check(GameLocalization.camera_assists_enabled(),"Pause option enables assists again")
		if index==6:
			GameLocalization.save_camera_assists(false)
			var env = level.get_node("LevelEnvironment")
			env.start_launch_camera(env.seesaws[1].definition.launch_cameras[0],true,player)
			check(not is_instance_valid(env.launch_camera),"Free mode skips optional launch camera creation")
			var intro = level.get_node("LevelCinematics").movies[0]
			player.cinematic_controls_locked = false; player.restart_fade_remaining = 0
			check(intro.start_sequence(true) and intro.camera.current,"Free mode retains the native entry cinematic and its camera")
			if intro.playing: intro.finish_sequence(true)
			GameLocalization.save_camera_assists(true)
		for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
		level.queue_free(); await process_frame
	check(total==56 and paths==20,"All56 original zone records and20 camera paths imported across00..06")
	check(absf(OriginalCameraZones.angle_limit(deg_to_rad(355),350,10)-deg_to_rad(355))<.001,"Angle ranges crossing zero preserve valid yaw")
	var point = OriginalCameraZones.closest_path_point(Vector3(2,1,5),[[0,0,0],[1000,0,0]])
	check(point.distance_to(Vector3(2,0,0))<.001,"Native path projection is converted consistently to metres")
	GameLocalization.config_path = prior_path; GameLocalization.initialized = false; GameLocalization.ensure()
	print("Shared camera assists / native00..06 zones / paths / free mode / options / config: ",failures," failures")
	quit(failures)
