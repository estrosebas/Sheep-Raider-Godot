extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool,message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func press(npc: OriginalNpcConversation, key: Key):
	var event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	npc._input(event)
func black(actor) -> bool:
	for material in actor.legacy_skin.materials:
		if not is_equal_approx(material.get_shader_parameter("original_tint_amount"),1): return false
	return true
func run_tests():
	OriginalProgress.restore({})
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var duck: OriginalLevel01Daffy = level.get_node("DaffyLessons")
	duck.movies[0].played = true
	duck.intro_finished = true
	var pig: OriginalLevel01Porky = level.get_node("PorkyLessons")
	var player: RalphController = level.player
	var bomb: DynamiteItem = level.get_node("Dynamite_%d" % int(JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_01/data/mechanics.json"))["dynamite"]["res"]))
	var clock: OriginalTimeKeeper = level.get_node("TimeKeeper_65")
	await frames(60)
	player.set_physics_process(false)
	level.get_node("Sam_43").set_physics_process(false)
	pig.set_process(false)
	check(pig.salads.size() == 8 and not pig.salads[0].available and not pig.salads[0].visible,"Porky hides all eight original lettuces before teaching")
	player.global_position = duck.daffy.global_position+Vector3(5,0,0)
	bomb.ignite(duck.daffy.global_position)
	bomb.explode()
	check(duck.burnt and black(duck.daffy),"Actual dynamite blast blackens Lucas using full original tint")
	player.global_position = duck.daffy.global_position+Vector3(1,0,0)
	check(duck.interact(player),"Burnt Lucas accepts interaction")
	check(duck.voice.stream.resource_path.ends_with("cin_lvl_0105.wav") and duck.speaking and not duck.menu.visible,"Burnt Lucas plays original joke/punishment voice instead of normal menu")
	print("Lucas burnt voice length: ",duck.voice.stream.get_length()," text time: ",duck.dialogue.total_duration)
	check(is_equal_approx(duck.dialogue.total_duration,41.6),"Original timed Lucas line includes all page markers")
	check(not duck.speech_skippable and player.cinematic_controls_locked,"Lucas's original punishment holds control until the voice ends")
	press(duck,KEY_E)
	check(duck.speaking,"E does not bypass original Lucas punishment")
	duck.voice.seek(maxf(0,duck.voice.stream.get_length()-.05))
	await create_timer(.25).timeout
	check(duck.speaking and player.cinematic_controls_locked,"Voice completion alone does not skip the original remaining timed subtitle pages")
	duck.dialogue.elapsed = duck.dialogue.total_duration-.05
	duck.dialogue._process(.1)
	check(not duck.speaking and not player.cinematic_controls_locked,"End of original burnt timed dialogue restores control")
	check(duck.interact(player) and duck.menu.visible,"Lucas's burnt line is once-only, next interaction opens normal choices")
	press(duck,KEY_ESCAPE)
	# Ralph's original EXPLOS1 must be black throughout the death, cleared on respawn.
	player.global_position = Vector3(8.91,.11,12.73)
	bomb.ignite(player.global_position)
	bomb.explode()
	check(player.current_state == player.WolfState.BLAST_DEATH and black(player),"Actual blast plays EXPLOS1 with black Ralph")
	player.respawn_at_checkpoint()
	check(not black(player) and not duck.burnt,"Respawn clears Ralph's and Lucas's original burned tint")
	player.restart_fade_remaining = 0
	# Porky's three original question/answer voices plus burnt reaction.
	player.global_position = pig.daffy.global_position+Vector3(0,0,1)
	for index in range(3):
		check(pig.interact(player),"Porky opens original three-topic menu")
		pig.selected = index
		press(pig,KEY_E)
		check(pig.speaking and pig.voice.stream.resource_path == pig.data["answers"][index]["voice_path"],"Porky's original answer voice %d" % (59+index))
		check(not pig.dialogue.label.text.contains("$"),"Porky uses cleaned original text and letterbox subtitles")
		press(pig,KEY_E)
		check(not player.cinematic_controls_locked,"Closing Porky answer releases control")
	player.global_position = pig.daffy.global_position+Vector3(5,0,0)
	bomb.ignite(pig.daffy.global_position)
	bomb.explode()
	check(pig.burnt and black(pig.daffy),"Porky's original KILL_GENERIC tint is shared")
	player.global_position = pig.daffy.global_position+Vector3(0,0,1)
	check(pig.interact(player) and pig.voice.stream.resource_path.ends_with("cintxtex_lvl_0106.wav"),"Porky's original burnt answer voice65")
	press(pig,KEY_E)
	# Trigger CIN02 without sheep, then CIN03 with the actual nearby sheep.
	for sheep in level.get_node("Flock").sheep:
		sheep.set_physics_process(false)
		sheep.global_position = sheep.home
	player.global_position = Vector3(15.62,.07,-56.73)
	pig.try_lesson()
	check(pig.without_sheep_played and pig.active_movie == duck.movies[2],"Original activation box starts CIN02 when Ralph has no nearby sheep")
	duck.movies[2].finish_sequence(true)
	check(not pig.salads[0].available,"Without-sheep cinematic leaves lettuces hidden")
	var sheep: OriginalSheep = level.get_node("Sheep_52")
	player.global_position = Vector3(15.62,.07,-56.73)
	sheep.global_position = player.global_position+Vector3(0,0,1)
	var sheep_entry = sheep.global_position
	pig.try_lesson()
	check(pig.with_sheep_played and pig.active_movie == duck.movies[3] and duck.movies[3].world_actors["2:59"] == sheep,"CIN03 binds the actual nearby sheep rather than a fixed imported sheep")
	pig._process(.011)
	check(pig.salads[0].available and not pig.salads[1].available,"Original ten-ms delay reveals the first lettuce")
	pig._process(.5)
	check(pig.salads[1].available and not pig.salads[2].available,"Original 500ms spacing reveals subsequent lettuces")
	duck.movies[3].finish_sequence(true)
	check(sheep.is_visible_in_tree() and sheep.visual.is_visible_in_tree() and Vector2(sheep.global_position.x-sheep_entry.x,sheep.global_position.z-sheep_entry.z).length() < .01,"Skipping Porky's lesson leaves the real sheep visible at the farm entrance")
	pig.with_sheep_played = false
	duck.movies[3].played = false
	player.global_position = Vector3(15.62,.07,-56.73)
	pig.try_lesson()
	check(pig.active_movie == duck.movies[3],"Sheep lesson can exercise its normal completion path")
	duck.movies[3].finish_sequence(false)
	check(sheep.is_visible_in_tree() and sheep.visual.is_visible_in_tree() and Vector2(sheep.global_position.x-sheep_entry.x,sheep.global_position.z-sheep_entry.z).length() < .01,"Normal Porky lesson completion leaves the real sheep visible at the farm entrance")
	for salad in pig.salads: check(salad.available and salad.visible and salad.original_visual.rig["animations"].has("appear"),"Ending/skipping sheep lesson reveals remaining original APPEAR lettuces")
	# Use the clock with Ralph on its ground; award once, run all stages, keep across death.
	player.global_position = clock.global_position+Vector3(0,0,.7)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(30)
	check(clock.interact(player),"Actual E-equivalent clock interaction starts Ralph CLOCK2")
	check(player.animation_player.current_animation == "timekeeper_use" and clock.clip == "clock2" and OriginalProgress.bonus_points == 1,"TimeKeeper awards one bonus and starts both original CLOCK2 animations")
	await frames(80)
	check(clock.clip == "clock3" and clock.audio.playing and not player.cinematic_controls_locked,"CLOCK3 rings original sound248 while Ralph regains control")
	await frames(180)
	check(clock.state == clock.State.COLLECTED and clock.visual.idle_clip == "clock1" and not clock.audio.playing,"CLOCK4 finishes, ringing stops, original collected clock stays visible")
	check(not clock.interact(player) and OriginalProgress.bonus_count == 1,"Collected clock cannot award twice")
	player.respawn_at_checkpoint()
	check(OriginalProgress.has_clock("lvl_01") and clock.state == clock.State.COLLECTED,"Timekeeper survives death, as original Reset is empty")
	var record = OriginalProgress.snapshot()
	OriginalProgress.restore({})
	OriginalProgress.restore(record)
	check(OriginalProgress.has_clock("lvl_01") and OriginalProgress.bonus_points == 1 and not OriginalProgress.timekeeper_unsaved,"Bonus progress can round-trip through manual save metadata")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await frames(2)
	OriginalProgress.restore({})
	print("Original Lucas/Ralph blast / Porky / lettuce lesson / secret clock: ",failures," failures")
	quit(1 if failures else 0)
