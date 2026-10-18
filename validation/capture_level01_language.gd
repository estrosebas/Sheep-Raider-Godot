extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	GameLocalization.config_path = "res://validation/capture_language.cfg"
	GameLocalization.select("en",false)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.2).timeout
	var npc = level.get_node("DaffyLessons")
	npc.player.cinematic_controls_locked = true
	npc.say(npc.data.answers[0])
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/level01_english_dialogue.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	quit()
