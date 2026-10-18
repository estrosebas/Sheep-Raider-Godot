extends SceneTree
func _init(): call_deferred("capture")
func save_image(path: String):
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func frame_actor(camera: Camera3D, actor: Node3D, offset: Vector3 = Vector3(2,1.3,3)):
	camera.global_position = actor.global_position+offset
	camera.look_at(actor.global_position+Vector3.UP*.7)
	camera.current = true
func capture():
	root.size = Vector2i(1280,720)
	SaveFiles.startup_offered = true
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var duck: OriginalLevel01Daffy = level.get_node("DaffyLessons")
	duck.movies[0].played = true
	duck.intro_finished = true
	var pig: OriginalLevel01Porky = level.get_node("PorkyLessons")
	pig.set_process(false)
	await create_timer(.4).timeout
	var player: RalphController = level.player
	player.set_physics_process(false)
	level.get_node("Sam_43").set_physics_process(false)
	var camera = Camera3D.new()
	level.add_child(camera)
	player.hide()
	duck.daffy.global_position = Vector3(-33,1.3,-49)
	duck._process(0)
	duck.on_blast(duck.global_position)
	frame_actor(camera,duck.daffy)
	await save_image("res://validation/level01_lucas_burnt.png")
	player.global_position = duck.daffy.global_position+Vector3(1,0,0)
	duck.interact(player)
	duck.dialogue.elapsed = 2.01
	duck.dialogue.letterbox.timer_ms = OriginalLetterbox.OPEN_MS
	duck.dialogue.set_process(false)
	duck.dialogue._process(0)
	await save_image("res://validation/level01_lucas_burnt_dialogue.png")
	duck._voice_finished()
	player.global_position = Vector3(8.91,.11,12.73)
	player.show()
	player.set_state(player.WolfState.BLAST_DEATH)
	player.animation_player.seek(.5,true)
	player.animation_player.advance(0)
	player.legacy_skin.update_pose()
	frame_actor(camera,player,Vector3(1.5,1,2.5))
	await save_image("res://validation/level01_ralph_burnt.png")
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	player.hide()
	player.global_position = pig.daffy.global_position+Vector3(0,0,1)
	frame_actor(camera,pig.daffy)
	pig.interact(player)
	await save_image("res://validation/level01_porky_original_menu.png")
	var event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	pig._input(event)
	var clock: OriginalTimeKeeper = level.get_node("TimeKeeper_65")
	# Asset inspection outside the narrow secret alcove, capture only.
	clock.global_position = Vector3(-33,1.3,-49)
	frame_actor(camera,clock,Vector3(-2,1,0))
	clock._enter_clip("clock2")
	clock.visual.sample_animation("clock2",.8)
	await save_image("res://validation/level01_secret_clock.png")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await process_frame
	await process_frame
	quit()
