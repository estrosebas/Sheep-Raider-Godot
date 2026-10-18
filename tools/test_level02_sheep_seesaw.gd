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
	var flock = level.get_node("Flock"); flock.set_physics_process(false)
	var environment = level.get_node("LevelEnvironment"); environment.set_physics_process(false)
	var board = environment.seesaw; var sheep = flock.sheep[0]
	player.global_position = Vector3(100,10,100); player.cinematic_controls_locked = false
	for other in flock.sheep:
		other.global_position = Vector3(100,10,100); other.set_physics_process(false)
	sheep.flock_target = null
	var tilt_values: Array = []
	for side in [-1,1]:
		board.tilt = 0; board.tilt_velocity = 0; board.rotation = Vector3.ZERO; board.contact_ids.clear(); board.timers = [0.0,0.0]
		sheep.set_physics_process(true)
		sheep.global_position = board.global_position+Vector3(side*3,board.top_offset+.15,0); sheep.velocity = Vector3.DOWN
		for i in range(120):
			environment._physics_process(1.0/60); await physics_frame
		check(sheep.is_on_floor() and board.contact_ids.has(sheep.get_instance_id()),"Loose sheep physically contacts and loads the board on side "+str(side))
		check(absf(board.tilt)>20 and signf(board.tilt)==side,"Sheep weight tilts the board on side "+str(side))
		tilt_values.append(board.tilt)
		check(absf(sheep.global_position.y-board.surface_height(sheep.global_position))<.5,"Sheep stays supported while board tilts")
	# Carried/dead sheep must not add a hidden weight from stale floor state.
	sheep.carried_by = player; sheep.set_physics_process(false)
	environment._physics_process(.04)
	check(not board.contact_ids.has(sheep.get_instance_id()),"Carried sheep does not count as a separate load")
	sheep.carried_by = null; sheep.dead = true; environment._physics_process(.04)
	check(not board.contact_ids.has(sheep.get_instance_id()),"Dead sheep does not keep board activated")
	sheep.dead = false; sheep.global_position = Vector3(100,10,100)
	for i in range(150): environment._physics_process(.04)
	check(absf(board.tilt)<5,"Removing the sheep returns the empty board to rest")
	# Exercise the actual puzzle, not only a sheep's isolated static weight.
	board.tilt = 0; board.tilt_velocity = 0; board.rotation = Vector3.ZERO; board.contact_ids.clear()
	sheep.reset_to_home(); sheep.set_physics_process(true)
	sheep.global_position = board.global_position+Vector3(3,board.top_offset+.15,0); sheep.velocity = Vector3.DOWN
	for i in range(120): environment._physics_process(1.0/60); await physics_frame
	check(board.contact_ids.has(sheep.get_instance_id()),"Sheep remains a rider before the rock impact")
	var rock = level.get_node("Rock_44")
	rock.global_position = board.global_position+Vector3(-3.2,0,0)
	rock.global_position.y = rock.home.y; rock.velocity = Vector3.ZERO; rock.fall_time = 0
	var launched = false; var highest = sheep.global_position.y; var start_height = highest
	environment.set_physics_process(true)
	for i in range(180):
		await physics_frame
		launched = launched or not sheep.seesaw_arc.is_empty()
		highest = maxf(highest,sheep.global_position.y)
		if sheep.seesaw_support == board:
			check(sheep.global_position.y>=board.sheep_surface_height(sheep)-.02,"Sheep never passes through the swinging plank")
	check(launched,"Rock falling from the original ledge launches the opposite sheep")
	check(highest>start_height+5,"Sheep follows the high original launch arc")
	var goal = level.get_node("Goal_110")
	check(sheep.seesaw_arc.is_empty() and sheep.is_on_floor(),"Launched sheep lands on the destination terrain")
	check(goal.qualifies(sheep.global_position,false),"Native sheep launch reaches the level02 goal")
	check(not goal.completed,"Sheep landing alone waits for Ralph to reach the goal")
	print("Sheep puzzle landing: ",sheep.global_position,"; max height ",highest,"; launches ",board.launch_count)
	environment.set_physics_process(false)
	# Native sheep bounce (wolf impact) is distinct from the rock's goal launch.
	sheep.global_position = board.global_position+Vector3(3,0,0); sheep.rest_on_seesaw(board)
	environment.launch(sheep,board.definition.trajectories[1],false)
	check(sheep.seesaw_arc.middle.is_equal_approx(sheep.seesaw_arc.start+Vector3.UP*3),"Wolf impact selects the native three-metre sheep hop")
	check(is_equal_approx(sheep.seesaw_arc.end.x,sheep.global_position.x),"Wolf hop cannot substitute for rock launch toward the goal")
	for i in range(90): await physics_frame
	check(sheep.seesaw_arc.is_empty() and sheep.global_position.y>=board.sheep_surface_height(sheep)-.05,"Vertical hop lands back on the plank rather than falling through it")
	environment.launch(sheep,board.definition.trajectories[1],true)
	sheep.reset_to_home()
	check(sheep.seesaw_arc.is_empty() and sheep.launch_board==null and sheep.seesaw_support==null,"Checkpoint reset clears sheep flight and plank attachment")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level02 sheep collision / native weight / seesaw: ",failures," failures; tilts ",tilt_values); quit(failures)
