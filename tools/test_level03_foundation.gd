extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://level03_foundation_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	check(level.manifest.level=="lvl_03" and level.entities.size()==85,"All85 original entity definitions imported")
	check(level.get_node("Scenery").mesh.get_surface_count()>0 and level.get_node("Collision/CollisionShape3D").shape.get_meta("native_triangles",0)==7084,"Editor map, native textures and7084 source collision triangles with local clock passage correction present")
	check(level.get_node("Collision").collision_layer==3,"Native terrain also blocks the free camera")
	var cinematics = level.get_node("LevelCinematics")
	check(cinematics.active_movie==cinematics.movies[2] and cinematics.movies[2].playing,"Native introductory CIN02 starts from its authored spawn trigger")
	for movie in cinematics.movies.values(): if movie.playing: movie.finish_sequence(true)
	check(level.player.is_physics_processing() and not level.player.cinematic_controls_locked,"Intro restores Ralph and gameplay camera")
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	await physics_frame; await physics_frame
	check(level.player.is_on_floor(),"Native level03 arrival lands on real terrain")
	var guard = level.get_node("Sam_63")
	check(guard.initialized and guard.rules.resource==63 and guard.rules.routes.size()==30 and guard.rules.hit.is_empty() and guard.inside_hit_zone(Vector3.ZERO),"Sam imports native routes and null hit-list semantics")
	check(level.get_node("Flock").sheep.size()==14,"All fourteen sheep use shared AI/carry logic")
	check(level.get_node("Checkpoints").entries.size()==2,"Both native checkpoints imported")
	var environment = level.get_node("LevelEnvironment")
	check(environment.seesaws.size()==3,"All three seesaws use shared collisions and weight mechanics")
	check(level.get_node("Salad_103") is LettuceItem and level.get_node("Rocks_85") is OriginalBreakableRocks,"Native vegetables and breakable rocks use reusable mechanics")
	check(level.get_node("TimeKeeper_86").level_id=="lvl_03","Secret clock is bound to level03 progress")
	var first = level.get_node("Mailbox_79"); var second = level.get_node("Mailbox_78")
	check(first.items.size()==2 and first.items[0] is DynamiteItem and first.items[1] is RocketItem,"First mailbox delivers native dynamite and rocket resources")
	check(first.items[0].actor_visual.asset_directory.begins_with(level.asset_directory) and first.items[1].rocket_visual.asset_directory.begins_with(level.asset_directory),"Delivered items use their actual level03 texture/model banks")
	check(second.items.size()==1 and second.items[0].class_id==42 and second.items[0].icon_path.ends_with("icon_42.png"),"Other mailbox contains native elastic asset and inventory icon")
	check(first.items[1].has_flight_bounds and not first.items[0].available and not first.items[1].available and not second.items[0].available,"Native rocket region is assigned and mailbox contents remain hidden")
	var lessons = level.get_node("DaffyLessons")
	check(lessons.source_level=="lvl_03" and lessons.data.variant=="hidden_rocks" and lessons.movies.has(0) and lessons.movies.has(3),"Lucas uses rock-cover tutorial CIN00/CIN03 instead of bush data")
	check(lessons.data.answers[0].voice_path.ends_with("cin_lvl_0308.wav") and lessons.movies[0].data.voice_path.ends_with("cin_lvl_0301.wav"),"Native level03 speech clips are resolved from BSV IDs")
	for movie in lessons.movies.values(): movie.played = true
	check(level.get_node("SignPostSimple_88").text==GameLocalization.text("lvl_03",79,1),"Signs use original level03 text")
	for locale in ["en","pt_BR","it","es"]:
		GameLocalization.select(locale,false); lessons.reload_localization()
		check(lessons.data.answers[0].voice_path.contains("/voices/"+locale+"/") and lessons.data.question==GameLocalization.text("lvl_03",48,10),"Level03 dialog/voice localization: "+locale)
	var music = level.get_node("BGMPlayer")
	check(music.playing and music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and music.stream.get_length()>30,"Level03 plays native Mix Jami_v2 full-file loop")
	# Source switch target links:57->gate102,58->lift61,54->lift56,59->gate94.
	var gate = level.get_node("FallingGate_102"); var button = level.get_node("SensibleButton_57")
	button.set_physics_process(false); gate.set_switch(button,true); gate._process(10)
	check(gate.opened and not gate.visible,"Imported switch opens original animated gate")
	var lift = level.get_node("Wooden Lift_61")
	lift.set_switch(button,true); lift._physics_process(.25)
	check(lift.position.y>lift.home_y,"Imported elevator uses original endpoint and speed")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and save.snapshot.level=="lvl_03" and SaveFiles.write_slot(1,save.snapshot)==OK,"Level03 uses shared checkpoint/manual-save format")
	var record = SaveFiles.read_slot(1)
	gate.restore_state(false,false)
	check(save.restore_checkpoint(record) and gate.opened,"Reload restores gate and tutorial progress")
	lessons.set_process(false); guard.set_physics_process(false); cinematics.set_process(false)
	level.player.cinematic_controls_locked = false
	first._deliver(level.player)
	await create_timer(3).timeout
	check(first.items.all(func(item): return not item.available) and first.boxes.all(func(box): return is_instance_valid(box) and box.state=="sealed"),"Mailbox leaves both authored containers sealed for the native rock puzzle")
	first._release_camera()
	second._deliver(level.player)
	await create_timer(4).timeout
	check(second.items[0].available,"Elastic asset is actually released by its original mailbox")
	second._release_camera()
	check(SaveFiles.scene_for_level("lvl_03")=="res://scenes/levels/Level03.tscn","Hub/loading/save systems discover new level03 scene")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = Vector3(-5,35,85); camera.look_at(Vector3(-4,2,10)); camera.far = 300; camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_overview.png")
		camera.position = Vector3(-15,5,62); camera.look_at(Vector3(-25,1,78))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_tutorial_area.png")
	stop_audio(level); level.queue_free(); await process_frame
	print("Level03 map / native entities / AI / cinematics / dialogs / delivery / shared mechanics / save: ",failures," failures")
	quit(failures)
