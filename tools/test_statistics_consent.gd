extends SceneTree
var failures = 0
func check(value: bool, label: String):
	if not value: failures += 1; push_error(label)
func _initialize(): call_deferred("run")
func run():
	var script = load("res://scripts/ui/optional_statistics.gd")
	var node = script.new()
	node.config_path = "user://statistics_test_%d.cfg" % Time.get_ticks_usec()
	root.add_child(node)
	check(node.choice=="unknown" and not node.session_sent,"No collection before consent")
	node.open_if_needed()
	check(paused and is_instance_valid(node.dialog),"Prompt pauses background")
	node.set_consent(false)
	check(not paused and node.choice=="declined" and not node.session_sent,"Decline resumes without sending")
	var second = script.new()
	second.config_path=node.config_path
	root.add_child(second)
	check(second.choice=="declined","Decline persists")
	second.open_if_needed()
	check(not is_instance_valid(second.dialog),"No repeated prompt after decline")
	paused=true
	node.open_preferences()
	node.set_consent(true)
	check(paused,"Preferences preserve pause menu state")
	check(node.choice=="accepted" and not node.session_sent,"Headless/editor runs excluded")
	node.set_consent(false)
	check(node.request==null,"Revocation has no pending request")
	DirAccess.remove_absolute(node.config_path)
	paused=false
	node.queue_free();second.queue_free()
	await process_frame
	print("Statistics consent: %d failures" % failures)
	quit(failures)
