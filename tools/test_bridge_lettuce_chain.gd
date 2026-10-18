extends SceneTree
func _init(): call_deferred("run")
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.4).timeout
	var player = level.player
	player.set_physics_process(false)
	player.global_position = Vector3(40,0,40)
	level.get_node("Sam_43").set_physics_process(false)
	var sheep = level.get_node("Sheep_52")
	for other in level.get_node("Flock").sheep:
		if other != sheep: other.global_position = Vector3(200,0,200); other.set_physics_process(false)
	var salad = level.get_node("PorkyLessons").salads[0]
	salad.reveal_from_lesson()
	salad.deployed = true
	var failures = 0
	var space = level.get_world_3d().direct_space_state
	var leaf2 = level.get_node("PorkyLessons").salads[1]
	leaf2.reveal_from_lesson()
	leaf2.deployed = true
	for data in [[salad,-23.0],[leaf2,-28.5],[sheep,-21.0]]:
		var ray = PhysicsRayQueryParameters3D.create(Vector3(7,3,data[1]),Vector3(7,-5,data[1]))
		ray.exclude = [sheep.get_rid()]
		var hit = space.intersect_ray(ray)
		data[0].global_position = hit.position+Vector3.UP*.005
	sheep.last_floor_y = sheep.global_position.y
	await create_timer(.5).timeout
	var contender = level.get_node("Flock").sheep[1]
	contender.global_position = salad.global_position+Vector3(.3,0,0)
	await create_timer(.1).timeout
	if level.get_node("Flock").reservations.get(salad) != sheep:
		printerr("An approaching sheep lost its reserved salad"); failures += 1
	contender.global_position = Vector3(200,0,200)
	var ate_first = false
	var ate_second = false
	var chain_started = false
	for i in range(28):
		await create_timer(.5).timeout
		ate_first = ate_first or not salad.available
		ate_second = ate_second or not leaf2.available
		chain_started = chain_started or (sheep.flock_target == leaf2 and sheep.flock_phase == "approach")
		if ate_second: break
	if not ate_first or not ate_second or not chain_started or sheep.dead:
		printerr("Bridge lettuce chain failed: ",ate_first," ",ate_second," ",chain_started," dead=",sheep.dead); failures += 1
	print("Bridge reservation / two-lettuce chain: ",failures," failures")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop(); node.stream = null
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
