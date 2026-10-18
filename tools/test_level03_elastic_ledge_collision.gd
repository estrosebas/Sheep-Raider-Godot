extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://elastic_ledge_wall_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	player.cinematic_controls_locked = false; player.tutorial_movement_locked = false
	var space = level.get_world_3d().direct_space_state
	check(level.get_node("Collision/CollisionShape3D").shape.get_faces().size()/3==7084,"Authored ground, platforms and all native collision triangles remain intact")
	# These rays crossed the visible purple cliff with no physical hit before
	# the fix, at the exact height of Ralph's capsule after the second seesaw.
	for sample in [Vector3(12,11.5,-28.62871),Vector3(13,11.5,-27.95068),Vector3(14,11.5,-27.20749),Vector3(15,11.5,-26.52563),Vector3(16,11.5,-23.6274)]:
		for direction in [-1.0,1.0]:
			var query = PhysicsRayQueryParameters3D.create(sample+Vector3.BACK*direction,sample-Vector3.BACK*direction,1)
			query.exclude = [player.get_rid()]
			var hit = space.intersect_ray(query)
			check(not hit.is_empty() and hit.position.distance_to(sample)<.03,"Purple cliff blocks both sides at %s direction %s"%[sample,direction])
		var camera_query = PhysicsRayQueryParameters3D.create(sample+Vector3.BACK,sample-Vector3.BACK,2)
		camera_query.exclude = [player.get_rid()]
		check(not space.intersect_ray(camera_query).is_empty(),"The same visible wall blocks the camera at %s"%sample)
	player.global_position = Vector3(14,10.08,-25.5); player.velocity = Vector3.ZERO
	await physics_frame
	var contact = player.move_and_collide(Vector3(0,0,-4))
	print("Wall approach: ",player.global_position," contact=",contact!=null)
	check(contact!=null and absf(contact.get_normal().y)<.5 and player.global_position.z>-27,"Walking toward the cliff stops outside the rendered wall instead of entering it")
	var pressed = player.global_position
	for i in range(30):
		player.velocity = Vector3(-3,0,-2.2); player.move_and_slide(); await physics_frame
	check(player.global_position.distance_to(pressed)>.9,"Ralph can move along the wall after contact instead of getting wedged")
	player.global_position = Vector3(11.93,10.87,-25.21)
	for i in range(45):
		player.velocity = Vector3.DOWN*3; player.move_and_slide(); await physics_frame
	check(player.is_on_floor() and absf(player.global_position.y-10.00712)<.05,"The native second-seesaw landing remains supported by its original floor")
	var landing = player.global_position
	player.move_and_collide(Vector3(1.5,0,-.15))
	check(player.global_position.distance_to(landing)>1.4,"The route from the landing toward the elastic delivery stays open")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level03 elastic ledge / purple walls / camera / seesaw landing: ",failures," failures")
	quit(failures)
