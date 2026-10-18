extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://rock_crush_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_63").set_physics_process(false)
	var environment = level.get_node("LevelEnvironment"); environment.set_physics_process(false)
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.cinematic_controls_locked = false; player.tutorial_movement_locked = false
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var rock = level.get_node("Rock_60"); rock.set_physics_process(false)
	var source = environment.seesaws.filter(func(board):return int(board.definition.res)==52)[0].definition.trajectories[1]
	var landing = OriginalSeesaw.source_point(source[2])
	var ray = PhysicsRayQueryParameters3D.create(landing+Vector3.UP*8,landing-Vector3.UP*10,1)
	ray.exclude = [player.get_rid(),rock.get_rid()]
	var hit = player.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(),"Native return point has solid terrain/support")
	if not hit.is_empty(): landing.y = hit.position.y
	player.global_position = landing; player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE)
	await physics_frame; await physics_frame
	rock.global_position = OriginalSeesaw.source_point(source[0]); rock.launch(source)
	for i in range(90):
		rock._physics_process(1.0/60); await physics_frame
		if player.death_animation_override=="crush_death": break
	check(player.current_state==player.WolfState.SAM_DEATH and player.death_animation_override=="crush_death","Actual native seesaw return crushes Ralph instead of resting on his capsule")
	check(player.animation_player.current_animation=="crush_death" and is_equal_approx(player.animation_player.get_animation("crush_death").length,.61),"KILL_CRUSH plays native SQUASH3 with original duration")
	check(player.get_collision_exceptions().has(rock) and rock.get_collision_exceptions().has(player),"Crushed capsule lets the rock finish falling")
	player.state_time = .6; rock.crush_objects_below(rock.global_position,rock.global_position)
	check(is_equal_approx(player.state_time,.6),"Repeated overlap cannot restart death/fade")
	for i in range(45): rock._physics_process(1.0/60); await physics_frame
	player.animation_player.advance(.61); player.apply_legacy_reaction_pose()
	player.step_pit_fall(.016)
	check(player.global_position.y<=rock.bottom()+.001,"Flattened Ralph stays below the killer instead of clipping into the stone")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		player.camera.global_position = Vector3(4.6,18.74,-21.45); player.camera.look_at(landing+Vector3.UP*.5)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_rock_crush.png")
	player.state_time = 1.9; player.step_pit_fall(.016)
	check(player.restart_fade.overlay.color.a>0,"Native animation plus two-second delay closes the iris before respawn")
	player.state_time = 2.62; player.step_pit_fall(.016)
	check(player.current_state==player.WolfState.IDLE and player.crushing_rock==null and player.camera.get_parent()==player.camera_pivot,"Crush death restores checkpoint and camera")
	check(not player.get_collision_exceptions().has(rock) and not rock.get_collision_exceptions().has(player),"Respawn restores ordinary rock collisions")
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	rock.arc.clear(); rock.seesaw_support = null
	rock.global_position = landing+Vector3.UP*(rock.radius+2)
	player.global_position = landing+Vector3(rock.radius+1,0,0)
	await physics_frame; await physics_frame
	rock.crush_objects_below(rock.global_position,landing+Vector3.UP*rock.radius)
	check(player.current_state==player.WolfState.IDLE,"Standing beside the native crush box remains safe")
	player.global_position = rock.global_position+Vector3.UP*rock.radius
	await physics_frame; await physics_frame
	rock.crush_objects_below(rock.global_position,rock.global_position)
	check(player.current_state==player.WolfState.IDLE,"Standing above the rock is not a crush")
	player.global_position = landing; player.restart_fade_remaining = .5
	await physics_frame; await physics_frame
	rock.crush_objects_below(rock.global_position,landing+Vector3.UP*rock.radius)
	check(player.current_state==player.WolfState.IDLE,"Opening respawn iris cannot immediately repeat the crush death")
	# The first rock's native gameplay CIN also keeps Ralph free. Ending
	# that shot after a crush must not restart death or corrupt camera parenting.
	player.restart_fade_remaining = 0
	var cinematic_rock = level.get_node("Rock_55")
	cinematic_rock.global_position = TutorialProgress.center(cinematic_rock.definition.cine_trigger[0])
	check(cinematic_rock.try_native_cinematic(),"First rock can start its gameplay cinematic for crush regression")
	var movie = manager.active_movie
	if movie:
		movie.set_process(false); movie._process(.016)
		player.global_position = cinematic_rock.global_position-Vector3.UP*cinematic_rock.radius
		await physics_frame; await physics_frame
		movie._process(0)
		check(player.death_animation_override=="crush_death","Native gameplay rock cinematic also crushes Ralph underneath")
		var camera_parent_before = player.death_camera_parent
		player.state_time = .3
		movie.finish_sequence(false)
		check(player.current_state==player.WolfState.SAM_DEATH and is_equal_approx(player.state_time,.3) and player.death_camera_parent==camera_parent_before,"Finishing a gameplay cinematic preserves active crush death and camera recovery")
		player.respawn_at_checkpoint()
		check(player.camera.get_parent()==player.camera_pivot,"Crush during a gameplay movie also restores camera on respawn")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level03 returning rock / native SQUASH3 / crush bounds / iris / checkpoint: ",failures," failures")
	quit(failures)
