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
	SaveFiles.startup_offered = true
	var scene = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("DaffyLessons").movies[0].played = true
	await frames(10)
	var player = scene.get_node("Player")
	var scrolling = scene.get_node("TextureScroll")
	for material in player.legacy_skin.materials:
		var texture: Texture2D = material.get_shader_parameter("albedo_texture")
		if texture: check(texture.resource_path.begins_with("res://assets/levels/lvl_00/textures/"),"Ralph retains original shared atlas; equal page IDs do not imply equal DAV")
	var cached: ArrayMesh = load("res://assets/levels/lvl_01/scenery.tres")
	check(scene.get_node("Scenery").mesh != cached,"Scrolling uses a local mesh instead of mutating cached scenery")
	for i in range(cached.get_surface_count()):
		var material = cached.surface_get_material(i)
		var texture: Texture2D = material.get_shader_parameter("albedo_texture")
		if texture: check(not texture.resource_path.is_empty(),"Original cached scenery texture remains reloadable from its source path")
	scrolling.advance_rows(8)
	for material in player.legacy_skin.materials:
		var texture: Texture2D = material.get_shader_parameter("albedo_texture")
		if texture: check(not texture is ImageTexture,"Water stepping never changes Ralph's atlas into animated ImageTexture")
	# Actual air movement with Shift pressed after the jump begins.
	player.global_position = Vector3(8.91,.15,12.73)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.IDLE)
	await frames(15)
	Input.action_press("move_right")
	await frames(14)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.current_state == player.WolfState.JUMP,"Normal jump is active before pressing Shift")
	Input.action_press("run")
	await frames(14)
	check(player.current_state == player.WolfState.JUMP,"Shift does not activate a running state during jump")
	check(Vector2(player.velocity.x,player.velocity.z).length() <= player.walk_speed+.01,"Shift does not give 12m/s turbo during jump ascent")
	await frames(8)
	check(Vector2(player.velocity.x,player.velocity.z).length() <= player.walk_speed+.01,"Shift also cannot boost ordinary falling speed")
	Input.action_release("move_right")
	Input.action_release("run")
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	scene.queue_free()
	await process_frame
	var second = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(second)
	await frames(4)
	check(second.get_node("Scenery").mesh != cached,"Reload gets a fresh local scenery mesh")
	var animated = false
	var reloaded: ArrayMesh = second.get_node("Scenery").mesh
	for i in range(reloaded.get_surface_count()):
		var texture: Texture2D = reloaded.surface_get_material(i).get_shader_parameter("albedo_texture")
		if texture is ImageTexture: animated = true
	check(animated,"Reload still binds its own animated atlas after previous level was freed")
	second.process_mode = Node.PROCESS_MODE_DISABLED
	for node in second.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	second.queue_free()
	await process_frame
	print("Texture bank isolation/reload/air Shift: ",failures," failures")
	quit(1 if failures else 0)
