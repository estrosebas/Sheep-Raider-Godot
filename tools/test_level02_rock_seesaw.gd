extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_51").set_physics_process(false)
	var environment = level.get_node("LevelEnvironment"); environment.set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	player.global_position = Vector3(100,10,100)
	var board = environment.seesaw; var rock = level.get_node("Rock_44")
	rock.global_position = board.global_position+Vector3(-3,board.top_offset+rock.radius+1.5,0); rock.velocity = Vector3.ZERO; rock.fall_time = 0
	for i in range(120): environment._physics_process(1.0/60); await physics_frame
	check(rock.is_on_floor() and rock.seesaw_support==board and board.contact_ids.has(rock.get_instance_id()),"Dropped pushable rock enters native ON_SEESAW contact state")
	check(board.tilt< -100 and not rock.can_interact(player),"Native rock weight120 lowers its side and it is not pushed uphill on the board")
	var box = board.definition.ejection_boxes[1]
	player.global_position = OriginalSeesaw.source_point([(box.min[0]+box.max[0])/2,(box.min[1]+box.max[1])/2,(box.min[2]+box.max[2])/2])
	environment._physics_process(.016)
	check(board.timers[1]>3.9,"Original opposite-end launch timer arms from the authored platform box")
	player.global_position = board.global_position+Vector3(3,0,0)
	player.global_position.y = board.surface_height(player.global_position)+.5
	player.velocity = Vector3.DOWN; player.set_state(player.WolfState.FALL); player.set_physics_process(true)
	var launched = false; var height = rock.global_position.y; var highest = height
	for i in range(140):
		environment._physics_process(1.0/60); await physics_frame
		launched = launched or not rock.arc.is_empty()
		highest = maxf(highest,rock.global_position.y)
	check(launched and board.launch_count>0,"Ralph landing on opposite end launches the resting rock using native trajectory")
	check(highest>height+3,"Rock rises out of lower side rather than remaining stuck")
	check(rock.arc.is_empty() and rock.global_position.x<board.global_position.x-4,"Original left trajectory returns the rock toward its upper ledge")
	rock.global_position.y = -50; rock.reset_to_home()
	check(rock.global_position.is_equal_approx(rock.home),"Rock44 native RESET flag returns it home on checkpoint reset if lost")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level02 rock gravity / seesaw launch / native recovery: ",failures," failures"); quit(failures)
