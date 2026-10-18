extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://clock_passage03_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(25)
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var actor = level.player; actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	var clock = level.get_node("TimeKeeper_86")
	check(not level.has_node("OriginalObjectCollisions/TimeKeeper_86") and clock.physical_root!=null,"Clock owns native collision without static duplicate")
	check(clock.physical_root.global_position.distance_to(clock.global_position)<.001 and clock.position.y<6.1,"Collision follows actual grounded clock rather than old6.87m spawn")
	check(clock.physical_root.global_basis.is_equal_approx(Basis.IDENTITY),"World-aligned clock box is independent of the180-degree artwork yaw")
	var space = level.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(Vector3(6,7.75,-50),Vector3(6,7.75,-43),1)
	ray.exclude = [actor.get_rid()]
	check(space.intersect_ray(ray).is_empty(),"Native face6628 no longer invades visible clock exit")
	var source = load("res://assets/levels/lvl_03/collision.tres").get_faces()
	var patched = level.get_node("Collision/CollisionShape3D").shape.get_faces()
	var region = AABB(Vector3(2.5,5,-50),Vector3(5,9,8))
	var outside_source: Array = []; var outside_patched: Array = []
	for i in range(0,source.size(),3):
		if not region.has_point((source[i]+source[i+1]+source[i+2])/3): outside_source.append([source[i],source[i+1],source[i+2]])
	for i in range(0,patched.size(),3):
		if not region.has_point((patched[i]+patched[i+1]+patched[i+2])/3): outside_patched.append([patched[i],patched[i+1],patched[i+2]])
	check(outside_source==outside_patched,"Collision outside the local passage remains byte-for-byte native")
	# Collect clock through its actual grounded interaction, then leave the alcove.
	actor.global_position = clock.global_position+Vector3(-.85,.04,-.4); actor.velocity = Vector3.DOWN
	actor.set_state(actor.WolfState.FALL); await frames(10)
	check(clock.can_interact(actor) and clock.interact(actor),"Grounded clock is accessible through shared E interaction")
	check(OriginalProgress.has_clock("lvl_03"),"Clock awards actual level03 progress")
	await frames(80)
	actor.camera_pivot.rotation.y = 0
	Input.action_press("move_left")
	for i in range(65):
		await physics_frame
		if actor.position.x<5.65: break
	Input.action_release("move_left"); actor.velocity.x = 0
	Input.action_press("move_backward")
	# Jump over the visible raised lip; no invisible lateral face may block us.
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	var touched_wall = false
	for i in range(105):
		await physics_frame
		for j in range(actor.get_slide_collision_count()):
			var contact = actor.get_slide_collision(j)
			if contact.get_collider()==level.get_node("Collision") and contact.get_normal().z<-.6: touched_wall = true
		if actor.position.z>-42.3: break
	Input.action_release("move_backward")
	print("Clock exit: ",actor.global_position," state=",actor.current_state," frontWall=",touched_wall)
	check(actor.global_position.z>-43.5 and actor.current_state!=actor.WolfState.PIT_FALL,"After collecting, Ralph physically exits the opening toward the previous zone")
	# Return through exactly the same opening to test both collision directions.
	actor.camera_pivot.rotation.y = 0; Input.action_press("move_forward")
	for i in range(100):
		await physics_frame
		if actor.position.z<-49: break
	Input.action_release("move_forward")
	check(actor.position.z<-48.8 and actor.current_state!=actor.WolfState.PIT_FALL,"Opening also remains traversable in the reverse direction")
	check(clock.physical_root.global_position.distance_to(clock.global_position)<.001,"Clock collision remains aligned while ringing/collected")
	if DisplayServer.get_name()!="headless":
		actor.restart_fade.hide(); root.size = Vector2i(1280,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = Vector3(8,7.7,-51); camera.look_at(Vector3(4,7.5,-47)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_clock_passage.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level03 grounded clock / native collider / collected progress / two-way passage: ",failures," failures")
	quit(failures)
