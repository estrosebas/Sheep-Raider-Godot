extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var node = load("res://scripts/ui/optional_statistics.gd").new()
	node.config_path = "user://stats_http_test_%d.cfg" % Time.get_ticks_usec()
	node.endpoint = "http://127.0.0.1:4940/api/stats/events"
	root.add_child(node)
	node.set_consent(false)
	await create_timer(.2).timeout
	if node.session_sent: quit(1); return
	node.set_consent(true)
	if node.request==null: quit(2); return
	var response = await node.request.request_completed
	if response[1]!=202: printerr("Unexpected stats HTTP status: ",response[1]);quit(3);return
	node.send_session() # Must not send a second event.
	node.set_consent(false)
	node.send_session() # Must not send after revocation.
	DirAccess.remove_absolute(node.config_path)
	node.queue_free();await process_frame
	print("Godot optional statistics real HTTP: PASS")
	quit(0)
