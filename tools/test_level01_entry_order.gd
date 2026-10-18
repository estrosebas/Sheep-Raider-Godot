extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func clean(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.process_mode = Node.PROCESS_MODE_DISABLED; scene.queue_free(); await process_frame
func run():
	GameLocalization.ensure(); GameLocalization.select("es",false)
	var original_enabled = GameLocalization.loading_enabled; var original_style = GameLocalization.loading_style
	var overlay = root.get_node("LevelLoading")
	for loading in [true,false]:
		SaveFiles.startup_offered = true; SaveFiles.pending = {"restart":true}
		var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
		await process_frame; await process_frame
		GameLocalization.loading_enabled = loading; GameLocalization.loading_style = "modern"
		overlay.enter_from_door("res://scenes/levels/Level01.tscn")
		if loading:
			for i in range(1200):
				overlay._process(.02); await process_frame
				if overlay.ready_to_enter: break
			check(overlay.ready_to_enter,"Level01 finishes scene preparation before confirming")
			overlay.finish()
		else: await scene_changed
		var level = current_scene; var player = level.player; var lessons = level.get_node("DaffyLessons")
		var entry = level.get_node("EntryController")
		check(entry.stage=="cinematic" and lessons.active_movie==lessons.movies[0] and player.restart_fade_remaining==0,"Door begins CIN00 before any iris, loading="+str(loading))
		check(lessons.movies[0].camera.current and not player.camera.current,"First visible view is cinematic camera rather than Ralph gameplay camera")
		for i in range(25): await physics_frame
		check(not player.restart_fade.iris_enabled and entry.stage=="cinematic" and not player.is_physics_processing(),"Camera cinematic runs without a competing iris")
		lessons.movies[0].finish_sequence(true); await process_frame
		check(lessons.active_movie==lessons.movies[4],"Original CIN00 still chains the Lucas entry CIN04")
		check(player.restart_fade_remaining==0 and entry.stage=="cinematic","Lucas dialogue has priority; no gameplay iris between CIN00 and CIN04")
		lessons.movies[4].finish_sequence(true)
		check(entry.stage=="iris" and player.restart_fade.iris_enabled and player.restart_fade_remaining>0 and player.is_physics_processing(),"After Lucas finishes, outward iris opens on the restored gameplay camera")
		for i in range(80): await physics_frame
		check(player.restart_fade_remaining==0 and entry.stage=="done" and not player.cinematic_controls_locked,"Iris completes and Ralph is finally playable")
		await clean(level)
	GameLocalization.loading_enabled = original_enabled; GameLocalization.loading_style = original_style
	print("Level01 camera / Lucas / iris / gameplay controller: ",failures," failures"); quit(failures)
