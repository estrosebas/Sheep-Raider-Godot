extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://snow_test_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level07.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var player = level.player
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false); player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false
	player.set_physics_process(false)
	for npc in get_nodes_in_group("sam_guards")+get_nodes_in_group("sheep_targets"): npc.set_physics_process(false)
	var field = level.get_node("GroundMine_61"); field.set_physics_process(false)
	var cube = level.get_node("SlidingIceCube_43")
	check(cube is OriginalSlidingIce and get_nodes_in_group("ice_cubes").size()==6,"Six moving cube controllers installed")
	check(cube.allows_direction(Vector3.RIGHT) and not cube.allows_direction(Vector3.FORWARD),"Cube43 respects native X-only push axis")
	# Isolated real physics floor/wall checks collision, bounce and cargo transport.
	var floor = StaticBody3D.new(); var floor_shape = CollisionShape3D.new(); floor_shape.shape = BoxShape3D.new(); floor_shape.shape.size = Vector3(30,1,30); floor.position = Vector3(0,99.5,0); floor.add_child(floor_shape); level.add_child(floor)
	var wall = StaticBody3D.new(); var wall_shape = CollisionShape3D.new(); wall_shape.shape = BoxShape3D.new(); wall_shape.shape.size = Vector3(1,8,12); wall.position = Vector3(5,104,0); wall.add_child(wall_shape); level.add_child(wall)
	cube.definition.zones = []; cube.global_position = Vector3(0,100,0); cube.home = cube.global_position
	player.global_position = Vector3(0,101.67,0)
	var mine = level.get_node("DefusableMine_73"); mine.set_physics_process(false); mine.available = true; mine.holder = null; mine.show(); mine.global_position = Vector3(.2,101.67,0)
	cube.start_slide(Vector3.RIGHT)
	for i in range(15): await physics_frame
	check(cube.global_position.x>1.5 and absf(player.global_position.x-cube.global_position.x)<.1,"Real sliding cube carries Ralph without duplicate platform movement")
	check(absf(mine.global_position.x-cube.global_position.x-.2)<.1,"Mine cargo follows the moving cube")
	var furthest = cube.global_position.x
	for i in range(100):
		await physics_frame
		furthest = maxf(furthest,cube.global_position.x)
	check(cube.bounced and cube.speed==0 and cube.hit_audio.stream!=null,"Cube hits wall, reverses once, brakes and plays native impact")
	check(furthest-cube.global_position.x>.45 and furthest-cube.global_position.x<.65,"Short rebound leaves enough space for Ralph (45..65cm)")
	player.global_position = Vector3(4.25,100.02,2.5); player.set_state(player.WolfState.IDLE)
	player.ground_distance = 0; player.last_ground_y = 100; player.jump_origin_y = null
	for i in range(75):
		level.get_node("IceAccess")._physics_process(1.0/60)
		player.velocity = Vector3(0,-2,-2); player.move_and_slide()
		await physics_frame
	check(player.global_position.z<.3 and player.is_on_floor(),"Ralph actually walks into the gap between rebound cube and wall")
	check(cube.can_interact(player) and cube.interact(player),"Rebound leaves rear side usable to push the cube back")
	player.item_actions.cancel(); player.global_position = Vector3(10,100,10)
	# Hitting an authored zone endpoint must rebound even without a wall.
	cube.global_position = Vector3(0,100,0); cube.velocity = Vector3.ZERO
	cube.definition.zones = [{"min":[-1000,-11000,-1000],"max":[200,-9000,1000]}]
	cube.start_slide(Vector3.RIGHT); var endpoint = 0.0
	for i in range(110):
		await physics_frame; endpoint = maxf(endpoint,cube.global_position.x)
	check(cube.bounced and cube.speed==0 and endpoint-cube.global_position.x>.45 and endpoint-cube.global_position.x<.7,"Native zone limit also rebounds once and leaves clearance")
	cube.definition.zones = []
	cube.set_physics_process(false)

	# A moving cube reaches a live wave and arms the mine; the cube survives blast.
	mine.set_phase(mine.State.ARMED); mine.clock = 2; mine.mine_definition.phase_seconds = 0
	mine.global_position = Vector3(0,100,0); cube.global_position = Vector3(.5,100,0)
	mine.item_step(.001)
	check(mine.state==mine.State.COUNTDOWN,"Ice cube triggers the mine wave")
	cube.on_blast(mine.global_position)
	check(cube.visible,"Explosion preserves the sliding cube, as in the native handler")
	mine.global_position = Vector3(20,100,20)
	# Native ray through safe/hazard boxes, then actual detector raising/scanning.
	var old_definition = field.definition.duplicate(true)
	field.definition.zones = [{"min":[-100,-11000,100],"max":[100,-9000,400]}]
	field.definition.safe_zones = [{"min":[-100,-11000,100],"max":[100,-9000,150]}]
	check(is_equal_approx(field.distance_to_hazard(Vector3(0,100,0),Vector3.FORWARD,3),1.5),"Detector ray skips safe box and finds hazard boundary at1.5m")
	var detector = level.get_node("MineDetector_72")
	check(is_equal_approx(detector.scan(Vector3(0,100,0),Vector3.FORWARD),1.5),"Usable detector reads buried region")
	check(is_inf(detector.scan(Vector3(0,100,0),Vector3.BACK)),"Detector ignores hazards behind Ralph")
	player.set_state(player.WolfState.IDLE)
	player.global_position = Vector3(-5,100.01,0); player.velocity = Vector3.DOWN; player.move_and_slide()
	player.ground_distance = 0; player.last_ground_y = player.global_position.y; player.jump_origin_y = null
	detector.equip_to(player)
	check(detector.use_item(player).success,"Detector starts with equipped item on floor")
	for i in range(65): detector.step_player(player,.016)
	detector.item_step(.016)
	check(detector.phase=="scanning" and detector.sound.playing and player.animation_player.current_animation=="detector_idle","Native raising leads to scan pose, prop animation and audio258")
	detector.use_item(player)
	for i in range(100): detector.step_player(player,.016)
	check(detector.phase=="idle" and not detector.active and not detector.sound.playing,"Detector lowers and stops loop")
	detector.store(); field.definition = old_definition
	# Real mine explosion dispatch breaks the native ice panel.
	var ground = level.get_node("IceGround_35"); ground.set_physics_process(false)
	player.global_position = Vector3(-12,100,0)
	mine.global_position = ground.global_position; mine.state = mine.State.SAFE; mine.explode()
	check(ground.breaking,"Actual mine explosion dispatch starts original ice-break animation")
	ground._physics_process(20); await physics_frame
	check(ground.broken and ground.body.get_child(0).disabled,"Broken ice disables its collider")
	ground.reset_ground(); await physics_frame
	check(not ground.broken and not ground.body.get_child(0).disabled,"Native ice reset restores collision")
	var ball = level.get_node("Snowball_63")
	check(ball is OriginalSnowball and is_equal_approx(ball.radius,.5),"Snowball starts at original quarter scale")

	# Real growth while pushing on the fixture floor; no time-only growth at rest.
	ball.global_position = Vector3(-8,100.5,-6); ball.definition.push_zones = []; ball.roll_seconds = 0; ball.apply_size(.25)
	ball.set_physics_process(false); player.global_position = Vector3(-9,100.01,-6); player.set_state(player.WolfState.IDLE)
	player.ground_distance = 0; player.last_ground_y = 100; player.jump_origin_y = null
	player.velocity = Vector3.DOWN; player.move_and_slide()
	ball.pushing_actor = player; player.push_target = ball; ball.push_direction = Vector3.RIGHT
	ball.add_collision_exception_with(player); player.add_collision_exception_with(ball)
	Input.action_press("action")
	for i in range(120): ball.step_pusher(player,1.0/60)
	Input.action_release("action"); ball.stop_push(false)
	check(ball.roll_seconds>1 and ball.ball_scale>.27,"Snowball grows from actual rolling displacement with ground/clearance checks")
	ball.restore_world_state({"position":[-7,100.8,0],"scale":.4,"roll_seconds":6})
	ball.reset_to_home()
	check(is_equal_approx(ball.ball_scale,.4) and is_equal_approx(ball.roll_seconds,6),"Snowball death reset preserves growth")
	var snow = level.get_node("SnowyGround_31"); snow.set_physics_process(false)
	ball.set_physics_process(false); ball.global_position = snow.global_position+Vector3(0,snow.bounds.end.y+ball.radius,0)
	snow._physics_process(.016); await physics_frame
	check(snow.breaking and snow.body.get_child(0).disabled,"Heavy snowball collapses snow crust and releases collision")
	var prints = level.get_node("SnowEffects")
	for i in range(140): prints.stamp(Vector3(i*.1,100,0),Vector3.FORWARD)
	check(prints.prints.size()==128 and prints.cursor==140 and not prints.prints[0].no_depth_test,"Footprints use original alternating sprites, depth testing and128-slot ring")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(save.snapshot.world.controllers.has("SlidingIceCube_43") and save.snapshot.world.controllers.has("Snowball_63") and save.snapshot.world.controllers.has("IceGround_35"),"Checkpoint captures new mechanics state")

	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var spawn = level.manifest.spawn.pos
		player.global_position = GameSpace.from_export(Vector3(spawn[0],spawn[1],spawn[2]))
		player.global_position.y = 251.6
		player.set_state(player.WolfState.IDLE); player.play_anim("detector_idle"); player.animation_player.seek(.5,true)
		player.apply_legacy_reaction_pose()
		detector.equip_to(player); detector.phase = "scanning"; detector.active = true; detector.reading = .5
		detector.original_visual.sample_animation("detec1",.5); detector.sync_held_pose()
		for i in range(8): prints.stamp(player.global_position+Vector3(-2+i*.3,.02,2),Vector3.FORWARD)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.global_position = player.global_position+Vector3(5,4,6); camera.look_at(player.global_position+Vector3.UP); camera.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level07_detector.png")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level07 snow / ice / cargo / detector / mines / breakage / save: ",failures," failures")
	quit(failures)
