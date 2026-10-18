extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func picture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	SaveFiles.startup_offered = true
	var background = ColorRect.new()
	background.color = Color.WHITE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade = OriginalRestartFade.new()
	root.add_child(fade)
	check(not fade.iris_enabled,"Non-death transitions retain normal fade by default")
	fade.set_iris(true)
	fade.set_amount(.5)
	check(fade.material.get_shader_parameter("iris_enabled") and fade.material.get_shader_parameter("amount") == .5,"Death aperture receives progress")
	if DisplayServer.get_name() != "headless":
		var image = await picture()
		var center = Vector2i(image.get_width()/2,image.get_height()/2)
		check(image.get_pixelv(center).r > .95 and image.get_pixel(0,0).r < .05,"Half closure keeps center visible while corners are black")
		var radius = Vector2(center).length()*.5
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			var inside = center+Vector2i(direction*(radius-3))
			var outside = center+Vector2i(direction*(radius+3))
			if Rect2i(Vector2i.ZERO,image.get_size()).has_point(outside):
				check(image.get_pixelv(inside).r > .95 and image.get_pixelv(outside).r < .05,"Circular edge has equal pixel radius in each direction")
		image.save_png("res://validation/restart_iris_half.png")
		fade.set_amount(.75)
		image = await picture()
		radius = Vector2(center).length()*.25
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			check(image.get_pixelv(center+Vector2i(direction*(radius-3))).r > .95 and image.get_pixelv(center+Vector2i(direction*(radius+3))).r < .05,"Advanced closure stays circular horizontally and vertically")
		fade.set_amount(1)
		image = await picture()
		check(image.get_pixelv(center).r < .05,"Full closure covers the center before reset")
		fade.set_amount(0)
		image = await picture()
		check(image.get_pixelv(center).r > .95 and image.get_pixel(0,0).r > .95,"Full reopening reveals the whole viewport")
	fade.queue_free()
	background.queue_free()
	await process_frame
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await create_timer(.2).timeout
	var player = lab.player
	player.set_physics_process(false)
	player.set_state(player.WolfState.FALL)
	player.set_state(player.WolfState.PIT_FALL)
	check(player.restart_fade.iris_enabled,"Fatal void selects circular closure")
	player.respawn_at_checkpoint()
	player._physics_process(OriginalRestartFade.DURATION+.01)
	check(not player.restart_fade.iris_enabled and player.restart_fade_remaining == 0,"Respawn finishes reopening and resets transition mode")
	player.set_state(player.WolfState.BLAST_DEATH)
	check(player.restart_fade.iris_enabled,"Explosion death selects circular closure")
	player.respawn_at_checkpoint()
	player.set_state(player.WolfState.SAM_DEATH)
	check(player.restart_fade.iris_enabled,"Sam death selects circular closure")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Death iris pixels / reopen / death modes: ",failures," failures")
	quit(1 if failures else 0)
