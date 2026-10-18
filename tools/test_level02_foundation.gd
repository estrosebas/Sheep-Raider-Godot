extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level02.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(.6).timeout
	check(level.manifest.level == "lvl_02" and level.foundation_mode,"Level02 uses reusable foundation with its own data")
	check(level.get_node("Scenery").mesh != null and level.get_node("Collision/CollisionShape3D").shape.get_meta("native_triangles",4435) == 4435,"Editor scenery and original terrain collision are present")
	check(level.player.is_on_floor(),"Native spawn is playable on original terrain")
	var guard = level.get_node("Sam_51")
	var saved_state = guard.state
	guard.state = guard.State.CHASE
	check(is_equal_approx(guard.chase_speed_multiplier,1.15) and is_equal_approx(guard.movement_speed(),12.65),"Level02 overrides Sam chase speed by 15 percent using local port balance")
	guard.state = guard.State.INVESTIGATE
	check(is_equal_approx(guard.movement_speed(),2.0),"Level02 chase tuning leaves investigation speed unchanged")
	guard.state = saved_state
	var default_guard = OriginalSam.new()
	check(is_equal_approx(default_guard.chase_speed_multiplier,1.0),"Shared Sam default stays at original speed for other levels")
	default_guard.free()
	check(guard.rules.resource == 51 and guard.rules_path.contains("lvl_02") and guard.initialized,"Sam uses Level02 zones and completes native lookout initialization")
	check(level.get_node("Flock").sheep.size() == 14,"All fourteen native sheep use shared flock logic")
	check(level.get_node("Checkpoints").entries.size() == 4,"Four native checkpoint entries recovered")
	check(level.get_node("DaffyLessons").data_path.contains("lvl_02") and level.get_node_or_null("PorkyLessons") == null,"Level02 lessons use native level02 data rather than copied level01 triggers")
	var first = level.get_node("Mailbox_66")
	var second = level.get_node("Mailbox_67")
	check(first.items.size() == 1 and first.items[0] is FanItem and second.items.size() == 1 and second.items[0] is PerfumeItem,"Two native mailboxes deliver correct shared item classes")
	check(not first.items[0].available and not second.items[0].available,"Items stay hidden until their own mailbox delivers")
	var note = level.get_node("SignPostSimple_69")
	check(note.text == GameLocalization.text("lvl_02",79,1) and not note.text.is_empty(),"Signs use native level02 Spanish text")
	GameLocalization.select("en",false)
	note.reload_localization()
	check(note.text == GameLocalization.text("lvl_02",79,1),"Sign language change uses level02 bank")
	GameLocalization.select("es",false)
	note.reload_localization()
	var music = level.get_node("BGMPlayer")
	check(music.stream != null and music.playing and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(music.stream.get_length(),1048067.0/16000),"Level02 plays native JAMI Full with exact full-file loop")
	var save = level.get_node("CheckpointSave")
	check(SaveFiles.valid(save.snapshot) and save.snapshot.level == "lvl_02","Level02 snapshot uses shared manual-save schema")
	var saved = save.snapshot.duplicate(true)
	var previous_directory = SaveFiles.directory
	SaveFiles.directory = "user://validation_level02_foundation"
	check(SaveFiles.write_slot(1,saved) == OK,"Manual save writes Level02 to disk")
	var disk = SaveFiles.read_slot(1)
	check(SaveFiles.valid(disk) and disk.level == "lvl_02","Manual save reloads Level02 with checksum and progress")
	SaveFiles.directory = previous_directory
	level.player.global_position += Vector3(2,1,2)
	check(save.restore_checkpoint(saved),"Level02 checkpoint restore works independently of level01 lessons")
	check(level.player.global_position.distance_to(SaveFiles.to_vector(saved.checkpoint.position)) < .1,"Restore returns to native start checkpoint")
	first._deliver(level.player)
	await create_timer(2.0).timeout
	check(first.items[0].available,"Native delivery box releases the fan")
	first._release_camera()
	check(SaveFiles.scene_for_level("lvl_02") == "res://scenes/levels/Level02.tscn","Load menu resolves correct level02 scene")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level02_start.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Level02 original foundation / AI / delivery / language / checkpoints: ",failures," failures")
	quit(1 if failures else 0)
