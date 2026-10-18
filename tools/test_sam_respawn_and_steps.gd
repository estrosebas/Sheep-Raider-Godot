extends SceneTree
var failures = 0
func _init(): call_deferred("run_tests")
func check(value: bool, message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func run_tests():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	var player: RalphController = level.player
	var checkpoints: OriginalCheckpointManager = level.get_node("Checkpoints")
	var sam: OriginalSam = level.get_node("Sam_43")
	check(player.checkpoint_position != null,"Initial spawn is a fixed respawn, never the last grounded footstep")
	await frames(60)
	player.set_physics_process(false)
	sam.set_physics_process(false)
	checkpoints.set_physics_process(false)
	player.cinematic_controls_locked = false
	sam.initialized = true
	sam.reset_guard()
	# Isolate native zone rules from the configurable shorter port leash.
	sam.chase_leash_distance = 0
	# Inside the wolf hit area, outside Sam's movement territory: do not confuse the boxes.
	player.global_position = Vector3(-50,1,-50)
	sam._enter(sam.State.CHASE,"run1")
	sam.state_elapsed = .3
	sam._physics_process(.016)
	check(sam.state == sam.State.CHASE,"Wolf hit zone, rather than Sam authorized zone, owns chase abandonment")
	player.global_position = Vector3(8.91,.11,12.73)
	sam.state_elapsed = .05
	sam._physics_process(.016)
	check(sam.state == sam.State.CHASE,"Original 200ms grace before testing target outside the hit zone")
	sam.state_elapsed = .2
	sam._physics_process(.016)
	check(sam.state in [sam.State.RETURN_HOME,sam.State.GUARD],"Sam gives up outside authored hit boxes and goes home")
	sam.global_position = Vector3(-46.68,1,-50)
	player.global_position = Vector3(-50,1,-50)
	sam._enter(sam.State.CHASE,"run1")
	sam._physics_process(.016)
	check(sam.state == sam.State.RETURN_HOME and is_zero_approx(sam.velocity.x),"Sam does not pursue beyond authored XZ movement boundary")
	sam.reset_guard()
	player.inventory.state.add({"id":"checkpoint_fixture","class_id":15,"label":"Perfume"})
	for index in range(2):
		var trigger: Dictionary = checkpoints.entries[index]["triggers"][0]
		player.global_position = checkpoints.destination_point(trigger)
		# Trigger centers can be below terrain; use their authored XYZ center for membership.
		var a = trigger["min"]
		var b = trigger["max"]
		player.global_position = GameSpace.original_point(Vector3((a[0]+b[0])*.5,(a[1]+b[1])*.5,(a[2]+b[2])*.5))
		var previous: Vector3 = player.checkpoint_position
		sam.state = sam.State.CHASE
		checkpoints._physics_process(3)
		check(player.checkpoint_position == previous,"No checkpoint update while Sam is red")
		sam.state = sam.State.GUARD
		checkpoints._physics_process(1.9)
		check(player.checkpoint_position == previous,"Checkpoint waits two seconds after chase")
		checkpoints._physics_process(.11)
		var expected = checkpoints.destination_point(checkpoints.entries[index]["wolf"][0])
		check(player.checkpoint_position.distance_to(expected) < .001,"Original destination for checkpoint %d" % index)
		player.safe_position = sam.home
		player.global_position = sam.home
		player.set_state(player.WolfState.SAM_DEATH)
		player.respawn_at_checkpoint()
		check(player.global_position.distance_to(expected) < .001 and player.global_position.distance_to(sam.home) > 5,"Sam death restores checkpoint %d, not death position" % index)
		check(is_equal_approx(player.skeleton.rotation.y,player.checkpoint_facing),"Respawn restores authored facing")
		check(player.inventory.state.count_class(15) == 1,"Original MSG_WOLF_SAVE_RESPAWN commits inventory at the checkpoint")
		player.restart_fade_remaining = 0
	# Test the original PCM stream and active carry animation's half-cycle.
	var sound: AudioStreamWAV = load("res://assets/audio/sfx/sneak_step.wav")
	check(sound.format in [AudioStreamWAV.FORMAT_8_BITS,AudioStreamWAV.FORMAT_16_BITS],"Sneak sample keeps original PCM without lossy compression")
	player.set_state(player.WolfState.SNEAK)
	player.play_anim("sheep_carry_sneak")
	player.handle_audio(.6,true,true)
	check(player.sneak_step_count == 0,"Carry SNEAK2 does not reuse normal sneak cadence")
	player.handle_audio(.41,true,true)
	check(player.sneak_step_count == 1 and is_equal_approx(player.sneak_audio_player.pitch_scale,.5),"Carry sneak starts with original half-speed sample")
	for i in range(1,8):
		player.sneak_audio_player.stop()
		player.handle_audio(1.01,true,true)
		check(is_equal_approx(player.sneak_audio_player.pitch_scale,.5+i/16.0),"Original sneak pitch step %d" % i)
	player.handle_audio(2,true,true)
	check(player.sneak_step_count == 8,"Continuous sneak becomes quiet after eight steps")
	for i in range(3): check(OriginalSamIndicator.source_color(i).is_equal_approx(OriginalSamIndicator.COLORS[i]),"HUD reproduces original packed color %d" % i)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.2).timeout
	level.queue_free()
	await frames(2)
	print("Sam limits / original checkpoints / sneak audio / HUD colors: ",failures," failures")
	quit(1 if failures else 0)
