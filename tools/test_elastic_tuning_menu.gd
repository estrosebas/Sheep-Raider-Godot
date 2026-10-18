extends SceneTree
const Settings = preload("res://scripts/testing/elastic_tuning_settings.gd")
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func key(code: Key):
	var event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); await process_frame
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://elastic_tuning_test_%d"%Time.get_ticks_usec()
	var config_dir = SaveFiles.directory
	DirAccess.make_dir_recursive_absolute(config_dir); Settings.path = config_dir+"/elastic_tuning.cfg"
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await frames(15)
	var actor = lab.player; actor.restart_fade_remaining = 0
	# Development panel is archived/commented out of normal Ralph startup.
	var archived_menu = preload("res://scripts/testing/elastic_tuning_menu.gd").new()
	archived_menu.name = "ElasticTuning"; actor.add_child(archived_menu)
	var menu = actor.get_node("ElasticTuning")
	await key(KEY_DELETE)
	check(menu.opened and paused and not actor.mouse_captured and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Delete opens interactive tuning, pauses simulation and releases mouse")
	menu.spins.max_length.value = 8; menu.spins.return_speed.value = 9; menu.spins.minimum_launch_charge.value = 90
	menu.apply_values()
	check(lab.get_node("Elastic").controller.max_length==8 and lab.get_node("ElasticYoyo").controller.return_speed==9 and lab.get_node("Elastic").controller.minimum_launch_charge==.9,"Spin controls apply correctly to current level and convert percentages")
	var dynamite = lab.get_node("Item_2"); dynamite.ignite(Vector3(5,0,5))
	var fuse = dynamite.fuse
	menu.manual_running = true; menu.manual_elapsed = 0
	for i in range(15): await process_frame
	check(dynamite.fuse==fuse and menu.manual_elapsed==0,"Editing pauses actual bomb fuse and gameplay stopwatch")
	menu.save_values(); check(FileAccess.file_exists(Settings.path),"Tuning persists in isolated config, not checkpoint")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,1000)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/elastic_tuning_menu.png")
	await key(KEY_DELETE)
	check(not menu.opened and not paused and actor.mouse_captured and menu.monitor.visible,"Delete closes, resumes simulation and shows optional measurement overlay")
	await frames(10)
	check(dynamite.fuse<fuse and menu.manual_elapsed>0,"Fuse and clock resume only during gameplay")
	await key(KEY_DELETE); menu.populate(Settings.native_values(menu.controller)); menu.apply_values()
	check(menu.controller.max_length==11.5 and menu.controller.return_speed==6.14 and menu.controller.minimum_launch_charge==0,"Original preset restores native elastic constants")
	menu.populate(Settings.level_values(menu.controller)); menu.apply_values()
	check(menu.controller.two_anchor_max_length==9.5 and menu.controller.minimum_launch_charge==1,"Level preset restores current PC tuning")
	await key(KEY_ESCAPE)
	check(not menu.opened and not paused,"Escape closes tuning without opening pause menu")
	stop_audio(lab); lab.queue_free(); await process_frame
	var next = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(next); current_scene = next
	await frames(10)
	check(next.get_node("Elastic").controller.max_length==8 and next.get_node("ElasticYoyo").controller.return_speed==9,"Saved tuning automatically reloads on next level entry")
	stop_audio(next); next.queue_free(); await process_frame
	Settings.path = config_dir+"/unused.cfg" # Native level measurements below must not use our saved test knobs.
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(25)
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	actor = level.player; actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	var elastic = level.get_node("elastic_104").controller; var tree = level.get_node("ElasticTree_100")
	dynamite = level.get_node("Dynamite_107")
	check(dynamite.fuse_seconds==5 and int(level.entities.filter(func(e): return int(e.res)==107)[0].props["0x0"])==5000,"Original Level03 bomb fuse is WAR5000ms, not8seconds")
	elastic.tie_first(tree,actor)
	var bottom = tree.global_position+Vector3(1.6,0,-.5); bottom.y = 5
	var ray = PhysicsRayQueryParameters3D.create(bottom,bottom-Vector3.UP*15,1)
	ray.exclude = [actor.get_rid()]
	var ground = level.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not ground.is_empty(),"Native bomb placement zone has real lower ground")
	if ground.is_empty(): stop_audio(level); level.queue_free(); await process_frame; quit(failures); return
	actor.global_position = ground.position+Vector3.UP*.06; actor.velocity = Vector3.DOWN
	actor.set_state(actor.WolfState.FALL)
	for i in range(100):
		await physics_frame
		if actor.is_on_floor(): break
	actor.inventory.add_item({"id":dynamite.item_id,"class_id":2,"label":dynamite.item_label,"icon":dynamite.icon_path,"kept":false},dynamite)
	var planted = dynamite.use_item(actor)
	check(actor.is_on_floor() and planted.success,"Actual PUT1A/PUT1B places a bomb while tethered below the anchor")
	var return_started = false; var fuse_on_return = -1.0; var returned_alive = false; var time = 0.0
	for i in range(280):
		await physics_frame; time += 1.0/60
		if not elastic.retract.is_empty():
			if not return_started: fuse_on_return = dynamite.fuse
			return_started = true
		if return_started and elastic.retract.is_empty() and actor.is_on_floor() and actor.ground_drop()<.15 and actor.global_position.y>tree.global_position.y-.6:
			returned_alive = actor.current_state not in [actor.WolfState.PIT_FALL,actor.WolfState.BLAST_DEATH,actor.WolfState.SAM_DEATH]
			break
	print("Native bomb return: startFuse=",fuse_on_return," time=",time," remainingFuse=",dynamite.fuse," position=",actor.global_position," phase=",elastic.mode)
	check(return_started and fuse_on_return>4,"Original interacting branch returns immediately after placement instead of waiting for max length")
	check(returned_alive and time<5 and dynamite.fuse>0,"Native6.14m/s return reaches upper ground alive before original5s fuse expires")
	await frames(2)
	check(not elastic.last_measurement.is_empty() and elastic.last_measurement.elapsed>elastic.last_measurement["return"],"Automatic trip measurement includes descent, placement and actual upper-ground landing")
	var archived_telemetry = preload("res://scripts/testing/elastic_tuning_menu.gd").new()
	archived_telemetry.name = "ElasticTuning"; actor.add_child(archived_telemetry)
	archived_telemetry.controller = elastic; archived_telemetry.refresh_telemetry()
	check(archived_telemetry.telemetry.text.contains("Mecha:"),"Telemetry reports actual live bomb fuse")
	stop_audio(level); level.queue_free(); await process_frame
	print("Delete tuning / pause / persistence / native interaction return / fuse: ",failures," failures")
	quit(failures)
