extends SceneTree
var failures=0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	var client=root.get_node("ContentUpdates")
	check(client.mounted and client.current_sequence()==1,"Real exported content pack mounted and authenticated")
	check(FileAccess.file_exists("res://scripts/player/ralph_controller.gd.remap"),"Compiled game script remap came from exported archive")
	var scene=load("res://scenes/testing/ItemLab.tscn")
	check(scene!=null,"Native exported scene resolves")
	var lab=scene.instantiate(); root.add_child(lab); current_scene=lab
	await create_timer(.4).timeout
	check(lab.get_node_or_null("Player")!=null and lab.player.animation_player.has_animation("sneak_idle"),"Real compiled controller, animation library and native assets instantiate")
	# Only updater-owned older ZIPs may be pruned after confirming a boot.
	var obsolete=client.storage.path_join("content-999.zip")
	var unrelated=client.storage.path_join("keep-test-note.txt")
	var file=FileAccess.open(obsolete,FileAccess.WRITE);file.store_string("old fixture");file.close()
	file=FileAccess.open(unrelated,FileAccess.WRITE);file.store_string("keep");file.close()
	client.confirm_boot()
	check(not FileAccess.file_exists(obsolete) and FileAccess.file_exists(client.package_file(client.active)),"Confirmation prunes obsolete packs and retains the active pack")
	check(FileAccess.file_exists(unrelated),"Pruning leaves unrelated files alone")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
	lab.queue_free();await process_frame
	print("Production exported ZIP / signature / compiled classes / imported assets: ",failures," failures")
	quit(failures)
