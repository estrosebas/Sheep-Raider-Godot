extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level07_foundation_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level07.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(45): await physics_frame
	check(level.entities.size()==75 and level.manifest.level=="lvl_07","All75 native entities imported")
	check(level.get_node("Scenery").mesh.get_surface_count()==10,"All10 native scenery surfaces rendered (11 texture pages including models)")
	check(level.get_node("Collision/CollisionShape3D").shape.get_faces().size()==4617*3,"Native4617 collision triangles retained")
	var cine = level.get_node("LevelCinematics")
	check(cine.intro_id==0 and cine.movies.size()==1,"Original entry movie classified")
	for i in range(150):
		if cine.movies[0].playing: break
		await physics_frame
	check(cine.movies[0].playing and cine.movies[0].camera.current,"Entry trigger starts native cinematic")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	for i in range(30): await physics_frame
	check(level.player.is_on_floor(),"Original spawn rests on native ground")
	check(level.get_node("Flock").sheep.size()==10 and level.get_node("Sam_48").initialized,"Sam and10 sheep use shared controllers")
	check(not level.has_node("DaffyLessons"),"No invented Lucas lessons in a map without Lucas")
	check(level.get_node("Checkpoints").entries.size()==3,"Three native checkpoints")
	check(level.get_node("Mailbox_60").items.size()==1 and level.get_node("Mailbox_60").items[0] is SheepCostumeItem,"Upper mailbox delivers usable sheep costume")
	check(level.get_node("Mailbox_59").items.size()==1 and level.get_node("Mailbox_59").items[0].class_id==61,"First mailbox delivers detector preview")
	check(level.get_node("MineDetector_72") is MineDetectorItem and not level.get_node("MineDetector_72").get_meta("prototype_only",true),"Detector uses native scan controller")
	for id in [73,74,75,76]: check(level.get_node("DefusableMine_%d"%id) is OriginalDefusableMine,"Mine uses native rhythm controller")
	for id in [36,37,39,42]: check(level.get_node("SensibleButton_%d"%id).switch_camera!=null,"Original gate button camera imported")
	check(level.get_node("TimeKeeper_62").level_id=="lvl_07" and level.get_node("Goal_85").level_id=="lvl_07","Clock and goal connected to new-level progress")
	check(level.get_node("CameraZones").data.cameras.size()==11,"Eleven optional native camera restrictions")
	check(level.get_node("BGMPlayer").playing,"Original level music playing")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and SaveFiles.write_slot(1,save.snapshot)==OK,"New level checkpoint can be saved")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = Vector3(295,290,-260); camera.look_at(Vector3(240,250,-210)); camera.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level07_overview.png")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level07 native foundation / intro / reusable mechanics / save: ",failures," failures")
	quit(failures)
