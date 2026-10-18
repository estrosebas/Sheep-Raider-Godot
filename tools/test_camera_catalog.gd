extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	OriginalCameraCatalog.ensure()
	for record in OriginalCameraCatalog.data.sequences.values():
		check(FileAccess.file_exists(record.source),"Catalog sequence resolves original asset "+record.source)
		var next = OriginalCameraCatalog.next_sequence(record.source)
		if record.has("next"): check(not next.is_empty(),"Next sequence resolves by stable ID")
	var fallback = OriginalCameraCatalog.sequence("res://future/unregistered_sequence.json")
	check(fallback.kind=="camera_animation" and fallback.return_transition=="none","Unknown camera animation never opens iris implicitly")
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	paused = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate(); root.add_child(level); current_scene = level
	await process_frame; await process_frame
	var director = level.get_node("DaffyLessons"); var player = level.player
	check(director.movies[0].camera_kind=="camera_animation" and director.movies[0].return_transition=="none","Camera overview is not implicitly an iris cinematic")
	check(director.movies[4].camera_kind=="intro_cinematic" and director.movies[4].return_transition=="iris","Intro explicitly declares iris on return")
	check(director.movies[2].camera_kind=="tutorial_cinematic" and director.movies[2].return_transition=="none","Porky lesson returns without a circle")
	check(director.start_movie(2),"Tutorial starts normally")
	director.movies[2].finish_sequence(true)
	check(player.restart_fade_remaining==0,"Finishing or skipping an ordinary tutorial does not open iris")
	var example = director.movies[3]
	example.camera_kind = "camera_animation"; example.return_transition = "iris"
	check(director.start_movie(3),"Non-cinematic camera animation can be configured separately")
	example.finish_sequence(true)
	check(player.restart_fade_remaining>0 and player.restart_fade.iris_enabled and player.is_physics_processing(),"Camera animation explicitly requesting iris restores physics then opens circle")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame; paused = false
	print("Camera catalogue / independent role and return policy: ",failures," failures"); quit(failures)
