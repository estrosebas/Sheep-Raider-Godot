extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func clean(scene):
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	scene.queue_free()
	await frames(2)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var duck = level.get_node("DaffyLessons")
	duck.movies[0].played = true
	duck.intro_finished = true
	var pig = level.get_node("PorkyLessons")
	pig.with_sheep_played = true
	pig.set_process(false)
	await frames(30)
	var player = level.player
	level.get_node("Sam_43").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	for salad in pig.salads:
		salad.reveal_from_lesson()
		salad.appear_time = -1
		salad.original_visual.idle("stand")
		salad.original_visual.sample_animation("stand",0)
		var lowest = INF
		for surface in salad.original_visual.rig["surfaces"].values():
			for i in range(surface["verts"].size()):
				var vertex = surface["verts"][i]
				var joint = int(surface["bones"][i])
				var point = salad.original_visual.legacy_skin.last_matrices[joint]*salad.original_visual.legacy_skin.inverse_rests[joint]*Vector3(vertex[0],vertex[1],vertex[2])
				lowest = minf(lowest,(salad.original_visual.global_transform*point).y)
		var ground = player.respawn_ground_position(salad.global_position)
		check(absf(lowest-ground.y) < .025,"Animated lettuce leaves must sit on the field floor: "+salad.name)
	player.global_position = pig.daffy.global_position+Vector3(0,0,1.3)
	check(not pig.can_interact(player),"Porky no longer captures E from 1.3m away")
	# A lettuce within the talk radius must still be the action that E performs.
	var salad = pig.salads[0]
	player.global_position = player.respawn_ground_position(pig.daffy.global_position+Vector3(0,0,.75))
	player.velocity = Vector3.ZERO
	await frames(20)
	player.set_physics_process(false)
	salad.global_position = player.global_position+Vector3(.25,0,0)
	check(player.is_on_floor() and pig.can_interact(player),"Fixture reaches Porky and a pickup on walkable ground")
	check(player.inventory.interaction_target() == salad,"Nearby lettuce takes priority over Porky conversation")
	var prompt = player.get_node("ActionPrompt")
	prompt._process(.5)
	check(prompt.target == salad and prompt.text.begins_with("Recoger") and prompt.icon != null,"Top-left HUD describes the same pickup as E with its original icon")
	player.cinematic_controls_locked = true
	prompt._process(.1)
	check(prompt.target == null and prompt.timer == 0,"Cinematic entry hides action prompt")
	player.cinematic_controls_locked = false
	player.inventory.interact_or_use()
	check(player.item_actions.busy and not pig.menu.visible,"E starts lettuce pickup rather than Porky dialogue")
	player.item_actions.cancel()
	var note: OriginalWorldNote
	for node in level.get_children():
		if node is OriginalWorldNote:
			note = node
			break
	check(note != null,"Level01 fixture has its original readable note")
	if note:
		player.global_position = Vector3(8.91,.11,12.73)
		note.global_position = player.global_position+Vector3(.25,0,0)
		player.set_physics_process(true)
		await frames(15)
		player.set_physics_process(false)
		check(player.inventory.interaction_target() == note,"Shared target selection preserves readable notes")
		prompt._process(.5)
		check(prompt.text == "Leer nota","Notes advertise reading rather than collecting")
		player.inventory.interact_or_use()
		check(note.opened and note.ui.visible,"E still reads a note that belongs to both interaction groups")
	for node in level.find_children("*","Label3D",true,false): check(not node.is_visible_in_tree(),"No floating world label in Level01: "+node.name)
	await clean(level)
	for path in ["res://scenes/levels/Level00.tscn","res://scenes/testing/ItemLab.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		current_scene = scene
		await frames(20)
		check(scene.get_node("Player").has_node("ActionPrompt"),"Shared context HUD exists in "+path)
		for node in scene.find_children("*","Label3D",true,false): check(not node.is_visible_in_tree(),"No floating world label in "+path+": "+node.name)
		await clean(scene)
	print("Porky interaction / posed lettuces / shared action HUD: ",failures," failures")
	quit(1 if failures else 0)
