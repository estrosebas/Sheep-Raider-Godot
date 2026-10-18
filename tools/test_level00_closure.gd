extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("CameraTraining").enabled = false
	var player = level.get_node("Player")
	var rocket = level.get_node("Rocket_77")
	var inv = player.inventory
	await frames(10)
	check(not level.get_node("HUD").visible and not inv.wheel.help_visible,"Top and bottom legends start hidden")
	var help = InputEventKey.new()
	help.physical_keycode = KEY_H
	help.pressed = true
	level._input(help)
	check(level.get_node("HUD").visible and inv.wheel.help_visible,"H reveals both legends without hiding inventory icons")
	level._input(help)
	check(not level.get_node("HUD").visible and not inv.wheel.help_visible,"H hides both legends again")
	check(not inv.allow_world_placement and not rocket.place_in_world(player),"Level00 rejects manual/direct world placement")
	rocket.owning_inventory = inv
	inv.add_item({"id":rocket.item_id,"class_id":10,"label":"Cohete","kept":false},rocket)
	player.set_physics_process(false)
	player.global_position = Vector3(-230,10,-100)
	check(inv.use_selected(),"Real inventory starts Rocket")
	rocket.mount_remaining = 0
	rocket.flight_time = 2
	rocket.heading = 0
	rocket.flight_speed = 8
	rocket.flight_step(.1,Vector2(1,0),false)
	var initial_bank = player.skeleton.rotation.z
	for i in range(4): rocket.flight_step(.1,Vector2(1,0),false)
	var bank_before = player.skeleton.rotation.z
	rocket.flight_step(.016,Vector2(-1,0),false)
	var bank_after = player.skeleton.rotation.z
	check(initial_bank > 0 and initial_bank < bank_before,"Original angular acceleration gradually builds flight bank")
	check(bank_after > 0 and absf(bank_after-bank_before) <= RocketItem.TURN_ACCELERATION*.016*.5+.0001,"Reversing direction does not instantly flip bank")
	for i in range(65): rocket.flight_step(.016,Vector2(-1,0),false)
	check(player.skeleton.rotation.z < 0,"Held opposite steering eventually banks into the opposite turn")
	check(inv.use_selected() and inv.state.count_class(10) == 0 and inv.equipped_node == null,"Dismount actually consumes selected/equipped Rocket")
	check(rocket.spent and not rocket.available and rocket.holder == null,"Spent Rocket cannot immediately be reused or picked up")
	check(rocket.rocket_visual.animation_player.current_animation == "crash1","Consumed Rocket uses original AFUSEE01 CRASH1")
	rocket.step_disposal(.5)
	check(rocket.crash_sound_played and not rocket.available,"CRASH1 cue 68 fires before original respawn delay")
	rocket.step_disposal(.5)
	check(not rocket.visible and not rocket.available,"Rocket disappears after CRASH1 rather than staying on Ralph")
	rocket.step_disposal(3.0)
	check(rocket.available and not rocket.spent and rocket.global_position.is_equal_approx(rocket.home_position),"Original world object returns home after three-second wait; inventory stays empty")
	check(inv.state.count_class(10) == 0,"Rocket respawn does not grant it back into inventory")
	# Walk/fall into real empty space: no teleport under the map and no y<-30 shortcut.
	player.global_position = Vector3(-450,5,-300)
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	player.floor_probe_warmup = 0
	player.coyote_remaining = 0 # This fixture exercises void death after edge grace expires.
	check(is_inf(player.ground_drop()),"Real floor ray reports absent terrain")
	check(player.check_void_below() and player.current_state == player.WolfState.PIT_FALL,"Ordinary missing ground enters direct DEAD1 fall")
	check(player.animation_player.current_animation == "fall_death" and player.camera.top_level,"Direct fall uses DEAD1 and frozen camera")
	var end = player.direct_fall_impact_time+OriginalRestartFade.DURATION
	player.state_time = end-1.5
	player.step_pit_fall(0)
	check(player.restart_fade.overlay.color.a == 0,"Animation/extra delay remain visible before final fade second")
	player.state_time = end-.5
	player.step_pit_fall(0)
	check(player.restart_fade.overlay.color.a > .4 and player.restart_fade.overlay.color.a < .6,"Original restart gradually fades during its final second")
	player.state_time = end
	player.step_pit_fall(0)
	check(not player.camera.top_level and player.restart_fade.overlay.color.a == 1,"Checkpoint reset happens under full black")
	check(not player.can_use_inventory(),"Fade-in temporarily blocks item actions")
	player._physics_process(.5)
	check(player.restart_fade.overlay.color.a > .4 and player.restart_fade.overlay.color.a < .6,"Original one-second fade-in reveals checkpoint gradually")
	player._physics_process(.5)
	check(player.restart_fade.overlay.color.a == 0 and player.restart_fade_remaining == 0,"Fade completes and releases controls")
	# Strict air budget cannot be extended by tapping Run again.
	player.global_position = Vector3(-450,5,-300)
	player.run_direction = Vector3.BACK
	player.velocity = Vector3.BACK*12
	player.run_active = true
	player.run_tap_timer = 0
	player.set_state(player.WolfState.RUN_AIR)
	player.state_time = RalphAirRules.RUN_AIR_LIMIT+.001
	Input.action_press("run")
	player.step_air_run(.016)
	Input.action_release("run")
	check(player.current_state == player.WolfState.RUN_AIR and not player.run_active,"Original air timeout removes impulse but preserves horizontal braking phase")
	check(Vector2(player.velocity.x,player.velocity.z).length() > player.walk_speed and is_zero_approx(player.velocity.y),"Airborne braking holds height while speed remains above walking")
	for i in range(34):
		player.state_time += .016
		player.step_air_run(.016)
		if player.current_state == player.WolfState.PIT_FALL: break
	check(player.current_state == player.WolfState.PIT_FALL,"Original pit death begins after airborne speed drops below walking speed")
	# Safe ground below an ordinary descent must remain a normal fall/landing.
	player.respawn_at_checkpoint()
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	player.global_position = Vector3(-99.42,8,-59.86)
	player.velocity = Vector3.DOWN
	player.set_state(player.WolfState.FALL)
	check(not player.check_void_below(),"Nearby real floor allows ordinary landing instead of a pit death")
	# Real first/second jump input over void: protect both apex frames.
	player.global_position = Vector3(-99.42,4.01,-59.86)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.IDLE)
	for i in range(8):
		await physics_frame
		player._physics_process(.016)
	Input.action_press("jump")
	await physics_frame
	player._physics_process(.016)
	Input.action_release("jump")
	check(player.current_state == player.WolfState.JUMP,"First jump starts before the void decision")
	var first_takeoff: float = player.jump_origin_y
	player.global_position = Vector3(-450,6,-300)
	for i in range(22):
		await physics_frame
		player._physics_process(.016)
	check(player.current_state == player.WolfState.FALL and player.can_double_jump,"First apex over void leaves second jump available")
	Input.action_press("jump")
	await physics_frame
	player._physics_process(.016)
	Input.action_release("jump")
	check(player.current_state == player.WolfState.JUMP and not player.can_double_jump and player.velocity.y > 0,"Second jump can rescue Ralph after the first apex")
	check(player.jump_origin_y == first_takeoff,"Second jump retains first takeoff height instead of resetting the void threshold")
	for i in range(17):
		await physics_frame
		player._physics_process(.016)
	check(player.current_state == player.WolfState.JUMP,"No pit death before the final part of jump two")
	for i in range(4):
		await physics_frame
		player._physics_process(.016)
	check(player.current_state == player.WolfState.FALL,"Second apex over void continues ordinary FALL, not immediate STRIKE2")
	var takeoff: float = player.jump_origin_y
	for i in range(60):
		if player.current_state == player.WolfState.PIT_FALL: break
		await physics_frame
		player._physics_process(.016)
	check(player.current_state == player.WolfState.PIT_FALL and player.global_position.y < takeoff-1,"Actual descending physics only enters death below the first takeoff margin")
	player.set_state(player.WolfState.FALL)
	player.global_position.y = takeoff-.99
	player.velocity.y = -1
	check(not player.check_void_below(),"First takeoff height protects descent until one metre below it")
	player.global_position.y = takeoff-1.01
	check(player.check_void_below() and player.current_state == player.WolfState.PIT_FALL,"STRIKE2 requires descent below original takeoff minus 1m and no floor")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	print("Level00 closure: ",failures," failures")
	quit(1 if failures else 0)
