extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(.4).timeout
	var cine = level.get_node("LevelCinematics")
	for movie in cine.movies.values():
		if movie.playing: movie.finish_sequence(true)
	# Stop scripts without removing CollisionObject3D from the physics world.
	for node in level.find_children("*","",true,false):
		node.set_process(false)
		node.set_physics_process(false)
	var player = level.player
	player.cinematic_controls_locked = false
	player.launch_controls_locked = false
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	player.camera.make_current()
	for identity in [48,53,54]:
		var button = level.get_node("SensibleButton_%d"%identity)
		var view = button.switch_camera
		check(view!=null,"Gate button has extracted original CamSetup")
		player.global_position = button.global_position+Vector3.UP*.02
		await physics_frame
		await physics_frame
		var saved_rotation = player.camera_pivot.rotation
		button._physics_process(.016)
		check(button.pressed and button.occupants.has(player),"Real player overlap activates button %d"%identity)
		check(view.active and get_root().get_camera_3d()==view.camera,"Pressed button activates original gate camera")
		var data: Dictionary = button.definition.camera
		var expected = GameSpace.original_point(Vector3(data.eye[0],data.eye[1],data.eye[2]))
		check(view.camera.global_position.is_equal_approx(expected),"Camera position matches native WAR CamSetup")
		var centre = Vector3.ZERO
		for resource in button.definition.targets:
			var gate = level.get_node("FallingGate_%d"%int(resource))
			check(gate.opened,"Button still opens gate %d"%int(resource))
			centre += gate.global_position
		centre /= button.definition.targets.size()
		check(view.camera.is_position_in_frustum(centre+Vector3.UP),"Original view includes the sheep passage at gate %d"%identity)
		check(not player.cinematic_controls_locked and not player.launch_controls_locked,"Gate view does not freeze player or sheep simulation")
		if DisplayServer.get_name()!="headless":
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/level05_gate_camera_%d.png"%identity)
		player.camera_pivot.rotation += Vector3(0,.2,0)
		player.global_position += Vector3.RIGHT*3
		await physics_frame
		await physics_frame
		button._physics_process(.016)
		check(not view.active and root.get_camera_3d()==player.camera,"Leaving the button returns free camera")
		check(player.camera_pivot.rotation.is_equal_approx(saved_rotation),"Hidden mouse movement does not change restored free view")
	# A sheep maintaining a button cannot take over the player's distant view.
	var button = level.get_node("SensibleButton_48")
	button.pressed = true
	button.occupants = [level.get_node("Flock").sheep[0]]
	button.switch_camera.update_view()
	check(not button.switch_camera.active,"Sheep-only button cannot steal free camera")
	button.occupants = [player]
	button.switch_camera.update_view()
	player.cinematic_controls_locked = true
	button.switch_camera.update_view()
	check(not button.switch_camera.active,"Conversation interrupts gate shot")
	player.cinematic_controls_locked = false
	button.occupants = []
	button.switch_camera.update_view()
	button.occupants = [player]
	button.switch_camera.update_view()
	player.set_state(player.WolfState.PIT_FALL)
	button.switch_camera.update_view()
	check(not button.switch_camera.active and root.get_camera_3d()==player.camera,"Death retains its own held camera")
	player.respawn_at_checkpoint()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free()
	await process_frame
	print("Level05 original gate cameras / passage framing / release / camera priority: ",failures," failures")
	quit(1 if failures else 0)
