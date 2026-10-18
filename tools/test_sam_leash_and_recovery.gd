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
	await create_timer(.5).timeout
	var sam = level.get_node("Sam_43")
	var player = level.player
	sam.initialized = true
	sam.set_physics_process(false)
	sam.set_process(false)
	player.set_physics_process(false)
	sam.reset_guard()
	check(sam.chase_leash_distance == 0,"Default restores original zones without a radial cutoff")
	player.global_position = Vector3(-47,1,-36.5)
	player.current_state = player.WolfState.WALK
	player.velocity = Vector3.RIGHT
	sam.update_alert()
	check(sam.alert_level == 1 and sam.can_detect_player(),"Original orange corner outside 14m detects noisy walking")
	check(not sam.contains(Vector3(7,0,-30),sam.rules.authorized,false),"Native Sam movement stops before the bridge")
	# The optional port leash is tested explicitly; default uses native zones.
	sam.chase_leash_distance = 14
	player.global_position = sam.home+Vector3(15,0,0)
	sam._enter(sam.State.CHASE,"run1")
	sam._physics_process(.016)
	check(sam.state in [sam.State.RETURN_HOME,sam.State.GUARD],"Pursuit stops beyond 14m home leash, before the bridge")
	check(not sam.can_detect_player(),"Player outside leash cannot restart a chase immediately")
	sam._route(sam.home)
	for point in sam.path: check(sam.contains(point,sam.rules.authorized,false),"Return path stays in native authorized area")
	sam.reset_guard()
	player.global_position = sam.global_position+Vector3(.5,0,0)
	sam._catch_player()
	sam.state_elapsed = sam.visual.rig.animations.punch7.duration
	sam._physics_process(.016)
	check(sam.clip == "win" and sam.catch_punched,"Punch transitions into original CATCHDONE/WIN")
	check(player.current_state == player.WolfState.SAM_DEATH,"Recovery still starts Ralph's death/checkpoint sequence")
	sam._process(.96)
	check(sam.audio.playing and sam.audio.stream.resource_path.ends_with("/77.wav"),"Original WIN cue77 plays after the punch")
	check(sam.visual.animation_player.current_animation == "win","Recovery animation evaluates real original WIN")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Sam shorter leash / authorized return / WIN / original sound: ",failures," failures")
	quit(1 if failures else 0)
