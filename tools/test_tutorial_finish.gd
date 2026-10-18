extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	SaveFiles.directory = "user://tutorial_finish_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("CameraTraining").enabled = false
	var player = level.get_node("Player")
	var finish = level.get_node("TutorialFinish")
	var sheep = finish.sheep
	var rocket = level.get_node("Rocket_77")
	await frames(100)
	check(sheep.is_on_floor(),"Final Sheep settles on actual terrain collision")
	print("Sheep grounded: ",sheep.global_position," source=",sheep.definition["pos"])
	var lowest = INF
	for surface in sheep.visual.rig["surfaces"].values():
		for i in range(surface["verts"].size()):
			var v = surface["verts"][i]
			var bone = int(surface["bones"][i])
			var pose = sheep.visual.skeleton.global_transform*sheep.visual.legacy_skin.last_matrices[bone]*sheep.visual.legacy_skin.inverse_rests[bone]
			lowest = minf(lowest,(pose*Vector3(v[0],v[1],v[2])).y)
	print("Sheep visible feet y=",lowest," terrain=",sheep.global_position.y)
	check(absf(lowest-sheep.global_position.y) < .08,"Rendered sheep feet actually meet the terrain, not only its collider")
	rocket.equip_to(player)
	player.animation_player.play("idle")
	player.animation_player.advance(0)
	player.legacy_skin.update_pose()
	rocket._update_held_position()
	var joint = player.skeleton.global_transform*player.legacy_skin.last_matrices[3]
	check((rocket.global_position-joint.origin).dot(player.item_facing()) < 0,"Rocket carry offset is behind the torso, independently of reflected render matrices")
	check(rocket.global_basis.determinant() > 0,"Rocket attachment does not mirror its native mesh a second time")
	player.set_physics_process(false)
	player.global_position = rocket.flight_bounds.end+Vector3(1,0,0)
	check(not rocket.use_item(player)["success"],"FLYBOX rejects ignition outside the original flight region")
	var boundary = rocket.flight_bounds.end
	player.global_position = Vector3(boundary.x-.01,8,0)
	check(rocket.use_item(player)["success"],"Rocket ignites inside the authored flight box")
	rocket.mount_remaining = 0
	rocket.flight_time = 2
	rocket.heading = PI/2
	rocket.flight_speed = 12
	rocket.flight_step(.1,Vector2.ZERO,true)
	check(rocket.contains_flight_point(player.global_position),"Forward flight is clamped before crossing FLYBOX")
	player.global_position = Vector3(-230,10,-100)
	rocket.heading = 0
	player.velocity = Vector3.ZERO
	rocket.flight_step(.1,Vector2(1,1),false)
	check(rocket.heading < 0 and player.velocity.y > 0,"Only Y is inverted: D preserves normal steering and S climbs")
	check(player.skeleton.rotation.x < 0 and player.skeleton.rotation.z > 0,"Original rocket flight pitches upward and banks into the turn")
	player.velocity.y = 0
	rocket.flight_step(.1,Vector2(-1,-1),false)
	check(player.velocity.y < 0,"Inverted W input descends")
	check(player.skeleton.rotation.x > 0,"Original rocket flight pitches downward when descending")
	rocket.finish_flight()
	check(is_zero_approx(player.skeleton.rotation.x) and is_zero_approx(player.skeleton.rotation.z),"Leaving rocket flight restores upright ground/fall orientation")
	rocket.store()
	player.inventory.equipped_node = null
	player.active_rocket = null
	player.set_state(player.WolfState.IDLE)
	player.set_physics_process(true)
	player.global_position = sheep.global_position+Vector3(0,0,1)
	player.velocity = Vector3.ZERO
	player.skeleton.rotation.y = PI
	await frames(45)
	print("Before lift: player=",player.global_position," sheep=",sheep.global_position," ground=",player.is_on_floor()," controls=",player.can_use_item()," facing=",player.item_facing())
	check(sheep.can_interact(player) and sheep.interact(player),"Grounded final Sheep can be lifted with E")
	await frames(100)
	check(sheep.carried_by == player and player.carried_sheep == sheep,"TAKE2A/B attaches Sheep to original joint 18")
	check(not player.inventory.open_wheel(),"Carrying sheep blocks item wheel")
	check(sheep.interact(player),"E starts original PUT2A/B")
	await frames(65)
	check(sheep.carried_by == null and sheep.is_on_floor(),"Dropped Sheep returns to grounded physics")
	var p = finish.goal["pos"]
	var goal_position = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
	player.global_position = goal_position
	player.velocity = Vector3.ZERO
	await frames(10)
	check(not finish.completed,"Ralph alone at goal cannot win")
	player.global_position = sheep.global_position+Vector3(0,0,1)
	player.skeleton.rotation.y = PI
	await frames(12)
	check(sheep.interact(player),"Sheep can be carried toward Goal after dropping")
	await frames(100)
	player.global_position.y = (player.checkpoint_position.y if player.checkpoint_position != null else player.safe_position.y)-31
	sheep.move_carrier(.016)
	check(player.carried_sheep == null and sheep.global_position.is_equal_approx(sheep.home),"Falling into a pit while carrying respawns Ralph and restores Sheep")
	check(player.current_state == player.WolfState.PIT_FALL,"A carried-sheep pit uses original STRIKE2 before respawn")
	await frames(600)
	player.global_position = sheep.global_position+Vector3(0,0,1)
	player.velocity = Vector3.ZERO
	player.skeleton.rotation.y = PI
	await frames(45)
	check(sheep.interact(player),"Sheep remains usable after pit respawn")
	await frames(100)
	player.camera_pivot.rotation.y = 0
	Input.action_press("move_right")
	await frames(450)
	Input.action_release("move_right")
	print("Walked Sheep into Goal: ",player.global_position)
	check(finish.completed and player.cinematic_controls_locked,"Ralph and Sheep together trigger original Goal 122 and victory lock")
	for i in range(180):
		if not player.item_actions.busy: break
		await physics_frame
	check(finish.completion.done and not sheep.carried_by,"Victory puts sheep down before saving and fading")
	finish._process(3.1)
	check(finish.result.visible and finish.overlay.color.a == 1,"Original three-second exit fade reaches completion screen")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	print("Flight bounds/back attachment/final Sheep/Goal: ",failures," failures")
	quit(1 if failures else 0)
