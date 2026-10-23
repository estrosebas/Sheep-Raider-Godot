extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level02.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(.3).timeout
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var flock = level.get_node("Flock")
	var sheep = flock.sheep.filter(func(s): return not s.sleepy)[0]
	for other in flock.sheep:
		if other!=sheep: other.sleepy = true
	var player = level.player
	player.cinematic_controls_locked = false
	var button = level.get_node("SensibleButton_45")
	var lettuce = level.get_node("Salad_74")
	lettuce.available = true
	lettuce.respawn_time = 0
	# Isolate both targets from Sam and other authored attractors.
	var origin = Vector3(200,0,200)
	button.global_position = origin
	lettuce.global_position = origin+Vector3(0,0,100)
	sheep.global_position = origin+Vector3.RIGHT*2
	sheep.button_think_timer = 0
	flock._physics_process(.016)
	check(flock.attraction(sheep)==button,"Nearby button is detected on the thinking slot")
	sheep.flock_target = button
	sheep.flock_phase = "button_stand"
	sheep.carried_by = player
	player.carried_sheep = sheep
	flock._physics_process(.016)
	check(sheep.flock_target==null and not flock.reservations.has(button),"Carrying releases button ownership immediately")
	player.global_position = origin+Vector3.RIGHT*30
	sheep.drop()
	flock._physics_process(.016)
	check(flock.attraction(sheep)==null and sheep.flock_phase=="idle","Far-away dropped sheep cannot return to old button")
	sheep.global_position = origin+Vector3.RIGHT*2
	flock._physics_process(.016)
	check(flock.attraction(sheep)==null,"Re-entering button range waits for a new detection slot")
	flock._physics_process(1)
	check(flock.attraction(sheep)==button,"Button can be detected again normally")
	# A stale food-chain origin beside a lettuce must not attract from afar.
	button.enabled = false
	lettuce.global_position = origin
	sheep.flock_target = lettuce
	sheep.flock_phase = "eat"
	sheep.last_food_position = origin
	sheep.global_position = origin+Vector3.RIGHT*30
	flock._physics_process(.016)
	check(sheep.flock_target==null and sheep.last_food_position==null and flock.attraction(sheep)==null,"Displacement invalidates old lettuce and chain origin")
	sheep.global_position = origin+Vector3.RIGHT*2
	flock._physics_process(.016)
	check(flock.attraction(sheep)==lettuce,"Lettuce must be detected again from current sheep position")
	sheep.flock_target = lettuce
	sheep.flock_phase = "approach"
	sheep.last_food_position = null
	sheep.global_position = origin+Vector3.RIGHT*6.1
	flock._physics_process(.016)
	check(flock.attraction(sheep)==null,"Ordinary reservation cannot extend original six-metre detection")
	# Valid native food chain still searches around the last eaten lettuce.
	sheep.forget_attraction()
	sheep.last_food_position = origin+Vector3.RIGHT*5.5
	sheep.global_position = origin+Vector3.RIGHT*6.4
	flock._physics_process(.016)
	check(flock.attraction(sheep)==lettuce,"Natural chained lettuce can be six metres from last food plus eating offset")
	sheep.flock_target = lettuce
	sheep.flock_phase = "approach"
	flock._physics_process(.016)
	check(flock.attraction(sheep)==lettuce,"Valid chained approach keeps its reservation")
	sheep.carried_by = player
	player.carried_sheep = sheep
	flock._physics_process(.016)
	check(sheep.last_food_position==null and sheep.flock_target==null,"Picking up also clears chain memory")
	player.global_position = origin+Vector3.RIGHT*30
	sheep.drop()
	flock._physics_process(.016)
	check(flock.attraction(sheep)==null,"Drop never restores previous food-chain reservation")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free()
	await process_frame
	print("Sheep target release / carry / displacement / redetection / food chains: ",failures," failures")
	quit(1 if failures else 0)
