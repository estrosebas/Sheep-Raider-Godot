extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.3).timeout
	var player = level.player
	player.set_physics_process(false)
	level.get_node("Sam_43").set_physics_process(false)
	player.global_position = Vector3(-33,1.2,-49)
	player.skeleton.rotation.y = 0
	var dynamite = level.get_node("Dynamite_70")
	player.inventory.animate_selection = false
	player.inventory.add_item({"id":dynamite.item_id,"class_id":2,"label":"Dinamita","icon":dynamite.icon_path,"kept":false},dynamite)
	await process_frame
	await process_frame
	check(player.animation_player.current_animation == "held_item_idle","Holding dynamite selects native STAND10 instead of empty-hand idle")
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.animation_player.seek(.3,true)
	player.animation_player.advance(0)
	player.legacy_skin.update_pose()
	dynamite._update_held_position()
	var native_hand = player.skeleton.global_transform*player.legacy_skin.last_matrices[18]
	check(dynamite.global_position.distance_to(native_hand.origin) < .001,"Dynamite follows source MSG_PICKUP joint18")
	check(dynamite.global_position.distance_to((player.skeleton.global_transform*player.legacy_skin.last_matrices[21]).origin) > .1,"Dynamite no longer anchors to opposite hand21")
	var expected = native_hand.basis*GameSpace.EXPORT_TO_GODOT
	check(dynamite.global_basis.x.distance_to(expected.x) < .001 and dynamite.global_basis.y.distance_to(expected.y) < .001,"Attachment preserves original wrist orientation")
	check(dynamite.actor_visual.animation_player.current_animation == "link","Original ADYNAM01 LINK pose is active")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		var camera = Camera3D.new()
		level.add_child(camera)
		camera.global_position = player.global_position+Vector3(2,1.4,3)
		camera.look_at(player.global_position+Vector3.UP*.9)
		camera.current = true
		for i in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/dynamite_original_hand_pose.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Dynamite original joint / LINK / STAND10: ",failures," failures")
	quit(1 if failures else 0)
