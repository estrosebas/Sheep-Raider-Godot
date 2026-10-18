extends SceneTree
func _init(): call_deferred("run")
func run():
	var client=root.get_node("ContentUpdates")
	var failures=0
	if client.current_sequence()!=int(client.config.get("bundled_sequence",0)) or client.mounted:
		failures+=1;printerr("An installer must retain its baseline and ignore older/equal cached content")
	print("Bundled content baseline / older cache exclusion: ",failures," failures")
	quit(failures)
