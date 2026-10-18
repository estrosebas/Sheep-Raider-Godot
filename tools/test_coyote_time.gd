extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func step(player, count: int) -> void:
	for i in range(count):
		await physics_frame
		player._physics_process(1.0/60)
func run_tests() -> void:
	var world = Node3D.new()
	root.add_child(world)
	var floor = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4,1,4)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)
	floor.position.y = -.5
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.capture_mouse(false)
	player.position = Vector3(0,.01,0)
	await step(player,8)
	check(player.is_on_floor(),"Fixture stands on real platform")
	player.position.x = 3
	await step(player,5)
	check(not player.is_on_floor() and player.coyote_remaining > 0 and player.current_state != player.WolfState.PIT_FALL,"Walking off platform preserves a brief first-jump opportunity over void")
	Input.action_press("jump")
	await step(player,1)
	Input.action_release("jump")
	check(player.current_state == player.WolfState.JUMP and player.current_jump_height == player.JUMP_HEIGHT*player.jump_height_scale,"Late edge jump uses full first-jump height")
	check(player.can_double_jump and player.coyote_remaining == 0,"Coyote jump consumes grace, preserves second jump")
	await step(player,9)
	Input.action_press("jump")
	await step(player,1)
	Input.action_release("jump")
	check(not player.can_double_jump and player.current_jump_height == player.DOUBLE_JUMP_HEIGHT*player.jump_height_scale,"Second jump remains available after coyote jump")
	await step(player,75)
	check(player.current_state == player.WolfState.PIT_FALL,"Coyote time does not allow indefinite survival over void")
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	player.position = Vector3(0,.01,0)
	await step(player,8)
	player.position.x = 3
	await step(player,16)
	check(player.current_state == player.WolfState.PIT_FALL,"An unused coyote window expires normally")
	player.respawn_at_checkpoint()
	check(player.coyote_remaining == 0,"Respawn clears stale edge grace")
	for node in world.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	world.queue_free()
	await process_frame
	print("Coyote time: ",failures," failures")
	quit(1 if failures else 0)
