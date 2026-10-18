extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	GameLocalization.config_path = "res://validation/test_language.cfg"
	GameLocalization.select("es",false)
	var wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel)
	await create_timer(6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/original_language_wheel.png")
	wheel.music.stop()
	wheel.music.stream = null
	wheel.queue_free()
	await process_frame
	quit()
