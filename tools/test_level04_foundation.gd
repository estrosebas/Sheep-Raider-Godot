extends SceneTree

var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level04_foundation_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	check(level.manifest.level=="lvl_04" and level.entities.size()==72,"All72 original entities imported")
	var shape: ConcavePolygonShape3D = level.get_node("Collision/CollisionShape3D").shape
	check(level.get_node("Scenery").mesh.get_surface_count()>0 and shape.get_faces().size()==6510*3,"Editor-visible textured map and6510 native collision triangles")
	check(level.get_node("Collision").collision_layer==3,"Terrain also blocks free camera")
	var cinematics = level.get_node("LevelCinematics")
	check(cinematics.intro_id==1 and cinematics.movies.size()==1 and cinematics.movies.has(1),"Native CIN1 entry is separate from Elf CIN2")
	check(cinematics.active_movie==cinematics.movies[1] and cinematics.movies[1].playing,"Authored entry activation starts CIN1")
	check(not level.get_node("DaffyLessons").calling.playing,"Native WAIT/CIN entry never forces Elf flute tune37")
	for movie in cinematics.movies.values(): if movie.playing: movie.finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	await physics_frame; await physics_frame
	check(level.player.is_on_floor(),"Ralph arrives on actual level04 terrain")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_spawn_camera.png")
	var guard = level.get_node("Sam_42")
	check(guard.initialized and guard.rules.resource==42 and guard.rules.mode==16384,"Sam reads original04 behavior flags and zones")
	check(level.get_node("Flock").sheep.size()==13,"All13 sheep use reusable AI/carry logic")
	check(not level.has_node("ObjectManager_38") and level.get_node("HeapOfLeaf_72").visual==null,"Invisible source managers/particle emitters never render marker meshes")
	check(level.get_node("bull_60").clip=="sleep1" and level.get_node("bull_60").grounded,"Bull starts grounded in native sleeping pose")
	check(level.get_node("Checkpoints").entries.size()==4,"Four native checkpoints")
	var environment = level.get_node("LevelEnvironment")
	check(environment.rules.water.size()==4 and environment.seesaws.is_empty() and environment.fish.is_empty(),"Normal swimming volumes have no borrowed02 piranha hazards or invented seesaws")
	check(environment.water_at(Vector3(-50,-2,0)).size()>0,"Level04 water provider serves shared swimming controller")
	var lessons = level.get_node("DaffyLessons")
	check(lessons.actor_prefix=="DaffyElf" and lessons.movies.has(2) and lessons.data.answers.size()==2,"Elf conversation and original CIN2")
	check(lessons.movie.data.voice_path.ends_with("cinfl_lvl0401.wav"),"Elf tutorial uses original BSV52 voice")
	for locale in ["en","pt_BR","it","es"]:
		GameLocalization.select(locale,false); lessons.reload_localization()
		check(lessons.data.answers[0].voice_path.contains("/voices/"+locale+"/") and lessons.data.question==GameLocalization.text("lvl_04",56,1),"Original text and voice localization: "+locale)
	level.player.set_physics_process(false)
	level.player.global_position = Vector3(18,0,17)
	lessons._process(.3)
	check(lessons.active_movie==lessons.movie and lessons.movie.playing,"Entering native Elf zone starts localized CIN2")
	lessons._process(.016)
	check(not lessons.calling.playing and lessons.movie.voice_player.playing,"Elf CIN2 plays original voice52 without adding flute37")
	if lessons.movie.playing: lessons.movie.finish_sequence(true)
	check(lessons.intro_finished and lessons.active_movie==null,"Elf tutorial hands control back for conversation")
	level.player.restart_fade_remaining = 0
	lessons._process(.016)
	check(lessons.calling.playing and lessons.calling_started,"WATCH starts original positional tune37 only after the tutorial")
	lessons.calling.stop(); lessons._process(.016)
	check(not lessons.calling.playing,"WATCH does not replay an ended soundHandle every frame")
	level.player.set_physics_process(true)
	lessons.set_process(false)
	check(level.get_node("SignPostSimple_68").text==GameLocalization.text("lvl_04",79,0),"Swimming sign uses original localized text")
	check(level.get_node("TimeKeeper_67").level_id=="lvl_04" and level.get_node("Goal_99").level_id=="lvl_04","Clock and goal are linked to persistent04 progress")
	var first = level.get_node("Mailbox_56"); var second = level.get_node("Mailbox_57")
	check(first.items.size()==1 and first.items[0] is GameItem and first.items[0].class_id==41,"First mailbox delivers actual flute pickup")
	check(second.items.size()==1 and second.items[0] is FanItem,"Second mailbox delivers reusable fan")
	check(not first.items[0].available and not second.items[0].available,"Mailbox items start hidden")
	check(level.get_node("HiddenRocks_62") is OriginalHiddenRock and level.get_node("Bush_70").is_in_group("world_interactables"),"Reusable hiding objects retain native placement")
	var stone = level.get_node("TriggedStone_65"); var button = level.get_node("SensibleButton_39")
	check(button.definition.targets.size()==1 and int(button.definition.targets[0])==65 and stone.definition.trigger_delay_ms==1000,"Button39 is wired to native timed rock65")
	stone.set_physics_process(false)
	stone.set_switch(button,true); stone._physics_process(.5)
	check(stone.state==stone.State.ARMED,"Rock preserves its original delay")
	stone._physics_process(.51); stone._physics_process(1); stone._physics_process(.7)
	check(stone.state==stone.State.REST,"Rock finishes FALL1 and EXPLOD1 and returns to rest")
	stone.reset_to_home(); stone.set_physics_process(true)
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and SaveFiles.write_slot(1,save.snapshot)==OK,"04 uses reusable checkpoint and manual slot format")
	check(save.restore_checkpoint(SaveFiles.read_slot(1)),"04 checkpoint restores with Elf conversation")
	lessons.set_process(false); guard.set_physics_process(false); cinematics.set_process(false)
	level.player.cinematic_controls_locked = false
	first._deliver(level.player)
	await create_timer(5).timeout
	check(first.items[0].available and first.boxes.all(func(box): return not is_instance_valid(box) or box.state=="open"),"Flute delivery falls, opens and releases its collectible")
	first._release_camera()
	level.player.inventory.animate_selection = false
	check(first.items[0].collect(level.player.inventory),"Flute uses original pickup action")
	level.player.item_actions.set_process(false)
	for i in range(3):
		if level.player.item_actions.busy: level.player.item_actions._process(10)
	check(level.player.inventory.state.items.has(first.items[0].item_id),"Flute pickup enters inventory with its original icon")
	first.items[0].equip_to(level.player); first.items[0]._physics_process(.016)
	check(first.items[0].holder==level.player,"Imported flute can be equipped by shared item controller")
	first.items[0].store(); level.player.item_actions.set_process(true)
	second._deliver(level.player)
	await create_timer(5).timeout
	check(second.items[0].available,"Fan delivery releases its collectible")
	second._release_camera()
	check(SaveFiles.scene_for_level("lvl_04")=="res://scenes/levels/Level04.tscn","Hub/loading/save systems discover04")
	var music = level.get_node("BGMPlayer")
	check(music.playing and music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"04 uses original music loop")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); level.add_child(camera); camera.far = 350; camera.current = true
		camera.position = Vector3(25,34,25); camera.look_at(Vector3(-10,0,-25))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_overview.png")
		camera.position = Vector3(20,4,12); camera.look_at(Vector3(15,0,15.27))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_entry.png")
	stop_audio(level); level.queue_free(); await process_frame
	print("Level04 map / native entities / swimming / AI / cinematics / i18n / mailboxes / triggered stone / save: ",failures," failures")
	quit(failures)
