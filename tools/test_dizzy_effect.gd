extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await create_timer(.2).timeout
	var player = lab.player
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3.ZERO
	player.set_state(player.WolfState.RUN_CRASH)
	player.animation_player.seek(.2,true)
	player.animation_player.advance(0)
	player.apply_legacy_reaction_pose()
	var effect = player.dizzy_effect
	check(effect.active and effect.is_visible_in_tree(),"Wall crash displays original effect")
	check(effect.visual.rig.animations.turn1.original_name == "turn1" and is_equal_approx(effect.visual.rig.animations.turn1.duration,.8),"Original TURN1 is recovered without invented timing")
	var expected = player.skeleton.global_transform*player.legacy_skin.last_matrices[0]*Vector3(0,1.5,0)
	check(effect.global_position.distance_to(expected) < .0001,"Effect attaches at original root joint and 150-unit height")
	effect.visual.sample_animation("turn1",0)
	var pose = effect.visual.skeleton.get_bone_pose_rotation(1)
	effect.visual.sample_animation("turn1",.4)
	check(absf(pose.dot(effect.visual.skeleton.get_bone_pose_rotation(1))) < .99,"Effect animates rather than remaining static")
	player.global_position += Vector3(2,0,1)
	player.apply_legacy_reaction_pose()
	check(effect.global_position.distance_to(expected+Vector3(2,0,1)) < .0001,"Effect follows Ralph without drifting")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		var camera = Camera3D.new()
		lab.add_child(camera)
		camera.position = player.global_position+Vector3(2.3,2.1,-3)
		camera.look_at(player.global_position+Vector3(0,1,0))
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/original_dizzy_effect.png")
	player.set_state(player.WolfState.IDLE)
	check(not effect.active and not effect.visible,"State exit stops original effect")
	player.set_state(player.WolfState.RUN_CRASH)
	player.interrupt_actions()
	check(not effect.active,"Cinematic interruption clears birds")
	player.set_state(player.WolfState.RUN_CRASH)
	player.respawn_at_checkpoint()
	check(not effect.active,"Checkpoint reset clears birds")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Native dizzy effect / attachment / animation / cleanup: ",failures," failures")
	quit(1 if failures else 0)
