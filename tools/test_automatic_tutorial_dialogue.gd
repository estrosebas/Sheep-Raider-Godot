extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://automatic_subtitles_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level00.tscn").instantiate(); root.add_child(level); current_scene = level
	await process_frame
	var training = level.get_node("CameraTraining"); var director = level.get_node("TutorialIntro")
	director.set_process(false); training.set_process(false); training.set_physics_process(false)
	if director.playing: director.finish_sequence(true)
	if director.playing: director.finish_sequence(true)
	training._show_dialogue(4)
	check(training.dialogue is OriginalLevelDialogue and training.dialogue.automatic and training.hint.text.is_empty(),"Level00 shares automatic voiced subtitles with later levels and has no compulsory E footer")
	check(training.voice_pending and training.dialogue.wait_for_voice and training.dialogue.elapsed==0,"Subtitle clock waits for opening bars and voice")
	training.dialogue._process(2)
	check(training.dialogue.elapsed==0,"Opening the bars does not consume first subtitle timing")
	training.letterbox._process(1.5); training._process(.016)
	check(training.voice.playing and not training.dialogue.wait_for_voice,"Native voice starts once the same shared bars finish opening")
	training.voice.play(3.9)
	await create_timer(.15).timeout
	training.dialogue._process(0); training._update_page()
	check(training.dialogue.current_page>=2 and training.body.text.contains("Espacio"),"Original numeric MLT tags switch subtitles from real voice playback without E")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level00_automatic_subtitles.png")
	# Let a real short lesson finish naturally: it must start Lucas's movement.
	training.set_process(true); training.continue_after_camera = false
	training._show_dialogue(0); training.letterbox.timer_ms = 1500
	await create_timer(7.8).timeout
	check(training.phase!=training.Phase.DIALOGUE or training.step_index!=0,"Actual lesson completion releases its dialogue and advances the original route automatically")
	training.set_process(false)
	training._show_dialogue(2)
	check(not training.voice_pending and not training.voice.playing,"Adapted first-person instruction still avoids contradictory original voice91")
	training.dialogue._process(training.dialogue.total_duration+.1)
	check(training.phase==training.Phase.MOVING,"Silent adapted instruction also advances after readable page timing")
	training._show_dialogue(16)
	check(training.dialogue.pages.size()>2 and training.dialogue.total_duration==training.voice.stream.get_length(),"Long PC-control explanation is paced over the localized voice")
	for page in training.dialogue.pages: check(OriginalTextBox.wrap_text(page,29).size()<=2,"Automatic adapted pages fit the original subtitle band")
	for locale in ["en","pt_BR","it","es"]:
		GameLocalization.select(locale,false); training.reload_localization()
		check(training.voice.stream.resource_path.contains("/voices/"+locale+"/") and not training.hint.text.contains("continuar"),"Automatic tutorial text and voice localization: "+locale)
	# CIN03 and its speech run together. Completing the speech must not cut
	# off the platform demonstration; the route resumes after its camera ends.
	training.step_index = 14; training._stage_reached()
	training.letterbox.timer_ms = 1500; training._process(.016)
	check(training.phase==training.Phase.DEMO and training.voice.playing,"Platform demonstration starts its speech while the cinematic is playing")
	training.voice.stop(); training.dialogue._process(training.dialogue.total_duration+.1)
	check(training.dialogue.completed and training.phase==training.Phase.DEMO,"Finishing subtitles preserves the ongoing platform demonstration")
	director.finish_sequence(false); await process_frame
	check(training.phase!=training.Phase.DIALOGUE and training.phase!=training.Phase.DEMO,"Completed platform speech resumes the route when its cinematic ends without E")
	training._show_dialogue(4); training.dialogue_time = .5
	var skip = InputEventKey.new(); skip.physical_keycode = KEY_E; skip.pressed = true
	training._unhandled_input(skip)
	check(training.phase==training.Phase.MOVING and not training.dialogue.card.visible and not training.voice_pending,"E remains an optional skip and closes the shared subtitles")
	training.dialogue.close(); training.voice.stop()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level00 shared automatic subtitles / original audio timing / no E gate / adapted PC pages / localization: ",failures," failures")
	quit(failures)
