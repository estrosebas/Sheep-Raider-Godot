extends SceneTree
var failures = 0
var menu_service: Node
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func key(code):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
func run():
	menu_service = root.get_node_or_null("LanguageMenu")
	if not menu_service:
		menu_service = load("res://scripts/localization/language_menu.gd").new()
		root.add_child(menu_service)
	GameLocalization.config_path = "res://validation/modal_language_test.cfg"
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.2).timeout
	var player = level.player
	var original_scene = level.get_instance_id()
	var position = player.global_position
	var camera = player.camera.global_transform
	for i in range(3): player.inventory.state.add({"id":"modal_leaf%d"%i,"class_id":3,"label":"Lechuga"})
	var inventory = player.inventory.state.items.duplicate(true)
	key(KEY_F5)
	await process_frame
	check(menu_service.overlay != null and paused,"F5 opens language wheel inside level")
	await create_timer(.5,true).timeout
	check(menu_service.transition.overlay.color.a > .3 and paused,"Entry uses death-style fade while preserving paused level")
	await create_timer(1.6,true).timeout
	if menu_service.wheel:
		var menu = menu_service.wheel
		var first_rotation = menu.wheel.skeleton.get_bone_pose_rotation(1)
		await create_timer(.7,true).timeout
		check(absf(first_rotation.dot(menu.wheel.skeleton.get_bone_pose_rotation(1))) < .999,"Native PUSH rotates wheel during entrance")
		check(menu.has_node("OriginalStudioScenery"),"Original studio background loaded")
		check(menu.music.playing and menu.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Original selection music loops in paused modal")
		check(menu.base.rig.animations.has("push"),"Original support PUSH is present")
		var saved_elapsed = menu.elapsed
		var saved_selection = menu.selected
		var saved_angle = menu.angle
		var flag_points = {"en":Vector3(.64042,.01096,.0788),"pt_BR":Vector3(.01110,-.64042,.0788),"es":Vector3(-.63974,-.01137,.0788),"it":Vector3(-.01096,.63974,.0788)}
		for i in range(menu.order.size()):
			menu.selected = i
			menu.elapsed = 10
			menu.angle = menu.target_angle(i)
			menu._process(0)
			var transform = menu.wheel.global_transform*menu.wheel.legacy_skin.last_matrices[1]*menu.wheel.legacy_skin.inverse_rests[1]
			var point = transform*flag_points[menu.order[i]]
			var center = transform*Vector3(0,0,.0788)
			check(point.y < center.y-.5 and absf(point.x-center.x) < .04,"Flag aligns above bottom pointer: "+menu.order[i])
		menu.selected = saved_selection
		menu.elapsed = saved_elapsed
		menu.angle = saved_angle

		var before = menu.selected
		key(KEY_RIGHT)
		await process_frame
		check(menu.selected != before,"Keyboard reaches embedded viewport")
		menu.selected = 0
		await menu.confirm()
		await create_timer(2.1,true).timeout
		await process_frame
	check(menu_service.overlay == null and not paused,"Confirm resumes same level")
	check(current_scene.get_instance_id() == original_scene,"No scene reload on language change")
	check(player.global_position.distance_to(position) < .02,"Position retained exactly")
	check(player.camera.global_transform.is_equal_approx(camera),"Gameplay camera retained")
	check(player.inventory.state.items.keys() == inventory.keys() and player.inventory.state.count_class(3) == 3,"Inventory identities and quantities retained")
	check(player.inventory.state.items["modal_leaf0"].label == "Lettuce","Inventory labels refresh without losing items")
	check(level.get_node("DaffyLessons").data.question == GameLocalization.text("lvl_01",34,0),"Existing NPC reloads native localized text")
	check(level.get_node("DaffyLessons").data.answers[0].voice_path.contains("/en/"),"Existing NPC reloads voice path")
	key(KEY_F5)
	await process_frame
	await create_timer(2.1,true).timeout
	if menu_service.wheel:
		key(KEY_ESCAPE)
		await create_timer(2.1,true).timeout
		await process_frame
	check(menu_service.overlay == null and not paused,"Escape cancels modal and resumes")
	GameLocalization.select("es",false)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("F5 modal / original wheel / preserve level / live locale: ",failures," failures")
	quit(1 if failures else 0)
