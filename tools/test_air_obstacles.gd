extends SceneTree

const Solids = preload("res://scripts/levels/original_solid_builder.gd")
const Air = preload("res://scripts/player/ralph_air_rules.gd")
var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func floor_box(world: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = pos
	return body

func step(player: Node, frames: int, tap_every: int = 0) -> void:
	for frame in range(frames):
		await physics_frame
		if tap_every > 0 and frame > 0 and frame % tap_every == 0:
			Input.action_release("run")
			Input.action_press("run")
		player._physics_process(1.0/60)
		player.animation_player.advance(1.0/60)
		player.apply_legacy_reaction_pose()
		Input.action_release("run")

func run_tests() -> void:
	check(Air.RUN_AIR_LIMIT == 0.75 and Air.PIT_DROP == 30, "Source air-run tuning values")
	check(not Air.can_air_run(true,12,3,6), "Small terrain gaps do not qualify for cartoon air run")
	check(Air.can_air_run(true,12,INF,6), "Full-speed running over a pit qualifies")
	var world = Node3D.new()
	root.add_child(world)
	var floor = floor_box(world,Vector3(0,-0.5,0),Vector3(1000,1,1000))
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.capture_mouse(false)
	player.position = Vector3(0,0.01,0)
	await step(player,4)
	var baseline = player.position.y
	Input.action_press("jump")
	await step(player,1)
	Input.action_release("jump")
	var peak = player.position.y
	for i in range(60):
		await step(player,1)
		peak = maxf(peak,player.position.y)
	check(peak-baseline > 1.65 and peak-baseline < 1.95, "Reduced single jump reaches approximately 1.8m")
	print("Jump landing: state=",player.current_state," position=",player.position," velocity=",player.velocity," ray=",player.ground_drop())
	check(player.is_on_floor(), "Reduced jump lands normally")
	player.run_dust.update_dust(0.05,true,player.global_position,Vector3.BACK,12,12)
	var dust_position = player.run_dust.particles[0]["sprite"].global_position
	player.position.x += 3
	check(player.run_dust.particles[0]["sprite"].global_position == dust_position, "Dust particles remain in world space when Ralph moves")
	player.position.x -= 3
	var solids = Solids.build(world,"res://assets/levels/lvl_00/data/solid_boxes.json")
	check(solids.get_child_count() == 33, "Recovered solid boxes instantiate all 33 objects")
	# Real running movement against original cactus/rock hulls, in an isolated floor.
	player.camera_pivot.rotation.y = PI
	for name in ["Cactus_64","Rock_49","MiscStatic_80"]:
		var body = solids.get_node(name)
		var home = body.position
		body.position = Vector3.ZERO
		player.position = Vector3(0,0.01,-4)
		player.velocity = Vector3.ZERO
		player.set_state(player.WolfState.IDLE)
		await step(player,4)
		player.set_state(player.WolfState.RUN)
		player.run_active = true
		player.run_tap_timer = 0
		player.run_direction = Vector3.BACK
		player.velocity = Vector3.BACK*12
		var collided = false
		for i in range(30):
			await step(player,1)
			if player.get_slide_collision_count() > 0:
				for hit in range(player.get_slide_collision_count()):
					if player.get_slide_collision(hit).get_collider() == body:
						collided = true
		check(collided and player.position.z < 0.8, "Running cannot cross original " + name)
		check(player.current_state == player.WolfState.RUN_CRASH, "Original object triggers running impact animation: " + name)
		print(name, " collision=",collided," state=",player.current_state," z=",player.position.z)
		body.position = home
	Input.action_release("move_forward")
	player.position = Vector3(0,0.01,0)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.IDLE)
	await step(player,4)
	# Platform ends at z=2: no floor below the next 320m.
	floor.queue_free()
	var platform = floor_box(world,Vector3(0,-0.5,-9),Vector3(8,1,22))
	await physics_frame
	await step(player,4)
	player.set_state(player.WolfState.RUN)
	player.run_active = true
	player.run_tap_timer = 0
	player.run_direction = Vector3.BACK
	player.velocity = Vector3.BACK*12
	Input.action_press("move_forward")
	await step(player,20,12)
	check(player.current_state == player.WolfState.RUN_AIR, "Running off a real platform enters RUN_AIR")
	var air_height = player.position.y
	await step(player,24,12)
	check(absf(player.position.y-air_height) < 0.02, "Air running actually holds height")
	check(player.run_dust.spawned_total > 0, "Ground running creates original dust particles")
	# At about .9 s, source impulse has expired but braking still carries Ralph.
	await step(player,14,12)
	check(player.current_state == player.WolfState.RUN_AIR and not player.run_active,"Original air run continues beyond .75 s while braking")
	check(absf(player.position.y-air_height) < .02,"Expired impulse does not force gravity before braking threshold")
	await step(player,56,12)
	check(player.current_state == player.WolfState.PIT_FALL, "Air timeout/deceleration triggers original pit animation")
	check(player.animation_player.current_animation == "pit_fall" and player.camera.top_level, "Original STRIKE2 and frozen camera activate")
	check(not player.can_use_inventory(), "Pit cinematic blocks inventory")
	var camera_position = player.camera.global_position
	var body_position = player.position
	await step(player,20)
	check(player.camera.global_position.distance_to(camera_position) < 0.001 and player.position.distance_to(body_position) < 0.001, "Camera and collision body hold while original pose performs fall")
	# Exercise cues across the final authored plunge, not an invented scream.
	var old_time = player.state_time
	player.advance_animation_sound_cues(old_time,5.3)
	var paths = []
	for sound in player.animation_sfx_players:
		if sound.stream:
			paths.append(sound.stream.resource_path)
	check(player.run_data["sounds"]["78"]["path"] in paths and player.run_data["sounds"]["81"]["path"] in paths, "Original STRIKE2 sound IDs 78/81 are dispatched")
	player.state_time = 5.3
	player.animation_player.seek(5.3,true)
	player.apply_legacy_reaction_pose()
	check(player.legacy_skin.last_matrices[1].origin.y < -8, "Original pit animation moves the rendered body down")
	Input.action_release("move_forward")
	await step(player,130)
	check(player.pit_respawn_count == 1 and not player.camera.top_level and player.is_on_floor(), "Death restores normal camera and lands at last safe position")
	Input.action_release("move_forward")
	Input.action_release("run")
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Air/obstacles: ",failures," failures; jump peak=",peak-baseline)
	quit(1 if failures else 0)
