extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level06_thaw_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level06.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var player = level.player
	var director = level.get_node("LevelCinematics")
	if director.active_movie: director.active_movie.finish_sequence(true)
	director.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	player.cinematic_controls_locked = false
	level.get_node("Sam_41").set_physics_process(false)
	var lessons = level.get_node("DaffyLessons")
	var ice = lessons.ice
	var dryer = level.get_node("HairDryer_74")
	check(not ice.melted and not lessons.can_interact(player) and lessons.solid.collision_layer==0,"Frozen Lucas cannot talk or obstruct Ralph")
	player.set_physics_process(false)
	player.global_position = ice.global_position+Vector3(0,0,-2)
	player.skeleton.rotation.y = 0
	dryer.available = false
	var entry = {"id":dryer.item_id,"class_id":58,"label":dryer.item_label,"icon":dryer.icon_path,"kept":true}
	player.inventory.add_item(entry,dryer,false)
	player.inventory.equipped_id = dryer.item_id
	player.inventory._equip_world_item(entry)
	check(dryer.use_item(player).success and dryer.active,"Secador enters native HELD_FAN blowing state")
	check(dryer.heats_point(ice.global_position) and not dryer.heats_point(player.global_position+Vector3(4,0,0)) and not dryer.heats_point(dryer.global_position+Vector3(0,0,4.1)),"Native four metre cone rejects side and distant targets")
	for i in range(25): await physics_frame
	check(ice.heat_time>.2 and ice.heat_time<1 and not ice.melted and dryer.sound.playing,"Heat accumulates and native283 loops while blowing")
	dryer.deactivate()
	var paused = ice.animation_time
	for i in range(10): await physics_frame
	check(is_equal_approx(paused,ice.animation_time) and not dryer.sound.playing,"FOND1 and audio pause when heat stops")
	dryer.use_item(player)
	for i in range(70):
		await physics_frame
		if lessons.active_movie: break
	check(ice.melted and lessons.movie.playing and lessons.movie.camera.current,"One accumulated second frees Lucas and starts original voiced CIN1 camera")
	check(not dryer.active and dryer.holder==null and player.inventory.state.items.has(dryer.item_id),"Cinematic strips the tool without consuming it")
	check(ice.shape.disabled and lessons.movie.data.voice_id==38,"Melted ice stops colliding; native lesson voice38 plays")
	var lesson = lessons.movie
	var use = InputEventAction.new(); use.action = "action"; use.pressed = true
	lesson._unhandled_input(use)
	check(lesson.playing and not lessons.intro_finished,"The secador interaction cannot immediately skip the thaw lesson")
	check(lesson.data.text.contains("Soy un pato helado") and lesson.data.text.contains("mina") and lesson.voice_player.playing,"Release plays original frozen-duck speech and mine explanation, not the question menu")
	var actor = lesson.actors["2:55"]
	lesson.sample(3.0)
	check(actor.visible and actor.animation_player.current_animation=="freeze1","Original Lucas thaw animation is visible at2.656 seconds")
	lesson.sample(10.0)
	check(actor.visible and actor.animation_player.current_animation=="talk2","Native mine lesson switches to Lucas TALK2 at9.296 seconds")
	# Follow the real audio clock through the WHOLE recording, accelerated only
	# inside this test; do not finish_sequence(true) at frame zero as before.
	lesson.voice_player.pitch_scale = 8
	for i in range(650):
		await physics_frame
		if not lesson.playing: break
	check(not lesson.playing and lessons.intro_finished,"Complete native speech and camera animation finish naturally before enabling conversation")
	if lesson.playing: lesson.finish_sequence(true)
	check(lessons.intro_finished and lessons.solid.collision_layer==1 and lessons.daffy.idle_clip=="stand2","After the lesson Lucas is free, solid and at native STAND2")
	player.set_physics_process(false)
	player.global_position = lessons.daffy.global_position+Vector3(0,0,1.2)
	player.set_state(player.WolfState.IDLE)
	player.cinematic_controls_locked = false
	player.restart_fade_remaining = 0
	for answer in lessons.data.answers:
		lessons.say(answer)
		check(lessons.voice.playing and lessons.dialogue.timed,"Each native answer has its localized voice and timed text")
		lessons._process(2.1)
		check(lessons.daffy.idle_clip=="talk1","Native answer begins STAND2 then TALKS after two seconds")
		lessons._voice_finished()
	var mine = level.get_node("DefusableMine_64")
	player.global_position = lessons.daffy.global_position+Vector3(0,0,4)
	mine.global_position = lessons.global_position
	mine.explode()
	player.global_position = lessons.daffy.global_position+Vector3(0,0,1.2)
	check(lessons.burnt and not lessons.daffy.is_processing(),"A nearby bomb chars and freezes Lucas's current pose")
	# can_use_item requires floor contact; re-establish it at his native ground.
	player.set_physics_process(true)
	for i in range(15): await physics_frame
	check(lessons.interact(player) and lessons.burnt_line_said and not lessons.speech_skippable,"Talking to burnt Lucas starts the unskippable original punishment once")
	check(lessons.voice.stream.resource_path.ends_with("cin_lvl_0105.wav") and player.cinematic_controls_locked,"Punishment uses original voice and freezes Ralph")
	lessons._voice_finished()
	var saved = JSON.parse_string(JSON.stringify(lessons.capture_progress()))
	lessons.restore_progress(saved)
	check(ice.melted and lessons.intro_finished and lessons.burnt and lessons.burnt_line_said,"Checkpoint round trip retains thawed Lucas and punishment state")
	var save = level.get_node("CheckpointSave")
	save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and SaveFiles.write_slot(1,save.snapshot)==OK and save.restore_checkpoint(SaveFiles.read_slot(1)),"Full save slot writes and restores the thawed military lesson")
	check(lessons.intro_finished and ice.melted,"Loading a checkpoint cannot refreeze the completed lesson")
	lessons.reset_burnt()
	check(not lessons.burnt and not lessons.burnt_line_said,"Respawn resets native burnt/punishment flags")
	var env = level.get_node("LevelEnvironment")
	env.set_physics_process(false)
	var launch_board = env.seesaws[1]
	var balance_board = env.seesaws[0]
	check(is_equal_approx(rad_to_deg(launch_board.max_positive*TAU/4096),15) and is_equal_approx(rad_to_deg(balance_board.max_positive*TAU/4096),80) and is_equal_approx(rad_to_deg(balance_board.max_negative*TAU/4096),1),"Native authored limits: launch15/15 degrees, balancing1/80 degrees")
	player.set_physics_process(false); player.global_position = Vector3(70.5,8.19,-43.94)
	player.global_position.y = launch_board.surface_height(player.global_position)
	player.velocity = Vector3.ZERO
	launch_board.contact_ids.clear()
	launch_board.timers = [0.0,0.0]
	# First establish the rider, then let the falling rock actually land opposite.
	launch_board.step(.04,player,[],env)
	var rock = level.get_node("Rock_38")
	rock.set_physics_process(false); rock.arc.clear()
	rock.global_position = Vector3(77.8,0,-43.94)
	rock.global_position.y = launch_board.surface_height(rock.global_position)+rock.radius
	rock.velocity = Vector3(0,-8,0); rock.landed_speed = 8
	launch_board.step(.04,player,[rock],env)
	check(launch_board.launch_count>0 and player.seesaw_launching and not env.arc.is_empty(),"Real opposite rock impact launches Ralph on the original trajectory")
	check(is_instance_valid(env.launch_camera) and env.launch_camera.camera.current and env.launch_camera.no_freeze,"Launch uses original angle/focal length and native NO_FREEZE flag")
	# Run the complete flight through real world collision, not only the launch event.
	env.set_physics_process(true); player.set_physics_process(true)
	var highest = player.global_position.y
	for i in range(95):
		await physics_frame
		highest = maxf(highest,player.global_position.y)
		if env.arc.is_empty() and player.is_on_floor(): break
	check(highest>20 and player.global_position.x>93 and player.global_position.y>14 and player.current_state!=player.WolfState.PIT_FALL,"Full native rock flight reaches the next balancing section without a premature void death")
	if is_instance_valid(env.launch_camera): env.launch_camera.close()
	env.clear_player_launch(); env.set_physics_process(false); player.set_physics_process(false)
	var sheep = level.get_node("Flock").sheep[0]
	sheep.set_physics_process(false); sheep.dead = false; sheep.carried_by = null; sheep.seesaw_arc.clear()
	# Equal opposed native moments: Ralph60*2m, sheep40*3m.
	player.global_position = balance_board.global_position+Vector3(-2,0,0)
	player.global_position.y = balance_board.surface_height(player.global_position)
	player.velocity = Vector3.ZERO
	sheep.global_position = balance_board.global_position+Vector3(3,0,0)
	sheep.global_position.y = balance_board.sheep_surface_height(sheep)
	sheep.velocity = Vector3.ZERO
	for i in range(100): balance_board.step(.04,player,[sheep],env)
	check(absf(balance_board.tilt)<2,"Ralph and sheep at opposed weight-adjusted distances balance the board")
	player.global_position.x -= 10
	for i in range(60): balance_board.step(.04,player,[sheep],env)
	check(balance_board.tilt>56 and balance_board.slide_velocity().x>0,"Sheep alone tilts the SLIDE board and starts native downhill drift")
	# Keep a planted lettuce attached as the plank moves; no invented weight.
	var lettuce: GameItem
	for item in get_nodes_in_group("game_items"):
		if item.class_id==3 and item.get_parent()==level: lettuce = item; break
	check(lettuce!=null,"Native lettuce is available for the balancing puzzle")
	if lettuce:
		balance_board.tilt = 80; balance_board.rotation.z = -80*TAU/4096
		lettuce.available = true; lettuce.deployed = true; lettuce.holder = null
		lettuce.global_position = balance_board.to_global(Vector3(2,balance_board.top_offset,0))
		var support = preload("res://scripts/items/original_moving_support.gd").new()
		support.support = balance_board; lettuce.add_child(support)
		var old_y = lettuce.global_position.y
		balance_board.tilt = 120; balance_board.rotation.z = -120*TAU/4096
		for i in range(3): await physics_frame
		check(lettuce.global_position.y<old_y and absf(lettuce.global_position.y-balance_board.surface_height(lettuce.global_position))<.03,"Lettuce follows the rotating board rather than floating")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level06 hairdryer / ice / Lucas / native seesaw mechanics: ",failures," failures")
	quit(failures)
