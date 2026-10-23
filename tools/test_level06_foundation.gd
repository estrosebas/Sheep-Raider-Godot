extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level06_foundation_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level06.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	check(level.manifest.level=="lvl_06" and level.entities.size()==67,"All67 native Lv06 entities imported")
	check(level.get_node("Scenery").mesh.get_surface_count()>0 and level.get_node("Collision/CollisionShape3D").shape.get_faces().size()==5882*3,"Textured editor mesh and native5882 collision triangles")
	check(level.get_node("WorldEnvironment").environment.background_color.to_html(false)=="283868","Native blue backdrop from WAR header")
	var cine = level.get_node("LevelCinematics")
	check(cine.intro_id==0 and cine.movies.size()==2 and cine.movies.has(2),"Native manager owns CIN0/2; Lucas lesson remains reserved for thaw controller")
	for i in range(150):
		if cine.movies[0].playing: break
		await physics_frame
	check(cine.movies[0].playing and cine.movies[0].camera.is_current(),"Native entry volume actually starts the original intro camera")
	var lesson = GameLocalization.load_data("res://assets/levels/lvl_06/cinematics/sequence_1.json")
	check(lesson.voice_id==38 and lesson.has("text") and ResourceLoader.exists(lesson.voice_path),"Military tutorial includes native voice38 and localized text")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	for i in range(20): await physics_frame
	check(level.player.is_on_floor(),"Native player spawn lands on actual collision")
	check(level.get_node("Flock").sheep.size()==11 and level.get_node("Sam_41").initialized,"Sam and11 sheep share gameplay controllers")
	check(level.get_node("Sam_41").visual.rig.animations.has("win_after_hit"),"Sam includes corrected HIT recovery pose")
	check(level.get_node("Checkpoints").entries.size()==6,"Six native checkpoint entries")
	check(level.get_node("Catapult_37").bucket!=null and level.get_node("Catapult_37").definition.max_throw_offset==20,"Catapult uses native20m power adjustment range")
	check(level.get_node("SmallRock_58").is_in_group("carryable_rocks"),"Native small rock is carryable")
	check(level.get_node("LevelEnvironment").seesaws.size()==2,"Both seesaws use shared moving collision")
	check(level.get_node("Telescope_59") is OriginalTelescope,"Native telescope uses existing viewing controller")
	check(level.get_node("TimeKeeper_63").level_id=="lvl_06" and level.get_node("Goal_90").level_id=="lvl_06","Clock and goal use level06 progress")
	check(level.get_node("Mailbox_53").items.size()==1 and level.get_node("Mailbox_53").items[0].class_id==58,"First mailbox delivers original hairdryer preview")
	check(level.get_node("Mailbox_54").items.size()==1 and level.get_node("Mailbox_54").items[0] is FluteItem,"Second mailbox delivers functioning shared flute")
	check(level.get_node("HairDryer_74").get_meta("prototype_only",false),"New hairdryer is explicitly pending its exclusive heating mechanic")
	check(level.get_node("IceCube_56").idle_clip.is_empty() and level.get_node("IceCube_56").animation_player.current_animation=="stand2","Ice preview retains native frozen STAND2 instead of melting on spawn")
	check(level.get_node("DaffyMilitary_55").idle_clip.is_empty(),"Lucas retains his original frozen pose until thaw mechanics are implemented")
	check(level.get_node("LevelEnvironment").rules.water.size()==5,"Five native water regions use shared swimming")
	check(level.get_node("BGMPlayer").stream!=null and level.get_node("BGMPlayer").playing,"Original Luney_v2 music loaded")
	var overlay = GameLocalization.load_data("res://assets/levels/lvl_06/data/exclusive_mechanics.json")
	check(overlay.mines.size()==11 and overlay.daffy.choices.size()==3 and not overlay.pending_classes.any(func(kind): return int(kind)==64),"Native mine parameters and dialogue choices are audited; mines have a reusable controller")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and SaveFiles.write_slot(1,save.snapshot)==OK,"New level uses shared manual checkpoint save schema")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var view = Camera3D.new(); level.add_child(view)
		view.position = Vector3(55,50,35); view.look_at(Vector3(35,2,-20)); view.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level06_overview.png")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level06 foundation / materials / actors / native movies / reusable mechanics / exclusive audit: ",failures," failures")
	quit(failures)
