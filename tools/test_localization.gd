extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value, message):
	if not value: failures += 1; printerr(message)
func run():
	GameLocalization.config_path = "res://validation/localization_test_language.cfg"
	GameLocalization.ensure()
	var original = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/daffy.json"))
	for code in ["en","es","it","pt_BR"]:
		check(GameLocalization.select(code,false),"Supported locale "+code)
		SaveFiles.startup_offered = true
		var level = load("res://scenes/levels/Level01.tscn").instantiate()
		root.add_child(level)
		current_scene = level
		level.get_node("DaffyLessons").movies[0].played = true
		level.get_node("PorkyLessons").set_process(false)
		await create_timer(.1).timeout
		var daffy = level.get_node("DaffyLessons")
		check(daffy.data.question == GameLocalization.text("lvl_01",34,0),"Daffy native MLT question "+code)
		check(daffy.data.answers[0].voice_path.contains("/voices/"+code+"/"),"Daffy locale voice "+code)
		check(daffy.data.resource == original.resource,"Shared mechanics identity "+code)
		check(level.get_node("PorkyLessons").data.answers[0].voice_path == GameLocalization.voice_path(59),"Porky BSV voice id "+code)
		var note = level.get_node("SignPostSimple_66") if level.has_node("SignPostSimple_66") else null
		for child in level.get_children():
			if child is OriginalWorldNote:
				var notes = GameLocalization.load_data("res://assets/levels/lvl_01/data/notes.json")
				check(child.text == notes[str(int(child.get_meta("original_resource")))],"Localized note "+code)
		var movie = daffy.movies[4]
		check(movie.data.voice_path.contains("/voices/"+code+"/"),"Localized cinematic voice "+code)
		check(movie.start_sequence(),"Localized movie starts "+code)
		check(movie.data.duration >= movie.voice_player.stream.get_length(),"Recording not truncated "+code)
		movie.finish_sequence(true)
		check(not level.player.cinematic_controls_locked,"Movie releases controls "+code)
		var training = GameLocalization.load_data("res://assets/cinematics/camera_training/lessons.json")
		check(training.voices["80"].path == GameLocalization.voice_path(80),"Level00 shares voice service "+code)
		for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
		level.process_mode = Node.PROCESS_MODE_DISABLED
		level.queue_free()
		await process_frame
	check(not GameLocalization.select("xx",false),"Unknown locale rejected")
	GameLocalization.select("es",false)
	var wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel)
	check(wheel.order == ["en","pt_BR","es","it"],"Original wheel order")
	wheel.turn(1)
	check(await wheel.confirm(false),"Wheel saves selection")
	GameLocalization.initialized = false
	GameLocalization.locale = "es"
	GameLocalization.ensure()
	check(GameLocalization.locale == "it","Language persists separately from checkpoint")
	wheel.music.stop()
	wheel.music.stream = null
	wheel.queue_free()
	await process_frame
	GameLocalization.select("es",false)
	print("Localization banks / notes / voices / cinematic duration / wheel: ",failures," failures")
	quit(1 if failures else 0)
