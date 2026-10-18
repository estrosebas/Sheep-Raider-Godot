extends SceneTree
var failures = 0
func check(value: bool, label: String):
	if not value: failures+=1; push_error(label)
func _initialize(): call_deferred("run")
func run():
	var client = root.get_node("ContentUpdates")
	check(client.mounted and client.current_sequence()==2,"Signed statistics pack cold mounted")
	var stats = get_first_node_in_group("optional_statistics")
	check(stats!=null,"Existing autoload bridge loaded updatable statistics service")
	if not stats: quit(1);return
	stats.config_path="user://stats_pack_test_%d.cfg" % Time.get_ticks_usec()
	stats.choice="unknown"
	var wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel);current_scene=wheel
	await create_timer(2).timeout
	check(paused and is_instance_valid(stats.dialog),"Compiled startup wheel opens explicit consent")
	stats.set_consent(false)
	check(not paused and not stats.session_sent,"Decline resumes compiled game without collection")
	DirAccess.remove_absolute(stats.config_path)
	for node in wheel.find_children("*","AudioStreamPlayer",true,false):node.stop();node.stream=null
	wheel.queue_free();await process_frame
	print("Signed statistics pack cold startup: %d failures" % failures)
	quit(failures)
