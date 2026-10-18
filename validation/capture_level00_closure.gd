extends SceneTree
func _init() -> void: call_deferred("capture")
func snapshot(name: String) -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/"+name+".png")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("CameraTraining").enabled = false
	await create_timer(.5).timeout
	var player = level.get_node("Player")
	player.capture_mouse(false)
	player.set_physics_process(false)
	player.global_position = Vector3(-95.42,4.01,-59.86)
	player.skeleton.rotation.y = 0
	player.camera.global_position = player.global_position+Vector3(2,1.3,-3)
	player.camera.look_at(player.global_position+Vector3.UP*.8)
	player.camera.current = true
	await snapshot("level00_clean_hud")
	var help = InputEventKey.new()
	help.physical_keycode = KEY_H
	help.pressed = true
	level._input(help)
	await snapshot("level00_help_h")
	level._input(help)
	player.set_state(player.WolfState.PIT_FALL)
	player.state_time = .9
	player.animation_player.seek(.9,true)
	player.animation_player.advance(0)
	player.apply_legacy_reaction_pose()
	player.step_pit_fall(0)
	await snapshot("level00_pit_original")
	var duration = player.animation_player.get_animation("pit_fall").length+RalphAirRules.RESTART_DELAY
	player.state_time = duration-.5
	player.step_pit_fall(0)
	await snapshot("level00_restart_fade")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	quit()
