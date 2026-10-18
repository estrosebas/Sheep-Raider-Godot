extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func clean_audio(scene) -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
func run_tests() -> void:
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true # This fixture checks locomotion, not the opening movie.
	await frames(60)
	var player = level.get_node("Player")
	print("Level01 spawn physics: ",player.position," state=",player.current_state," drop=",player.ground_drop()," velocity=",player.velocity)
	check(player.is_on_floor(),"Level01 original spawn settles on recovered terrain")
	check(absf(player.position.x-8.91) < .05 and absf(player.position.z-12.73) < .05,"Source spawn uses the verified x,-y,-z conversion")
	check(level.get_node("Collision/CollisionShape3D").shape.get_faces().size() == 4051*3,"All original 4051 collision triangles are loaded")
	check(level.entities.size() == 99 and level.get_node("OriginalObjectCollisions").get_child_count() > 20,"Original entity placement and model solid boxes are mounted")
	check(level.has_node("Sam_43") and level.has_node("DaffyLevel01_63") and level.has_node("PorkyLevel01_62") and level.has_node("Sheep_44"),"Level01 original actor assets are independent of tutorial assets")
	check(level.get_node("OriginalSky").material_override.render_priority == -128,"Sky preserves far-background rendering")
	var start = player.position
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(player.position.distance_to(start) > 1 and player.current_state != player.WolfState.PIT_FALL,"Ralph can physically explore the Level01 floor")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		for i in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level01_spawn.png")
	clean_audio(level)
	level._unhandled_input(InputEventAction.new()) # No-op unrelated event must not change level.
	var event = InputEventAction.new()
	event.action = "item_lab"
	event.pressed = true
	level._unhandled_input(event)
	await process_frame
	await process_frame
	var lab = current_scene
	check(lab.name == "ItemLab" and lab.has_node("LevelDoor_00") and lab.has_node("LevelDoor_01"),"F8 from Level01 opens lab with both studio doors")
	if lab.name == "ItemLab":
		var actor = lab.get_node("Player")
		actor.set_physics_process(false)
		var door = lab.get_node("LevelDoor_01")
		actor.global_position = door.global_position+Vector3(0,0,-1)
		check(door.can_interact(actor) and door.interact(actor),"Original studio door enters Level01 with E")
		check(door.visual.rig["animations"].has("open") and actor.cinematic_controls_locked,"Door uses APORTE01 original OPEN and locks movement during entry")
		door._process(float(door.visual.rig["animations"]["open"]["duration"])+.6)
		await process_frame
		await process_frame
		check(current_scene.name == "Level01","Door actually routes into Level01 scene")
		clean_audio(current_scene)
		current_scene.queue_free()
	await create_timer(.3).timeout
	print("Level01 original scene/floor/F8/door: ",failures," failures")
	quit(1 if failures else 0)
