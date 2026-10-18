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
	var space = level.get_world_3d().direct_space_state
	for z in [-32,-30,-28,-26,-24,-22,-20,-18]:
		var ray = PhysicsRayQueryParameters3D.create(Vector3(7,5,z),Vector3(7,-10,z))
		ray.exclude = [sheep.get_rid()]
		print("FLOOR ",z," ",space.intersect_ray(ray))
	salad.global_position = Vector3(7,.05,-25)
	sheep.global_position = Vector3(7,.05,-23)
	sheep.last_floor_y = .05
	for i in range(10):
		await create_timer(.5).timeout
		print("BRIDGE ",sheep.global_position," phase ",sheep.flock_phase," target ",sheep.flock_target," time ",salad.eat_time," dead ",sheep.dead," leaf ",salad.global_position)
	level.queue_free()
	await process_frame
	quit()
