extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.directory = "user://victory_autosave_test_%d"%Time.get_ticks_usec()
	SaveFiles.startup_offered = true; GameLocalization.select("es",false)
	OriginalProgress.restore({})
	var manual = {"version":1,"level":"studio","checkpoint":{"index":-1,"position":[-4.62,.42,-4.55],"facing":0.0,"camera":[0,0,0]},"progress":OriginalProgress.snapshot(),"resume_checkpoint":{}}
	check(SaveFiles.write_slot(1,manual)==OK,"Manual sentinel save created")
	var manual_bytes = FileAccess.get_file_as_bytes(SaveFiles.slot_path(1))
	var last_level
	for number in range(3):
		var identity = "lvl_%02d"%number
		var level = load(SaveFiles.scene_for_level(identity)).instantiate()
		root.add_child(level); current_scene = level
		await create_timer(.3).timeout
		var player: RalphController = level.get_node("Player")
		for guard in get_nodes_in_group("sam_guards"): guard.set_physics_process(false)
		var lessons = level.get_node_or_null("DaffyLessons")
		if lessons:
			lessons.set_process(false)
			for movie in lessons.movies.values():
				if movie.playing: movie.finish_sequence(true)
				movie.played = true
		var goal
		var sheep: OriginalSheep
		var origin: Vector3
		if number==0:
			level.get_node("TutorialIntro").set_process(false)
			level.get_node("CameraTraining").enabled = false
			goal = level.get_node("TutorialFinish"); sheep = goal.sheep
			var p = goal.goal.pos; origin = GameSpace.from_export(Vector3(p[0],p[1],p[2]))
		else:
			var porky = level.get_node_or_null("PorkyLessons")
			if porky: porky.set_process(false)
			goal = level.get_node("Goal_%d"%(115 if number==1 else 110))
			sheep = level.get_node("Flock").sheep[0]; origin = goal.global_position
		goal.set_physics_process(false)
		for other in get_nodes_in_group("sheep_targets"):
			if other is OriginalSheep: other.set_physics_process(false)
		player.global_position = player.respawn_ground_position(origin)
		player.cinematic_controls_locked = false; player.tutorial_movement_locked = false; player.restart_fade_remaining = 0
		player.set_state(player.WolfState.IDLE); player.velocity = Vector3.ZERO
		await physics_frame; await physics_frame
		player.set_physics_process(false)
		sheep.global_position = player.global_position+player.item_facing()*.85
		player.item_actions.set_process(false)
		check(sheep.interact(player),"Level%d: actual original sheep lift starts"%number)
		for i in range(3): if player.item_actions.busy: player.item_actions._process(10)
		check(player.carried_sheep==sheep,"Level%d: sheep is actually attached before goal"%number)
		player.play_anim("sheep_carry_idle"); player.animation_player.advance(0); player.legacy_skin.update_pose(); sheep._process(.016)
		OriginalProgress.award_clock(identity)
		if number==0: goal._physics_process(0)
		else: goal.complete(sheep)
		check(goal.completed and player.item_actions.busy and sheep.carried_by==player,"Level%d: goal starts PUT2A without instant detach"%number)
		check(player.animation_player.current_animation=="sheep_drop","Level%d: native put-down animation selected"%number)
		goal._process(.5)
		check(goal.overlay.color.a==0 and not goal.completion.done,"Level%d: fade/save waits for put-down"%number)
		var before = SaveFiles.read_slot(SaveFiles.AUTO_SLOT)
		check(before.is_empty() or not before.progress.completed_levels.get(identity,false),"Level%d: autosave waits for animation completion"%number)
		var duration = player.animation_player.get_animation("sheep_drop").length
		var final_jump = 0.0
		for step in range(41):
			var position = sheep.global_position
			var attached = sheep.carried_by==player
			player.item_actions._process(duration/40.0+.00001); sheep._process(.016)
			if number==2 and step==26 and DisplayServer.get_name()!="headless":
				var camera = Camera3D.new(); level.add_child(camera)
				camera.position = player.global_position+Vector3(3,2,4)
				camera.look_at(player.global_position+Vector3.UP*.7); camera.current = true
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://validation/victory_sheep_putdown.png")
			if attached and sheep.carried_by==null: final_jump = position.distance_to(sheep.global_position)
		check(sheep.carried_by==null and final_jump<.1,"Level%d: sheep reaches ground smoothly before detaching (%.3fm)"%[number,final_jump])
		for i in range(3): if player.item_actions.busy: player.item_actions._process(10)
		check(goal.completion.done and goal.completion.save_error==OK and player.cinematic_controls_locked,"Level%d: save completes and victory stays locked"%number)
		var automatic = SaveFiles.read_slot(SaveFiles.AUTO_SLOT)
		check(not automatic.is_empty() and automatic.level=="studio" and automatic.progress.completed_levels.get(identity,false) and automatic.progress.clocks.has(identity),"Level%d: autosave contains completed flag and clock"%number)
		check(int(automatic.progress.sheep_extracted)==number+1,"Level%d: completion count accumulates across levels"%number)
		check(FileAccess.get_file_as_bytes(SaveFiles.slot_path(1))==manual_bytes,"Level%d: manual slot remains byte-for-byte unchanged"%number)
		check(not FileAccess.file_exists(SaveFiles.slot_path(2)) and not FileAccess.file_exists(SaveFiles.slot_path(3)),"Level%d: autosave never writes other manual slots"%number)
		goal._process(3.1)
		check(goal.result.visible and goal.result.text.contains("automáticamente"),"Level%d: result confirms automatic save"%number)
		if number<2:
			stop_audio(level); level.queue_free(); await process_frame
		else: last_level = level
	var menu = last_level.get_node("PauseMenu")
	menu.open_menu(); menu.show_page("save")
	check(menu.rows[0].begins_with("Guardado automático") and menu.actions[0]=="auto_info","Autosave is above all manual slots and is not a manual write target")
	var automatic_bytes = FileAccess.get_file_as_bytes(SaveFiles.slot_path(0))
	menu.activate("auto_info")
	check(FileAccess.get_file_as_bytes(SaveFiles.slot_path(0))==automatic_bytes and menu.message.contains("completar"),"Manual selection cannot overwrite the automatic slot")
	menu.show_page("load")
	check(menu.actions[0]=="slot_0","Automatic slot is the first load option")
	menu.activate("slot_0")
	check(menu.page=="choice" and menu.slot==0,"Autosave can be selected in the actual load menu")
	stop_audio(last_level); menu.activate("continue_slot")
	await scene_changed; await create_timer(.3).timeout
	check(current_scene.scene_file_path==SaveFiles.STUDIO_SCENE and current_scene.returned_sheep.size()==3,"Loading autosave enters studio with all captured sheep")
	if DisplayServer.get_name()!="headless":
		var studio_menu = current_scene.get_node("PauseMenu")
		studio_menu.open_menu(); studio_menu.show_page("load")
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/victory_autosave_slot.png")
		studio_menu.close_menu()
	stop_audio(current_scene); current_scene.queue_free(); await process_frame
	OriginalProgress.restore({}); SaveFiles.resume_checkpoint = {}; SaveFiles.pending = {}; SaveFiles.studio_initialized = false
	var record = SaveFiles.initialize_studio()
	check(record.level=="studio" and OriginalProgress.extracted_sheep_count()==3 and OriginalProgress.has_clock("lvl_02"),"Fresh startup chooses latest autosave and restores progress")
	OriginalProgress.restore({})
	print("Level00/01/02 smooth victory / automatic save / manual isolation / real load / fresh startup: ",failures," failures")
	quit(failures)
