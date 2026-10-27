extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://frozen06_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level06.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var p = level.player; var movies = level.get_node("LevelCinematics")
	if movies.active_movie: movies.active_movie.finish_sequence(true)
	movies.set_process(false); level.get_node("Sam_41").set_physics_process(false)
	p.restart_fade_remaining = 0; p.restart_fade.set_amount(0); p.cinematic_controls_locked = false
	p.global_position = Vector3(120,1.3,-32); p.velocity = Vector3(0,-10,0); p.set_state(p.WolfState.FALL)
	for i in range(100):
		await physics_frame
		if p.water_motion.frozen: break
	var water = p.water_motion
	check(water.frozen and p.current_state==p.WolfState.FROZEN_FLOAT,"A real fall into native freezing water enters FREEZE1 rather than ordinary swimming")
	check(is_instance_valid(water.frozen_visual) and water.frozen_visual.visible and water.frozen_visual.animation_player.current_animation=="stand2","Original AGLACON1 block is attached and visible")
	check(p.animation_player.current_animation=="frozen_float" and not p.can_use_inventory(),"Native frozen pose holds and gameplay actions are blocked")
	var start = p.global_position
	Input.action_press("move_right"); Input.action_press("jump")
	for i in range(70): await physics_frame
	Input.action_release("move_right"); Input.action_release("jump")
	check(absf(p.global_position.x-start.x)<.1 and p.global_position.z<start.z-2,"Frozen motion ignores controls and follows the original current")
	check(absf(p.global_position.y-(-float(water.zone.min[1])*.01-1.05))<.03,"Frozen block rises to native105cm surface offset")
	check(water.frozen_time<20 and p.current_state==p.WolfState.FROZEN_FLOAT,"Frozen state does not use the short generic death timer")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,800)
		var view = Camera3D.new(); level.add_child(view)
		view.global_position = p.global_position+Vector3(4,3,5); view.look_at(p.global_position+Vector3.UP*.9); view.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level06_frozen_water.png")
		view.queue_free(); p.camera.make_current()
	water.frozen_time = 19.95
	for i in range(160): await physics_frame
	check(not water.frozen and not water.frozen_visual.visible and p.current_state!=p.WolfState.FROZEN_FLOAT,"20 second native timeout and iris restore checkpoint, clearing the ice prop")
	check(p.inventory.can_open(),"Gameplay/inventory resumes after frozen restart")
	# The same shared controller must still swim in ordinary water.
	var normal = level.get_node("LevelEnvironment").rules.water[0]
	normal.flags = int(normal.flags)&~0x1000000
	p.restart_fade_remaining = 0; p.restart_fade.set_amount(0)
	p.global_position = Vector3(120,-.95,-32); p.velocity = Vector3.ZERO; p.set_state(p.WolfState.FALL)
	for i in range(12): await physics_frame
	check(not water.frozen and p.current_state==p.WolfState.SWIM,"Unmarked water retains ordinary swimming")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Native cold water / FREEZE1 / ice block / current / restart / ordinary water: ",failures," failures")
	quit(failures)
