extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	GameLocalization.config_path = "res://validation/ui_polish_test.cfg"
	for code in ["en","es","it","pt_BR"]:
		GameLocalization.select(code,false)
		var menu = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
		root.add_child(menu)
		menu.set_process(false)
		var duration = float(menu.wheel.rig.animations.push.duration)
		menu.elapsed = duration-.001
		menu._process(0)
		var before = menu.wheel.skeleton.get_bone_pose_rotation(1)
		menu._process(.002)
		var after = menu.wheel.skeleton.get_bone_pose_rotation(1)
		check(absf(before.dot(after)) > .99999,"Continuous PUSH-to-selection rotation for "+code)
		check(absf(angle_difference(menu.angle,menu.target_angle(menu.selected))) < .002,"Entry ends on remembered language "+code)
		menu.music.stop(); menu.music.stream = null
		menu.queue_free()
		await process_frame
	GameLocalization.select("es",false)
	var dialogue = OriginalLevelDialogue.new()
	root.add_child(dialogue)
	dialogue.show_line("$10$¡Hola! ¿Cómo estás? $10$Adiós.")
	check(dialogue.label.get_theme_font("font").resource_path == OriginalGameFont.PATH,"Dialogue uses original bitmap font")
	check(dialogue.label.get_theme_font("font").has_char(241) and dialogue.label.get_theme_font("font").has_char(233),"Original font supports Spanish accents")
	check(dialogue.total_duration == 2 and dialogue.pages.size() == 2,"Font change preserves native timed subtitle pages")
	check(not dialogue.label.visible and dialogue.subtitle_canvas.text_label == dialogue.label,"Dialogues render through shared animated atlas canvas")
	check(OriginalSubtitleCanvas.GLYPH_SIZE == Vector2(15,15) and OriginalSubtitleCanvas.LINE_HEIGHT == 17,"Dialogue matches native game-font cell size and line spacing")
	var variants = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/pause/source.json"))["variants"]
	check(OriginalGameFont.animated_glyph(65,.01) == int(variants.Fwd[33]) and OriginalGameFont.animated_glyph(65,.08) == int(variants.Rev[33]) and OriginalGameFont.animated_glyph(65,.15) == 65,"Shared vibration cycles source forward/reverse/base glyphs")
	dialogue.queue_free()
	await process_frame
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	await create_timer(.2).timeout
	var pause = level.get_node("PauseMenu")
	var prompt = level.player.get_node("ActionPrompt")
	pause.open_menu()
	check(not prompt.visible and paused,"Pause hides interaction prompt and pauses gameplay")
	check(pause.get_node("PauseBackgroundFilter").material.shader.resource_path.ends_with("pause_background.gdshader"),"Pause uses scene-preserving blue filter")
	pause.close_menu()
	check(prompt.visible and not paused,"Resume restores interaction prompt")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		var reference = OriginalLevelDialogue.new()
		level.add_child(reference)
		reference.show_line("VERDE : ESTÁS CERCA DE LA ZONA DE SAM.")
		await create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/animated_subtitles.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Wheel continuity / original dialogue font / readable pause: ",failures," failures")
	quit(1 if failures else 0)
