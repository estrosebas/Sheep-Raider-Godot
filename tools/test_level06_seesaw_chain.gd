extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://chain06_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level06.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var player = level.player
	var director = level.get_node("LevelCinematics")
	if director.active_movie: director.active_movie.finish_sequence(true)
	director.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false
	player.set_physics_process(false); player.set_process(false)
	level.get_node("Sam_41").set_physics_process(false)
	var env = level.get_node("LevelEnvironment")
	var board = env.seesaws[1]; var balance = env.seesaws[0]
	var sheep = level.get_node("Flock").sheep[0]
	for other in level.get_node("Flock").sheep: other.set_physics_process(false)
	sheep.flock = null
	var rock = level.get_node("Rock_38")
	# The first board is a launcher, not a SLIDE board. A sheep waiting on it
	# must not inherit sideways velocity from the rotating Godot platform.
	player.global_position = Vector3(60,3,-40)
	rock.set_physics_process(false)
	sheep.global_position = board.global_position+Vector3(-3,0,0)
	sheep.global_position.y = board.sheep_surface_height(sheep)
	sheep.rest_on_seesaw(board); sheep.velocity = Vector3.ZERO; sheep.set_physics_process(true)
	var waiting = Vector2(sheep.global_position.x,sheep.global_position.z)
	for i in range(120): await physics_frame
	check(Vector2(sheep.global_position.x,sheep.global_position.z).distance_to(waiting)<.05 and sheep.seesaw_slide_time==0,"First seesaw preserves the waiting sheep's horizontal position; sliding only belongs to the second")
	sheep.set_physics_process(false)
	var launched = 0
	for offset in [-3.7,-3.3,-3.0]:
		player.global_position = Vector3(60,3,-40)
		if is_instance_valid(env.launch_camera): env.launch_camera.close()
		env.clear_player_launch()
		board.tilt = 0; board.tilt_velocity = 0; board.rotation.z = 0; board.contact_ids.clear(); board.launch_count = 0; board.timers = [0.0,0.0]
		balance.tilt = 0; balance.tilt_velocity = 0; balance.rotation.z = 0; balance.tipping_moment = 0; balance.contact_ids.clear()
		sheep.dead = false; sheep.clear_seesaw_launch(); sheep.seesaw_support = null; sheep.velocity = Vector3.ZERO
		sheep.global_position = board.global_position+Vector3(offset,2,0)
		sheep.last_floor_y = sheep.global_position.y; sheep.set_physics_process(true)
		rock.set_physics_process(false); rock.seesaw_support = null; rock.arc.clear(); rock.landed_speed = 0
		rock.global_position = Vector3(77.5,17.15,-43.94); rock.velocity = Vector3.ZERO; rock.fall_time = 0
		for i in range(55): await physics_frame
		rock.process_physics_priority = -50 if offset==-3.3 else 50
		rock.set_physics_process(true)
		var flew = false; var top = sheep.global_position.y; var reached = false
		for i in range(400):
			await physics_frame
			flew = flew or not sheep.seesaw_arc.is_empty()
			top = maxf(top,sheep.global_position.y)
			reached = reached or (sheep.global_position.x>93 and sheep.global_position.y>14)
		check(flew and reached,"First rock drop must launch sheep from offset%f to the next board; final=%s high=%f"%[offset,sheep.global_position,top])
		if flew: launched += 1
		check(not is_instance_valid(env.launch_camera),"A sheep-only launch must release its shot without requiring a Ralph launch")
		print("trial=",offset," sheep=",sheep.global_position," reached=",reached," tilt=",balance.tilt," dead=",sheep.dead," floor=",sheep.is_on_floor())
		check(sheep.dead or sheep.global_position.y<balance.global_position.y-2,"Without Ralph the sheep must slide off and fall, not remain perched at the board edge")

		sheep.set_physics_process(false)
	# Real physics with the sheep on one side and Ralph counterbalancing it.
	rock.set_physics_process(false)
	balance.tilt = 0; balance.tilt_velocity = 0; balance.rotation.z = 0; balance.tipping_moment = 0; balance.contact_ids.clear(); balance.pending_landings.clear(); balance.pending_impulse = 0
	sheep.reset_to_home(); sheep.flock = null; sheep.set_physics_process(true)
	sheep.global_position = balance.global_position+Vector3(3,0,0)
	sheep.global_position.y = balance.sheep_surface_height(sheep)
	sheep.rest_on_seesaw(balance)
	player.global_position = balance.global_position+Vector3(-2,0,0)
	player.global_position.y = balance.surface_height(player.global_position)
	player.velocity = Vector3.ZERO
	for i in range(150): await physics_frame
	check(not sheep.dead and absf(balance.tilt)<2 and sheep.seesaw_support==balance,"Ralph's60 weight opposes sheep40 and keeps the sheep safe on the balanced board")
	sheep.set_physics_process(false)
	# Reproduce the reported carried-sheep position on the positive half.
	balance.tilt = 0; balance.tilt_velocity = 0; balance.rotation.z = 0; balance.tipping_moment = 0
	sheep.reset_to_home(); sheep.set_physics_process(false); sheep.carried_by = player; player.carried_sheep = sheep
	sheep.carry_controller = OriginalSheepCarry.new()
	sheep.get_node("CollisionShape3D").set_deferred("disabled",true)
	sheep.add_collision_exception_with(player)
	for i in range(3): await physics_frame
	player.global_position = balance.global_position+Vector3(3,0,0)
	player.global_position.y = balance.surface_height(player.global_position)
	player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE); player.set_physics_process(true)
	var maximum_tilt = 0.0; var fell_off = false
	for i in range(240):
		await physics_frame
		maximum_tilt = maxf(maximum_tilt,balance.tilt*360/4096)
		fell_off = fell_off or player.global_position.y<balance.global_position.y-2
	print("carried tilt=",maximum_tilt," ralph=",player.global_position)
	check(maximum_tilt>75 and fell_off,"Ralph carrying sheep tips the second plank to the80 degree stop and both leave the edge")
	check(player.carried_sheep==sheep and sheep.carried_by==player,"Sliding off the balancing plank preserves the carried sheep")
	player.carried_sheep = null; sheep.carried_by = null; player.set_physics_process(false)
	# Re-arm and launch only the rock: this used to leave a permanent camera.
	player.global_position = Vector3(60,3,-40)
	rock.set_physics_process(true)
	rock.launch(board.definition.trajectories[1]); env.start_launch_camera(board.definition.launch_cameras[1],true,rock)
	for i in range(180): await physics_frame
	check(not is_instance_valid(env.launch_camera),"A rock-only launch must return the camera after its flight")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level06 repeated first-drop sheep / rock camera / balancing chain: ",failures," failures")
	quit(failures)
