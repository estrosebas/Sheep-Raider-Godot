extends SceneTree

var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var puzzle = level.get_node("TutorialPuzzle")
	var player = level.get_node("Player")
	var training = level.get_node("CameraTraining")
	training.enabled = false
	var director = level.get_node("TutorialIntro")
	director.set_process(false)
	director.switch_sequence("res://assets/cinematics/tutorial_intro/platform_sequence.json")
	director.start_sequence(true)
	director.finish_sequence(false)
	check(puzzle.seesaws.size() == 2 and puzzle.rocks.size() == 2,"Original puzzle entities recovered")
	await frames(180)
	for rock in puzzle.rocks:
		check(rock.global_position.y < rock.initial_position.y-1,"Rock falls from its original authored position instead of floating")
		check(rock.is_on_floor(),"Rock settles on real collision")
	for seesaw in puzzle.seesaws:
		check(absf(seesaw.tilt) > 10 and absf(seesaw.tilt) <= seesaw.max_positive,"Original Rock weight inclines its seesaw within 20 degrees")
		var ray = PhysicsRayQueryParameters3D.create(seesaw.global_position+Vector3(2,6,0),seesaw.global_position+Vector3(2,-2,0))
		var hit = level.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit["collider"] == seesaw,"Seesaw has a real walkable collider")
	check(OriginalSeesaw.arc_point(Vector3.ZERO,Vector3(1,4,0),Vector3(2,0,0),.5).is_equal_approx(Vector3(1,4,0)),"Source LaunchArc passes through its authored midpoint")
	# First seesaw on the route is resource 48: heavy rock on left, Ralph on right.
	var first = puzzle.seesaws[1]
	player.global_position = TutorialProgress.center(first.definition["ejection_boxes"][1])
	await frames(1)
	check(first.timers[1] > 0,"Original high platform arms launch timer")
	player.global_position = first.global_position+Vector3(3.2,3.5,0)
	player.set_state(player.WolfState.FALL)
	player.velocity = Vector3(0,-5,0)
	var launched_player = false
	var launched_big = false
	for i in range(240):
		await physics_frame
		launched_big = launched_big or not puzzle.rocks[0].arc.is_empty()
		launched_player = launched_player or puzzle.player_launching()
	check(launched_big,"Landing from armed platform launches opposite heavy rock")
	check(launched_player,"Heavy rock returning catapults Ralph along the authored trajectory")
	print("First launch outcome: player=",player.global_position," rock=",puzzle.rocks[0].global_position," tilt=",first.tilt)
	check(player.is_on_floor() and player.global_position.y > 5,"Ralph lands on the elevated platform instead of passing through it along the arc")
	# Second seesaw: Ralph lands left to send the small rock onto the red button.
	var second = puzzle.seesaws[0]
	player.global_position = TutorialProgress.center(second.definition["ejection_boxes"][0])
	await frames(1)
	player.global_position = second.global_position+Vector3(-3.3,4,0)
	player.set_state(player.WolfState.FALL)
	player.velocity = Vector3(0,-5,0)
	var launched_small = false
	for i in range(180):
		await physics_frame
		launched_small = launched_small or not puzzle.rocks[1].arc.is_empty()
	check(launched_small,"Second seesaw launches small rock toward the button")
	check(puzzle.pressed and puzzle.gate_open and puzzle.gate_shape.disabled,"Small rock holds button and gate collision opens")
	print("Second launch outcome: rock=",puzzle.rocks[1].global_position," button=",puzzle.button.global_position," pressed=",puzzle.pressed)
	puzzle.rocks[1].global_position += Vector3(5,0,0)
	await frames(90)
	check(not puzzle.pressed and not puzzle.gate_shape.disabled,"Removing button weight closes the gate")
	# Grounded run states reject jump edges until SLIDE1 completes.
	player.global_position = Vector3(-87.41,.5,43.45)
	player.interrupt_actions()
	await frames(60)
	player.set_physics_process(false)
	for state in [player.WolfState.RUN_START,player.WolfState.RUN,player.WolfState.RUN_STOP]:
		player.set_state(state)
		player.state_time = 0
		Input.action_press("jump")
		player._physics_process(.016)
		check(player.current_state != player.WolfState.JUMP,"Jump cannot interrupt sprint or braking")
		check(not player.can_use_inventory() and not player.can_use_item(),"Inventory/items stay blocked during sprint and braking")
		Input.action_release("jump")
		await process_frame
	player.set_state(player.WolfState.RUN_RECOVER)
	Input.action_press("jump")
	player._physics_process(.016)
	check(player.current_state == player.WolfState.JUMP,"Jump is available once braking animation completes")
	Input.action_release("jump")
	training._show_dialogue(14)
	check(training.voice_pending and not training.voice.playing,"Original dialogue queues voice while letterbox opens")
	training.letterbox._process(1.5)
	training.enabled = true
	training._process(.016)
	check(not training.voice_pending and training.voice.playing,"Original dialogue starts voice once both bars are open")
	check(training.letterbox.timer_ms == 1500 and training.dialogue_pages.size() >= 6,"Original 1500ms bars and two-line dialogue pages")
	training.card.hide()
	training.letterbox._process(1.5)
	check(training.letterbox.timer_ms == 0,"Letterbox closes after dialogue")
	player.capture_mouse(false)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	level.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("Puzzle/letterbox/run lock: ",failures," failures")
	quit(failures)
