extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func walk(player,target: Vector3):
	for i in range(180):
		var difference = target-player.global_position; difference.y = 0
		if difference.length()<.15: return true
		player.velocity = difference.normalized()*3.0
		player.velocity.y = -.6 if player.is_on_floor() else -4.0
		player.move_and_slide()
		await physics_frame
	return false
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://corral_boundary_test_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level06.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(40): await physics_frame
	var director = level.get_node("LevelCinematics")
	if director.active_movie: director.active_movie.finish_sequence(true)
	director.movies[0].played = true
	var player = level.player; var sam = level.get_node("Sam_41")
	player.restart_fade_remaining = 0; player.cinematic_controls_locked = false
	player.set_physics_process(false); sam.set_physics_process(false)
	var original: ConcavePolygonShape3D = load(level.asset_directory+"/collision.tres")
	check(level.get_node("Collision/CollisionShape3D").shape==original,"Original scenery/camera/NPC collider is preserved")
	var barrier = level.get_node("PlayerBoundaries/RaisedSnowRidge")
	var faces = barrier.get_child(0).shape.get_faces()
	var high = 0.0
	for vertex in faces: high = maxf(high,vertex.y)
	check(high>60,"Real snow ridge vertices rise above sixty meters")
	check((player.collision_mask&8)!=0 and (sam.collision_mask&8)==0 and (player.camera_pivot.collision_mask&8)==0,"Raised geometry affects Ralph only")
	# Check actual native inner/outer ridge faces, including the previously
	# omitted corners; test above any normal or double jump on either side.
	var space = level.get_world_3d().direct_space_state
	for line in [[Vector3(-13,10,-30),Vector3(-18,10,-30)], [Vector3(-8,10,-26),Vector3(-8,10,-20)], [Vector3(-13,10,-34),Vector3(-17,10,-36)], [Vector3(-5,10,-35),Vector3(-5,10,-39)]]:
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(line[0],line[1],8)).is_empty(),"Native ridge footprint blocks high bypass")
	# The real entrance is south between the two snowy tips, NOT the river.
	for x in [-9.4,-8.7,-7.8]:
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,.9,-39),Vector3(x,.9,-35.5),8)).is_empty(),"Native southern opening remains free across its width")
	player.add_collision_exception_with(sam)
	for sheep in level.get_node("Flock").sheep: player.add_collision_exception_with(sheep)
	# Walk with Ralph's real capsule and ALL collision masks, in both phases.
	player.global_position = player.respawn_ground_position(Vector3(-8.7,0,-39))
	check(await walk(player,Vector3(-8.7,0,-35.5)),"Phase1: Ralph physically enters through the original opening")
	level.get_node("SamFluteEncounter").finished(false)
	check(await walk(player,Vector3(-8.7,0,-39)),"Phase2: Ralph physically exits after Sam changes patrol")
	check(await walk(player,Vector3(-8.7,0,-35.5)),"Phase2: Ralph can re-enter the sheep area")
	# Sam must also leave his home via this passage on his real trajectory.
	player.global_position = Vector3(70,20,70)
	sam.reset_guard(); sam.set_physics_process(true)
	for i in range(140): await physics_frame
	check(sam.global_position.z< -37.5,"Second patrol gets through the original southern passage")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Level06 native ridge vertices / high barriers / real capsule entrance in both phases / Sam patrol: ",failures," failures")
	quit(failures)