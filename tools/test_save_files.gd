extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func clean_audio(level) -> void:
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
func run_tests() -> void:
	SaveFiles.directory = "user://test_saves_%d" % Time.get_ticks_usec()
	SaveFiles.startup_offered = true
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var player = level.get_node("Player")
	player.set_physics_process(false)
	level.get_node("TutorialIntro").set_process(false)
	var training = level.get_node("CameraTraining")
	training.enabled = false
	var progress = level.get_node("TutorialProgress")
	progress.set_physics_process(false)
	var saves = level.get_node("CheckpointSave")
	var menu = level.get_node("PauseMenu")
	check(saves.snapshot.is_empty(),"No save checkpoint is invented at spawn")
	menu.open_menu()
	menu.show_page("save")
	menu.activate("slot_1")
	check(menu.message.contains("checkpoint") and not FileAccess.file_exists(SaveFiles.slot_path(1)),"Save before first checkpoint is rejected")
	menu.close_menu()
	training.step_index = 16
	training.actor.global_position = Vector3(-92.38,-1.91,.48)
	training.race_finished = true
	var rocket = level.get_node("Rocket_77")
	rocket.owning_inventory = player.inventory
	player.inventory.add_item({"id":rocket.item_id,"class_id":10,"label":"Cohete","kept":false},rocket,false)
	var mailbox = level.get_node("Mailbox_54")
	mailbox.opened = true
	progress.activate_checkpoint(5)
	check(not saves.snapshot.is_empty() and saves.snapshot["inventory"].size() == 1 and saves.snapshot["world"]["mailboxes"][0]["committed"],"Checkpoint snapshot captures committed inventory and delivery")
	check(not FileAccess.file_exists(SaveFiles.slot_path(1)),"Reaching checkpoint never writes an automatic save")
	var original_training_pos = saves.snapshot["training"]["position"].duplicate()
	training.actor.global_position += Vector3(100,0,0)
	player.global_position = Vector3(-450,10,-300)
	player.inventory.state.remove(rocket.item_id)
	menu.open_menu()
	OriginalProgress.award_clock("lvl_01")
	menu.activate("save")
	menu.activate("slot_1")
	var record = SaveFiles.read_slot(1)
	check(record["progress"]["clocks"].has("lvl_01") and not OriginalProgress.timekeeper_unsaved,"Manual slot persists original secret-clock reward without automatic writes")
	check(record["inventory"].size() == 1 and SaveFiles.to_vector(record["training"]["position"]).is_equal_approx(SaveFiles.to_vector(original_training_pos)),"Manual save serializes checkpoint snapshot, not current position/items")
	menu.activate("slot_1")
	check(menu.page == "confirm","Overwriting occupied slot has in-game confirmation")
	menu.close_menu()
	check(SaveFiles.write_slot(2,record) == OK and SaveFiles.read_slot(3).is_empty(),"Three save slots remain independent")
	clean_audio(level)
	level.queue_free()
	await process_frame
	OriginalProgress.restore({})
	SaveFiles.pending = record
	var loaded = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(loaded)
	await process_frame
	await process_frame
	check(OriginalProgress.has_clock("lvl_01") and OriginalProgress.bonus_points == 1,"Fresh scene reload restores clock reward from the manually saved slot")
	var restored = loaded.get_node("Player")
	restored.set_physics_process(false)
	loaded.get_node("TutorialProgress").set_physics_process(false)
	loaded.get_node("CameraTraining").enabled = false
	print("Loaded checkpoint ",loaded.get_node("TutorialProgress").checkpoint_index," at ",restored.global_position," destination=",restored.checkpoint_position)
	check(loaded.get_node("TutorialProgress").checkpoint_index == 5 and restored.global_position.distance_to(restored.checkpoint_position) < .2,"Fresh scene restores original checkpoint destination, not save-time position")
	check(restored.inventory.state.count_class(10) == 1 and restored.inventory.equipped_node == null,"Load restores committed Rocket with empty hands")
	check(loaded.get_node("Mailbox_54").committed and loaded.get_node("Mailbox_54").opened,"Loaded delivered mailbox cannot duplicate contents")
	check(loaded.get_node("CameraTraining").step_index == 16 and loaded.get_node("TutorialIntro").played,"Tutorial stage restores without replaying intro")
	var restored_menu = loaded.get_node("PauseMenu")
	var escape = InputEventAction.new()
	escape.action = "cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(restored_menu.opened and paused,"Real Escape pauses the whole gameplay tree")
	check(restored_menu.last_sound == "confirm" and restored_menu.ui_sound.stream.resource_path.ends_with("confirm.wav"),"Opening pause uses original confirm sound")
	var down = InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	restored_menu._input(down)
	check(restored_menu.last_sound == "move" and restored_menu.ui_sound.stream.resource_path.ends_with("move.wav"),"Pause selection uses original movement sound while paused")
	restored_menu.clock = .01
	check(restored_menu.selected_glyph(65) == 97,"Selected glyph uses original forward A variant")
	restored_menu.clock = .08
	check(restored_menu.selected_glyph(65) == 129,"Selected glyph uses original reverse A variant")
	restored_menu.clock = .15
	check(restored_menu.selected_glyph(65) == 65,"Selected glyph returns to base during third phase")
	var before = loaded.get_node("Rocket_77").rocket_visual.idle_time
	await create_timer(.1,true).timeout
	check(loaded.get_node("Rocket_77").rocket_visual.idle_time == before,"Animation does not advance underneath pause menu")
	restored_menu.show_page("load")
	restored_menu.activate("slot_1")
	check(restored_menu.page == "choice" and restored_menu.actions.has("continue_slot") and restored_menu.actions.has("restart"),"Load offers checkpoint continuation or full restart")
	restored_menu.close_menu()
	var malformed = record.duplicate(true)
	malformed["training"].erase("position")
	check(not SaveFiles.valid(malformed),"Missing nested save fields are rejected safely")
	var file = FileAccess.open(SaveFiles.slot_path(2),FileAccess.WRITE)
	file.store_string("{broken}")
	file.close()
	check(SaveFiles.read_slot(2).is_empty(),"Corrupted JSON is treated as unavailable, without crashing")
	clean_audio(loaded)
	loaded.queue_free()
	await process_frame
	SaveFiles.pending = {"restart":true}
	var fresh = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	await process_frame
	check(fresh.get_node("TutorialProgress").checkpoint_index == -1 and fresh.get_node("Player").inventory.state.items.is_empty() and not fresh.get_node("TutorialIntro").played,"Restart discards live checkpoint/world/inventory but keeps disk save")
	check(not SaveFiles.read_slot(1).is_empty(),"Restart does not overwrite manual save")
	var first_progress = fresh.get_node("TutorialProgress")
	first_progress.activate_checkpoint(0)
	var first_snapshot = fresh.get_node("CheckpointSave").snapshot.duplicate(true)
	check(fresh.get_node("CheckpointSave").restore_checkpoint(first_snapshot),"Checkpoint at intro start also restores safely")
	check(fresh.get_node("CameraTraining").phase == fresh.get_node("CameraTraining").Phase.DIALOGUE and fresh.get_node("CameraTraining").actor.global_position.length() > 1,"First checkpoint positions original Lucas and resumes initial camera lesson")
	SaveFiles.startup_offered = false
	var fresh_menu = fresh.get_node("PauseMenu")
	fresh_menu._startup()
	check(fresh_menu.opened and fresh_menu.page == "load" and paused,"Returning to game offers existing manual saves")
	fresh_menu.close_menu()
	current_scene = fresh
	clean_audio(fresh)
	fresh_menu._reload(record)
	await process_frame
	await process_frame
	await process_frame
	var ui_loaded = current_scene
	check(ui_loaded != fresh and ui_loaded.get_node("TutorialProgress").checkpoint_index == 5,"Actual Cargar path reloads scene and applies saved checkpoint")
	ui_loaded.get_node("CameraTraining").enabled = false
	var loaded_menu = ui_loaded.get_node("PauseMenu")
	loaded_menu.open_menu()
	loaded_menu.activate("restart")
	check(loaded_menu.page == "confirm","Actual Reiniciar path asks in-game confirmation")
	clean_audio(ui_loaded)
	loaded_menu.activate("confirmed")
	await process_frame
	await process_frame
	await process_frame
	var ui_restarted = current_scene
	check(ui_restarted.get_node("TutorialProgress").checkpoint_index == -1 and ui_restarted.get_node("CheckpointSave").snapshot.is_empty(),"Actual restart choice clears checkpoint snapshot")
	ui_restarted.process_mode = Node.PROCESS_MODE_DISABLED
	clean_audio(ui_restarted)
	await create_timer(.3).timeout
	ui_restarted.queue_free()
	await process_frame
	for i in range(1,4):
		for suffix in ["",".tmp",".bak"]:
			var path = SaveFiles.slot_path(i)+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(SaveFiles.directory)
	print("Manual save/pause/checkpoint/fresh restore: ",failures," failures")
	quit(1 if failures else 0)
