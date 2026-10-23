extends SceneTree
var failures = 0
const NativeAudio = preload("res://scripts/audio/original_character_audio.gd")
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func playing(players: Array,path: String) -> bool:
	return players.any(func(voice): return voice.playing and voice.stream.resource_path==path)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level); current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	for i in range(35): await physics_frame
	var sam = level.get_node("Sam_43"); var player = level.player
	sam.set_physics_process(false); sam.set_process(false); player.set_physics_process(false)
	player.restart_fade_remaining = 0; player.cinematic_controls_locked = false
	sam.reset_guard(); sam.initialized = true
	player.global_position = sam.global_position+Vector3(.5,0,0)
	sam._catch_player(0)
	var grab = player.run_data.animations.sam_caught
	check(grab.sound_cues[0].sound_id==29 and is_equal_approx(grab.sound_cues[0].time,2.1),"Original GRAB anticipatory sound29 at2.1s")
	sam._process(2.11)
	var sound29 = player.run_data.sounds["29"].path
	var sound80 = player.run_data.sounds["80"].path
	check(playing(player.animation_sfx_players,sound29),"Locked GRAB animation plays Ralph cue29")
	sam._process(.54)
	check(playing(player.animation_sfx_players,sound80),"GRAB impact80 plays at2.64s")
	check(playing(player.animation_sfx_players,sound29),"Impact does not cut off preceding overlapping sample")
	for voice in player.animation_sfx_players:
		if voice.playing: check(voice.native_falloff,"GRAB uses native audible positional falloff")
	player.cinematic_controls_locked = false
	player.death_animation_override = "sam_hit"; player.set_state(player.WolfState.SAM_DEATH)
	var hit = player.run_data.animations.sam_hit
	check(hit.sound_cues.any(func(cue): return int(cue.sound_id)==81 and is_equal_approx(cue.time,2.06)),"Original HIT impact81 at2.06s")
	player.advance_animation_sound_cues(2.0,2.08)
	check(playing(player.animation_sfx_players,player.run_data.sounds["81"].path),"HIT death plays original impact81")
	# A completed sample must not restart merely because its key is in the past.
	sam.catch_punched = true; sam._enter(sam.State.CATCH,"win")
	sam._process(.95)
	check(sam.audio.playing and sam.audio.stream.resource_path==sam.sounds["77"],"Native victory sound77 fires at.94s")
	var voice = sam.audio; voice.stop()
	sam._process(.03)
	check(not voice.playing,"WIN sound does not restart on later animation frames")
	for sound in sam.sound_players: sound.stop()
	sam.play_original_sound(4); var first = sam.audio
	sam.play_original_sound(5)
	check(first.playing and sam.audio.playing and first!=sam.audio,"Sam supports simultaneous native cues without truncation")
	check(is_equal_approx(NativeAudio.distance_gain(2),1) and is_equal_approx(NativeAudio.distance_gain(26),.5) and is_zero_approx(NativeAudio.distance_gain(50)),"Native 2m..50m linear distance curve")
	sam.audio.update_gain()
	var camera_distance = sam.global_position.distance_to(player.camera.global_position)
	check(is_equal_approx(db_to_linear(sam.audio.volume_db),maxf(.00001,NativeAudio.distance_gain(camera_distance))),"Actual Sam voice applies native camera distance gain")
	for slug in ["lvl_01","lvl_02","lvl_03","lvl_04","lvl_05","lvl_06"]:
		var sounds = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/"+slug+"/data/ai_audio.json"))
		check(sounds.has("77") and ResourceLoader.exists(sounds["77"]),"Every imported Sam has original victory audio")
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Sam native GRAB/HIT sounds / overlap / single cue dispatch / original distance falloff: ",failures," failures")
	quit(failures)
