extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var butterflies = get_nodes_in_group("ambient_butterflies")
	check(butterflies.size()==3,"Native Level01 has three Butterfly records")
	var player = level.player
	player.global_position = Vector3(1000,0,1000)
	for butterfly in butterflies:
		check(butterfly.definition.directory.ends_with("/185"),"Variants 1/2 swap the placeholder for APAPIL03")
		check(not butterfly.visual.visible,"Butterflies start hidden, not frozen at editor positions")
		butterfly._process(10)
		check(not butterfly.visual.visible,"No butterfly appears when player is outside original zones")
	var first = butterflies[0]
	var box: Dictionary = first.definition.zones[0]
	var centre = GameSpace.original_point((Vector3(box.min[0],box.min[1],box.min[2])+Vector3(box.max[0],box.max[1],box.max[2]))*.5)
	player.global_position = centre
	for butterfly in butterflies:
		for i in range(4): butterfly._process(.016)
		check(butterfly.visual.visible and butterfly.state==butterfly.State.FLUTTER,"Native activation zone starts flutter after three invisible frames")
		var start: Vector3 = butterfly.global_position
		butterfly._process(.25)
		check(butterfly.global_position.distance_to(start)>.1,"Butterfly travels along an orbit instead of staying still")
		check(absf(butterfly.global_position.y-start.y)<=.8*.25+.001,"Native vertical speed is 80 units per second")
		check(butterfly.visual.animation_player.current_animation == ("fly" if int(butterfly.definition.variant)==1 else "fly1"),"Variant uses its native flutter clip")
	if DisplayServer.get_name()!="headless":
		player.camera.global_position = centre+Vector3(0,2,7)
		player.camera.look_at(centre+Vector3.UP*.3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level01_butterflies.png")
	first.global_position = Vector3(1000,0,1000)
	first.start_arc()
	check(first.state==first.State.LEAVE and first.clip=="fly2","Leaving the native zone plays variant departure animation")
	player.global_position = Vector3(1000,0,1000)
	first._process(10)
	check(not first.visual.visible,"Departure finishes and hides the butterfly")
	level.queue_free()
	await process_frame
	print("Level01 native butterflies / variants / zones / flutter / departure: ",failures," failures")
	quit(1 if failures else 0)
