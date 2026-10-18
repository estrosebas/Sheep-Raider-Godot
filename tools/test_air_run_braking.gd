extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func platform(world: Node3D,z: float,length: float) -> void:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6,1,length)
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = Vector3(0,-.5,z)
func step(player) -> void:
	await physics_frame
	player._physics_process(1.0/60)
func run_tests() -> void:
	var world = Node3D.new()
	root.add_child(world)
	platform(world,-10,20) # edge z=0
	platform(world,18,12) # edge z=12: cannot reach it in .75 s at 12 m/s.
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.capture_mouse(false)
	player.position = Vector3(0,.01,-1)
	for i in range(8): await step(player)
	player.set_state(player.WolfState.RUN)
	player.run_active = true
	player.run_direction = Vector3.BACK
	player.velocity = Vector3.BACK*12
	var saw_braking = false
	var crossed = false
	var air_height = INF
	for i in range(120):
		if i > 0 and i%12 == 0: Input.action_press("run")
		await step(player)
		Input.action_release("run")
		if player.current_state == player.WolfState.RUN_AIR and is_inf(air_height): air_height = player.position.y
		if player.current_state == player.WolfState.RUN_AIR and player.state_time > .8:
			saw_braking = true
			check(absf(player.position.y-air_height) < .03,"Horizontal air braking holds the same height as powered air run")
		if player.position.z >= 12 and player.current_state == player.WolfState.RUN:
			crossed = true
			break
		if player.current_state == player.WolfState.PIT_FALL: break
	check(saw_braking and crossed,"Actual 12m gap is crossed during original braking phase, with run resumed on far platform")
	print("12m gap outcome: ",player.position," state=",player.current_state," braking=",saw_braking)
	for node in world.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	world.queue_free()
	await process_frame
	print("Air-run braking/gap: ",failures," failures")
	quit(1 if failures else 0)
