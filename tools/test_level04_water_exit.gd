extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func tick(actor,count: int):
	for i in range(count):
		actor._physics_process(1.0/60)
		await physics_frame
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://level04_water_exit_test_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	var level=load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene=level
	await create_timer(.6).timeout
	var player=level.player
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	level.get_node("LevelCinematics").set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_42").set_physics_process(false); level.get_node("bull_60").set_physics_process(false)
	# Isolate swimming/exit inputs from the independently tested Shark50 AI.
	for shark in get_nodes_in_group("sharks"): shark.set_physics_process(false)
	player.set_physics_process(false); player.cinematic_controls_locked=false; player.restart_fade_remaining=0; player.restart_fade.set_amount(0)
	player.water_motion.reset(player); player.set_state(player.WolfState.FALL)
	player.global_position=Vector3(-50,-4,0); player.velocity=Vector3.ZERO
	await tick(player,3)
	check(player.current_state==player.WolfState.SWIM,"Native04 water enters shared swimming")
	Input.action_press("jump")
	await tick(player,1)
	check(player.current_state==player.WolfState.SWIM,"Deep underwater Space ascends without starting an air jump")
	await tick(player,150)
	check(player.current_state==player.WolfState.SWIM and absf(player.global_position.y+1.9)<.03,"Holding Space reaches the actual native swim surface")
	check(player.water_motion.surface_mode and player.animation_player.current_animation=="swim4" and absf(player.skeleton.rotation.x)<.001,"Reaching surface returns upright and uses native SWIM4 idle even while Space stays held")
	Input.action_press("move_forward"); await tick(player,12); Input.action_release("move_forward")
	check(player.animation_player.current_animation=="swim1" and player.water_motion.surface_mode,"Horizontal surface swimming uses native SWIM1 without requiring a floor collision")
	check(player.animation_sfx_players.any(func(audio): return audio.playing and audio.stream.resource_path=="res://assets/audio/sfx/original_surface_swim.wav"),"SWIM1 plays native sound51 on the surface stroke")
	await tick(player,3)
	check(player.animation_player.current_animation=="swim4" and not player.loop_audio_player.playing,"Stopping at surface returns SWIM4 and stops the submerged stroke loop")
	Input.action_release("jump"); await tick(player,2)
	Input.action_press("run"); await tick(player,30)
	check(player.global_position.y<-2.15 and player.water_motion.surface_mode,"Surface motion persists while diving through the original 20-to-50-unit hysteresis band")
	await tick(player,14)
	check(not player.water_motion.surface_mode and player.animation_player.current_animation=="swim3","Below 50 units the moving swimmer changes to native submerged SWIM3")
	Input.action_release("run"); await tick(player,50)
	check(player.animation_player.current_animation=="swim2","Stopping below surface uses submerged SWIM2 idle")
	Input.action_press("jump"); await tick(player,180)
	check(player.water_motion.surface_mode and player.animation_player.current_animation=="swim4" and absf(player.global_position.y+1.9)<.03,"Ascending restores the surface pose without being stuck in the underwater animation")
	Input.action_release("jump"); await tick(player,2)
	Input.action_press("jump"); await tick(player,2)
	check(player.current_state==player.WolfState.JUMP and player.water_motion.zone.is_empty() and player.can_double_jump,"Fresh Space at surface enters WATER_JUMP and retains double jump")
	Input.action_release("jump")
	await tick(player,9)
	check(player.current_state==player.WolfState.JUMP and player.global_position.y>-.8,"Water box cannot recapture the first ascent")
	Input.action_press("jump"); await tick(player,2); Input.action_release("jump")
	check(player.current_state==player.WolfState.JUMP and not player.can_double_jump,"Second Space applies the normal double jump after exiting water")
	var maximum=player.global_position.y
	for i in range(110):
		await tick(player,1); maximum=maxf(maximum,player.global_position.y)
	check(maximum>.6,"Combined ascent clears banks above the water")
	check(player.current_state==player.WolfState.SWIM and player.water_motion.jump_surface==null,"Falling back into water restores swimming without an endless air exemption")
	Input.action_press("run"); var height=player.global_position.y; await tick(player,40); Input.action_release("run")
	check(player.global_position.y<height-.3,"Shift still dives after jumping back into water")
	player.water_motion.reset(player); player.set_state(player.WolfState.FALL); player.global_position=Vector3(-50,-1.5,0); player.velocity=Vector3.ZERO
	await tick(player,3); Input.action_press("jump"); await tick(player,90); Input.action_release("jump")
	check(absf(player.global_position.y+1.9)<.03,"Low-momentum entry above swim line does not stall when Space is held")
	# A floating platform is a valid bank too. Place a fixture at the native
	# water height, then use real collisions and inputs to jump onto it.
	var bank=StaticBody3D.new(); bank.name="WaterExitBankFixture"; var collision=CollisionShape3D.new(); var box=BoxShape3D.new()
	box.size=Vector3(4,.4,4); collision.shape=box; bank.add_child(collision); level.add_child(bank)
	bank.global_position=Vector3(-50,-.3,-4)
	player.water_motion.reset(player); player.set_state(player.WolfState.FALL); player.global_position=Vector3(-50,-1.9,0); player.velocity=Vector3.ZERO; player.camera_pivot.rotation=Vector3.ZERO
	await tick(player,4)
	Input.action_press("move_forward"); Input.action_press("jump"); await tick(player,2); Input.action_release("jump")
	await tick(player,10)
	Input.action_press("jump"); await tick(player,2); Input.action_release("jump")
	await tick(player,20); Input.action_release("move_forward"); await tick(player,40)
	check(player.is_on_floor() and player.global_position.z<-2 and player.current_state!=player.WolfState.SWIM,"Real capsule exits water and lands on a raised bank")
	var clock=level.get_node("TimeKeeper_67")
	check(clock.visual!=null and clock.state==clock.State.AVAILABLE and clock.physical_root!=null,"04 secret clock is loaded and collidable")
	var collected=false
	for offset in [Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,.7),Vector3(0,0,-.7)]:
		player.water_motion.reset(player); player.set_state(player.WolfState.IDLE); player.global_position=clock.global_position+offset+Vector3.UP*.05; player.velocity=Vector3.ZERO
		await tick(player,15)
		if clock.can_interact(player): collected=clock.interact(player); break
	check(collected and OriginalProgress.has_clock("lvl_04"),"04 clock is physically reachable from its alcove and actually records collection")
	Input.action_release("jump"); Input.action_release("run"); Input.action_release("move_forward")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
	level.queue_free();await process_frame
	print("Level04 surface exit / double jump / reentry / bank landing / original secret clock: ",failures," failures")
	quit(failures)
