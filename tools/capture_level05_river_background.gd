extends SceneTree
# Two real renders of identical original geometry: generic old backdrop versus
# native WAR clear color. No terrain/collision/texture is added to the river.
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://river_bg_capture_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level05.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(10): await physics_frame
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	level.player.get_node("ActionPrompt").hide()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("BGMPlayer").stop()
	var camera = Camera3D.new(); level.add_child(camera)
	camera.fov = 55
	camera.position = Vector3(16,16,17); camera.look_at(Vector3(1,-1,-3)); camera.current = true
	var environment: Environment = level.get_node("WorldEnvironment").environment
	var original = environment.background_color
	environment.background_color = Color8(24,20,32)
	await capture("res://validation/level05_river_material_before.png")
	environment.background_color = original
	await capture("res://validation/level05_river_material_after.png")
	# Also record the whole-map view to expose all backdrop openings.
	camera.position = Vector3(43,55,48); camera.look_at(Vector3(-10,0,-20)); camera.fov = 75
	await capture("res://validation/level05_river_background_overview.png")
	print("Native river background: ",original.to_html(false))
	level.queue_free(); await process_frame; quit()
func capture(path: String):
	for i in range(8): await process_frame; await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(path)
	print(path," ",result)
