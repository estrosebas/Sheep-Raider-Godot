extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func touches_region(a: Vector3,b: Vector3,c: Vector3,region: AABB) -> bool:
	# A modified edge can move a triangle's centroid across the region border;
	# compare only whole triangles completely outside the local correction.
	return AABB(a,Vector3.ZERO).expand(b).expand(c).grow(.001).intersects(region)
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
	var profile = level.get_node("LocalWalkingCollision")
	var default_angle = actor.wall_min_slide_angle
	var default_block = actor.floor_block_on_wall
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	# Actually drop the prop which covers the OUTER exit. Earlier tests stopped
	# before it and never played CIN5, leaving the stale box untested.
	var prop = level.get_node("MiscStatic_112")
	var prop_body = level.get_node("OriginalObjectCollisions/MiscStatic_112")
	check(manager.start_movie(5),"Native CIN5 opens the clock passage by dropping the slab")
	await frames(50)
	check(not manager.movies[5].playing and absf(prop.position.y-.17)<.01,"Slab reaches original dropped cinematic position")
	check(prop_body.global_position.distance_to(prop.global_position)<.001,"Dropped slab collision follows the prop instead of floating above the exit")
	check(prop_body.global_basis.is_equal_approx(Basis.IDENTITY),"Moved prop keeps native world-aligned solid boxes")
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
		if not touches_region(source[i],source[i+1],source[i+2],region): outside_source.append([source[i],source[i+1],source[i+2]])
	for i in range(0,patched.size(),3):
		if not touches_region(patched[i],patched[i+1],patched[i+2],region): outside_patched.append([patched[i],patched[i+1],patched[i+2]])
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
	# Walking must clear both small floor lips; jumping hid this regression.
	var touched_wall = false
	for i in range(400):
		await physics_frame
		for j in range(actor.get_slide_collision_count()):
			var contact = actor.get_slide_collision(j)
			if contact.get_collider()==level.get_node("Collision") and contact.get_normal().z<-.6: touched_wall = true
		if actor.position.z>-29.8: break
	Input.action_release("move_backward")
	actor.velocity.x = 0; actor.velocity.z = 0
	await frames(60)
	print("Clock exit: ",actor.global_position," state=",actor.current_state," frontWall=",touched_wall)
	check(actor.global_position.z>-30.0 and actor.position.x<4 and actor.current_state!=actor.WolfState.PIT_FALL,"After collecting, Ralph walks through the curved exit AND past the actual fallen slab")
	# The final slab drops to the lower outdoor area. Reverse walking is tested
	# on the upper ledge, before that drop (not by demanding a five-meter step).
	actor.global_position = Vector3(3.3,5.7,-33.7); actor.velocity = Vector3.DOWN
	actor.set_state(actor.WolfState.FALL); await frames(12)
	actor.camera_pivot.rotation.y = 0; Input.action_press("move_forward")
	for i in range(340):
		await physics_frame
		if actor.position.z<-49: break
	Input.action_release("move_forward")
	check(actor.position.z<-48.8 and actor.current_state!=actor.WolfState.PIT_FALL,"Opening also remains traversable in the reverse direction")
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	var record = JSON.parse_string(JSON.stringify(save.snapshot))
	check(save.restore_checkpoint(record),"JSON checkpoint reload restores dropped scenery")
	await frames(3)
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	check(prop_body.global_position.distance_to(prop.global_position)<.001 and absf(prop.position.y-.17)<.01,"Loaded slab artwork and box stay lowered together")
	# Old saves have played-cinematic flags, but no scenery-transform records.
	prop.global_position.y = 5.11; prop_body.global_position.y = 5.11
	manager.restore_progress({"played":[5.0]}); await frames(2)
	check(absf(prop.position.y-.17)<.01 and prop_body.global_position.distance_to(prop.global_position)<.001,"Older saves repair dropped slab from played CIN5 float identifier")
	# Reproduce the user's sticking point at the FINAL mouth, not the inner lips.
	for x in [5.0,5.8,6.6]:
		actor.interrupt_actions(); actor.global_position = Vector3(x,7.5,-41.0)
		actor.camera_pivot.rotation.y = 0
		actor.velocity = Vector3.DOWN; actor.set_state(actor.WolfState.FALL)
		await frames(12)
		Input.action_press("move_backward")
		for i in range(350):
			await physics_frame
			if actor.position.z>-34.3: break
		Input.action_release("move_backward")
		check(actor.position.z>-34.5 and actor.position.x<4 and actor.is_on_floor(),"Ralph slides around final corner from laneX%s without jumping/falling"%x)
	# The obstacle remains: removing it would let Ralph walk into the void.
	var cliff_ray = PhysicsRayQueryParameters3D.create(Vector3(5.5,8,-41),Vector3(5.5,8,-39),1)
	cliff_ray.exclude = [actor.get_rid()]
	check(not space.intersect_ray(cliff_ray).is_empty(),"Real cliff wall remains solid to guide Ralph to safe left route")
	actor.global_position = Vector3(20,10,20); profile._physics_process(0)
	check(is_equal_approx(actor.wall_min_slide_angle,default_angle) and actor.floor_block_on_wall==default_block,"Local walking options restore outside the passage")
	actor.global_position = Vector3(5.5,7.2,-41); actor.current_state = actor.WolfState.RUN_START
	profile._physics_process(0)
	check(not profile.applied,"Local walking adapter does not change running collisions")
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
