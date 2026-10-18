extends SceneTree

const Rules = preload("res://scripts/player/ralph_run_rules.gd")
var failures = 0
var impacts = 0
var recoveries = 0

func _init() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var geometry = BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	parent.add_child(body)
	body.position = position
	return body

func step(player, frames: int, tap_every: int = 0) -> void:
	for frame in range(frames):
		await physics_frame
		if tap_every > 0 and frame > 0 and frame % tap_every == 0:
			Input.action_release("run")
			Input.action_press("run")
		player._physics_process(1.0 / 60)
		player.animation_player.advance(1.0 / 60)
		if tap_every > 0:
			Input.action_release("run")

func run_tests() -> void:
	check(not Rules.run_tap_check(0.05, true, true)["active"], "Too-fast taps must clear the run flag")
	check(Rules.run_tap_check(0.3, false, true)["active"], "Valid tap must sustain running")
	check(not Rules.run_tap_check(0.76, true, false)["active"], "Held key must expire after 0.75s")
	check(Rules.is_run_crash(Vector3(0, 0, -7), Vector3.BACK, 1, 12), "Head-on wall at half speed must crash")
	check(not Rules.is_run_crash(Vector3(0, 0, -5), Vector3.BACK, 1, 12), "Slow collision must not crash")
	check(not Rules.is_run_crash(Vector3(7, 0, -1), Vector3.BACK, 1, 12), "Glancing collision must not crash")
	check(not Rules.is_run_crash(Vector3(0, 0, -12), Vector3.BACK, 0.3, 12), "Low obstacle must not trigger crash")
	check(not Rules.is_run_crash(Vector3(0, 0, -12), Vector3.BACK, 1, 12, true), "Exempt object must not crash")
	var poses = Rules.reaction_pose_transforms([-1, 0, 1], [Vector3.ZERO, Vector3.UP, Vector3.UP],
		[Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY],
		[Vector3.ZERO, Vector3.UP, Vector3.UP], [Vector3.ONE, Vector3(2, 3, 4), Vector3.ONE])
	check(poses[2].origin.is_equal_approx(Vector3(0, 4, 0)), "Parent scale must affect only rest offset")
	check(poses[2].basis.is_equal_approx(Basis.IDENTITY), "Parent scale must not compound on child geometry")

	var world = Node3D.new()
	root.add_child(world)
	box(world, Vector3(0, -0.5, 0), Vector3(1000, 1, 1000))
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	world.add_child(player)
	player.capture_mouse(false)
	player.set_physics_process(false)
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.run_impact.connect(func(_collider, _normal, _point, _speed): impacts += 1)
	player.run_recovery_started.connect(func(): recoveries += 1)
	await step(player, 10)
	check(player.is_on_floor(), "Fixture must establish floor contact")
	Input.action_press("move_forward")
	Input.action_press("run")
	await step(player, 1)
	check(player.current_state == player.WolfState.RUN_START, "Run edge must enter start")
	var start_stream = player.loop_audio_player.stream
	check(start_stream.resource_path.ends_with("run_start.wav"), "Start must use the single run channel")
	check(not player.audio_player.playing, "Start must not also play on one-shot channel")
	await step(player, 90)
	Input.action_release("run")
	Input.action_release("move_forward")
	await step(player, 21)
	check(player.current_state == player.WolfState.RUN_RECOVER, "Holding Shift must brake and recover")
	check(not player.loop_audio_player.playing, "Recovery must stop run channel")
	check(recoveries == 1, "Recovery must enter exactly once")
	await step(player, 301)
	check(player.current_state == player.WolfState.IDLE, "Recovery must return to idle after five seconds")

	player.position = Vector3(0, 0, 0)
	player.velocity = Vector3.ZERO
	await step(player, 3)
	Input.action_press("move_forward")
	Input.action_press("run")
	await step(player, 1)
	Input.action_release("run")
	await step(player, 60, 20)
	check(player.current_state == player.WolfState.RUN, "Correct taps must sustain run beyond start animation")
	# Deterministic audio completion: real audio clock is independent of test physics.
	player.loop_audio_player.stop()
	player._on_run_sound_finished()
	var loop = player.loop_audio_player.stream
	check(loop is AudioStreamWAV and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Run sample must actually loop")
	check(loop != start_stream, "Loop must start only after the start sample finishes")
	await step(player, 240, 20)
	check(player.current_state == player.WolfState.RUN, "Repeated valid taps must keep running")
	check(player.loop_audio_player.stream == loop, "Run must preserve one loop instance")
	check(player.loop_audio_player.playing, "Run audio must remain playing beyond the sample duration")

	# Real CharacterBody3D vs a wall, not only a synthetic normal test.
	Input.action_release("run")
	Input.action_release("move_forward")
	player.position = Vector3(0, 0, 0)
	player.velocity = Vector3.ZERO
	player.set_state(player.WolfState.IDLE)
	var wall = box(world, Vector3(0, 1.5, -7), Vector3(8, 3, 0.5))
	await step(player, 3)
	Input.action_press("move_forward")
	Input.action_press("run")
	await step(player, 1)
	Input.action_release("run")
	await step(player, 75, 20)
	print("Wall check: position=", player.position, " state=", player.current_state, " impacts=", impacts, " velocity=", player.velocity)
	check(impacts == 1, "Real head-on contact must produce one crash")
	check(player.current_state == player.WolfState.RUN_CRASH, "Crash must retain its one-shot animation")
	check(player.dizzy_effect.active and player.dizzy_effect.visual.idle_clip == "turn1", "Real wall impact starts original dizzy birds")
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.001, "Crash must stop horizontal movement")
	check(not player.loop_audio_player.playing, "Crash must stop run audio")
	Input.action_release("move_forward")
	await step(player, 100)
	check(player.current_state == player.WolfState.IDLE, "Crash must release after STRIKE1 finishes")
	check(not player.dizzy_effect.active and not player.dizzy_effect.visible,"Dizzy birds stop when crash animation ends")
	check(impacts == 1, "Persistent wall must not retrigger crash")
	for bone in range(player.skeleton.get_bone_count()):
		var idle_animation = player.animation_player.get_animation(player.animation_player.current_animation)
		var track = idle_animation.find_track(NodePath("Skeleton3D:joint_%02d" % bone),Animation.TYPE_SCALE_3D)
		var expected = idle_animation.scale_track_interpolate(track,player.animation_player.current_animation_position) if track >= 0 else Vector3.ONE
		check(player.skeleton.get_bone_pose_scale(bone).is_equal_approx(expected), "Crash scale must reset to the native idle pose")
	check(not player.reaction_pose_active, "Legacy global overrides must clear after crash")
	wall.queue_free()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await step(player, 3)
	Input.action_press("jump")
	await step(player, 1)
	Input.action_release("jump")
	check(player.current_state == player.WolfState.JUMP and player.velocity.y > 0, "Jump regression")
	await step(player, 8)
	Input.action_press("jump")
	await step(player, 1)
	Input.action_release("jump")
	check(not player.can_double_jump and player.jump_timer == 0.0, "Double-jump regression")
	await step(player, 130)
	check(player.is_on_floor(), "Jump must land again")
	world.queue_free()
	await process_frame
	# Allow the audio mixer to release its last active playback after queue_free.
	await create_timer(0.1).timeout
	print("Run mechanics: ", failures, " failures; real wall impacts=", impacts, "; recoveries=", recoveries)
	quit(1 if failures else 0)
