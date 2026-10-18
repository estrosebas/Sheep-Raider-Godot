extends SceneTree

const State = preload("res://scripts/inventory/inventory_state.gd")
const Steps = preload("res://scripts/player/ralph_step_rules.gd")
var failures = 0
var equipped_events = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func item(id: String, kind: int) -> Dictionary:
	return {"id": id, "class_id": kind, "label": "Objeto %d" % kind}

func key(action: String, pressed: bool) -> void:
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var state = State.new()
	check(not state.add(item("bad", 200)), "Reject invalid class without corrupting lists")
	check(state.add(item("rocket-a", 10)), "Add original rocket class")
	check(not state.add(item("rocket-a", 10)), "A world object cannot be collected twice")
	check(state.add(item("rocket-b", 10)), "Stack independent objects of one class")
	state.select_class(10)
	check(state.count_class(10) == 2 and state.get_selected_object()["id"] == "rocket-b", "Push-front/count/get semantics")
	state.clear_selection()
	state.select_next()
	check(state.selected_class == State.NONE and state.wheel_side == 1, "Single-class wheel first forward press only turns")
	state.select_next()
	check(state.selected_class == 10, "Single-class second forward press selects item")
	state.select_next()
	check(state.selected_class == State.NONE, "Empty hands remains a carousel stop")
	state.select_prev()
	check(state.selected_class == 10, "Reverse single-class selection")
	state.add(item("later", 50))
	state.clear_selection()
	state.select_next()
	check(state.selected_class == 10, "Classes sort by original numeric id")
	state.select_next()
	check(state.selected_class == 50, "Next occupied class skips gaps")
	state.select_next()
	check(state.selected_class == State.NONE, "End of sorted classes enters empty hands")
	state.select_prev()
	check(state.selected_class == 50, "Reverse from empty hands visits last class")
	state.commit_at_checkpoint()
	state.add(item("uncommitted", 15))
	check(state.drop_uncommitted().size() == 1 and state.items.size() == 3, "Checkpoint rollback retains committed objects")
	state.select_class(50)
	state.remove("later")
	check(state.selected_class == State.NONE, "Removing last selected class clears hands")
	state.reset()
	check(state.items.is_empty() and state.selected_class == State.NONE, "Per-level reset")

	for n in range(8):
		var cue = Steps.sneak_step(n)
		check(is_equal_approx(cue["pitch"], 0.5 + n * 0.0625), "Exact fixed-point sneak pitch %d" % n)
		check(is_equal_approx(cue["volume"], float(int((8 - n) * 255.0 / 8.0)) / 255), "Exact integer sneak volume %d" % n)
	check(Steps.sneak_step(8).is_empty(), "Sneak becomes silent after eight steps")
	check(is_equal_approx(Steps.step_interval(0.62), 0.31), "Two steps per actual animation cycle")

	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.capture_mouse(false)
	var inv = player.inventory
	inv.equipped.connect(func(_entry): equipped_events += 1)
	var rocket = level.get_node("Rocket_77")
	player.global_position = rocket.global_position
	# Full mailbox delivery/pickup is exercised by test_mailbox.
	inv.add_item({"id":rocket.item_id,"class_id":10,"label":"Cohete"},rocket)
	check(inv.state.count_class(10) == 1 and not rocket.available and rocket.holder == player and rocket.global_position != rocket.home_position, "Inventory fixture equips Rocket on the original back attachment")
	check(not rocket.collect(inv), "Hidden pickup cannot be collected again")
	inv.state.add(item("fixture", 50))
	await key("inventory", true)
	check(inv.wheel_open and player.inventory_controls_locked, "Real Tab event opens wheel and locks controls")
	await key("move_right", true)
	await process_frame
	check(inv.state.selected_class == 10, "Real movement input selects rather than moving")
	await key("jump", true)
	player._physics_process(1.0 / 60.0)
	check(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z) and player.current_state != player.WolfState.JUMP, "Wheel blocks movement/jump in physics while gravity continues")
	await key("jump", false)
	check(not inv.turn(1), "Cannot turn again during wheel animation")
	await key("move_right", false)
	await key("inventory", false)
	check(not inv.wheel_open and not player.inventory_controls_locked and inv.equipped_id == "lvl_00:77", "Tab release equips and unlocks player")
	await key("inventory", true)
	await key("cancel", true)
	await key("cancel", false)
	await key("inventory", false)
	check(inv.state.selected_class == 10 and not inv.wheel_open, "Escape cancels and restores equipped selection")
	check(inv.use_selected() and player.active_rocket == rocket and inv.state.count_class(10) == 1, "Shared rocket starts flight without consuming inventory")
	check(inv.use_selected() and player.active_rocket == null, "Second use stops flight")
	check(inv.state.count_class(10) == 0,"Second use consumes the original Rocket")
	rocket.restore()
	check(inv.add_item({"id":rocket.item_id,"class_id":10,"label":"Cohete","kept":false},rocket),"Recovered Rocket fixture is collected again for generic use-contract checks")
	inv.state.select_class(50)
	inv.equipped.emit(inv.state.get_selected_object())
	check(not inv.use_selected(), "Unimplemented catalog classes retain inventory")
	inv.state.select_class(10)
	inv.equipped.emit(inv.state.get_selected_object())
	inv.register_use_handler(10, func(_entry, _actor): return {"success": false, "consumed": true})
	check(not inv.use_selected() and inv.state.count_class(10) == 1, "Rejected use cannot consume an object")
	inv.register_use_handler(10, func(_entry, _actor): return {"success": true, "consumed": false})
	check(inv.use_selected() and inv.state.count_class(10) == 1, "Reusable item use dispatch")
	inv.state.drop_uncommitted()
	check(rocket.available and rocket.visible and inv.equipped_id.is_empty(), "Rollback restores world pickup and clears equipped item")
	rocket.collect(inv)
	await create_timer(1.1).timeout
	inv.equipped.emit(inv.state.get_selected_object())
	inv.state.commit_at_checkpoint()
	inv.state.drop_uncommitted()
	check(not rocket.available and inv.state.count_class(10) == 1, "Committed pickup stays in inventory")
	inv.register_use_handler(10, func(_entry, _actor): return {"success": true, "consumed": true})
	check(inv.use_selected() and inv.state.count_class(10) == 0 and inv.equipped_id.is_empty(), "Successful consuming use removes the selected object and unequips")
	player.set_state(player.WolfState.RUN_START)
	check(not inv.open_wheel(), "Original running-state permission denies wheel")
	player.set_state(player.WolfState.SNEAK)
	player.handle_audio(0.32, true, true)
	player.handle_audio(0.32, true, true)
	check(player.sneak_step_count == 2 and is_equal_approx(player.sneak_audio_player.pitch_scale, 0.5), "SNDF_NO_RETRIGGER retains the active sample pitch")
	player.set_state(player.WolfState.IDLE)
	player.set_state(player.WolfState.SNEAK)
	for n in range(8):
		player.sneak_audio_player.stop()
		player.handle_audio(0.32, true, true)
		check(player.sneak_step_count == n + 1, "Controller advances sneak count %d" % n)
		check(is_equal_approx(player.sneak_audio_player.pitch_scale, 0.5 + n * 0.0625), "Audio adapter applies pitch %d" % n)
		check(is_equal_approx(player.sneak_audio_player.volume_db, -2.0 + linear_to_db(Steps.sneak_step(n)["volume"])), "Audio adapter applies fading volume %d" % n)
	player.handle_audio(10.0, true, true)
	check(player.sneak_step_count == 8, "Controller does not restart sneak sound sequence")
	player.set_state(player.WolfState.IDLE)
	check(not player.sneak_audio_player.playing, "Leaving sneak releases positional audio")
	player.set_state(player.WolfState.SNEAK)
	check(player.sneak_step_count == 0, "New sneak resets eight-step sequence")
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Inventory/sneak tests: failures=%d, equipped events=%d" % [failures, equipped_events])
	quit(1 if failures else 0)
