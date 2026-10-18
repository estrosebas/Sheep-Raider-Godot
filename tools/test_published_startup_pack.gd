extends SceneTree
var failures = 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	if not value: failures+=1;push_error(label)
func run():
	var client=root.get_node("ContentUpdates")
	check(client.mounted and client.current_sequence()==3,"Signed 1.0.4 content mounted before autoload compilation")
	var identity=str(Time.get_ticks_usec())
	GameLocalization.config_path="user://published_locale_"+identity+".cfg"
	GameLocalization.initialized=false;GameLocalization.select("es")
	SaveFiles.startup_offered=true;SaveFiles.directory="user://published_saves_"+identity
	var statistics=get_first_node_in_group("optional_statistics")
	statistics.config_path="user://published_privacy_"+identity+".cfg"
	statistics.choice="unknown"
	var wheel=load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel);current_scene=wheel
	check(wheel.wheel==null,"Compiled startup respects remembered locale")
	await create_timer(3,true).timeout
	check(current_scene and current_scene.scene_file_path==SaveFiles.STUDIO_SCENE,"Compiled pack enters studio directly")
	check(not FileAccess.file_exists(client.storage.path_join("trial.json")),"Successful studio startup confirms update without the language wheel")
	check(paused and is_instance_valid(statistics.dialog),"Skipping language selection still asks for statistics consent")
	statistics.set_consent(false)
	check(not paused and not statistics.session_sent,"Declining continues with zero telemetry")
	var help=get_first_node_in_group("first_run_help")
	check(help!=null,"Compiled pack includes shared first-run help")
	var controls=root.get_node("MobileControls")
	controls.set_enabled(true);controls.update_layout()
	check(controls.buttons.has("help"),"Compiled mobile UI includes help button")
	controls.set_enabled(false)
	DirAccess.remove_absolute(GameLocalization.config_path)
	DirAccess.remove_absolute(statistics.config_path)
	for node in current_scene.find_children("*","AudioStreamPlayer",true,false):node.stop();node.stream=null
	current_scene.queue_free();await process_frame
	print("Signed 1.0.4 / direct studio / startup confirmation / consent / help: %d failures" % failures)
	quit(failures)
