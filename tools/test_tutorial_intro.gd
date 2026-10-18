extends SceneTree

var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	player.capture_mouse(false)
	var director = level.get_node("TutorialIntro")
	level.get_node("CameraTraining").enabled = false
	director.set_process(false)
	check(director.data["cine_id"] == 1 and is_equal_approx(director.data["duration"],18.16),"Original CIN 1 duration")
	check(director.actors.size() >= 7 and director.data["tracks"].size() == 8 and director.sound_events.size() > 5,"All original intro actors and sound timeline recovered")
	check(not director.inside_trigger(player.position),"Intro does not start at map spawn")
	check(director.inside_trigger(Vector3(-55,0,42)),"Converted original ACTBOX includes start-line area")
	var original_count = director.get_child_count()
	var original_mesh_visibility = player.visible
	player.position = Vector3(-55,0,42)
	director._process(0.016)
	check(director.playing and player.cinematic_controls_locked and not player.is_physics_processing(),"Entering original start trigger captures player automatically")
	check(not player.visible and not player.can_use_inventory() and not director.start_sequence(),"No duplicate player or concurrent intro")
	check(director.camera.current and not level.get_node("DaffyDuck").visible,"Script camera and original Lucas replace gameplay placeholders")
	check(is_equal_approx(director.camera.fov,rad_to_deg(2*atan(256.0/533/(4.0/3)))),"Original fixed-point camera focal scale and 4:3 framing")
	director.sample(3.2)
	check(director.actors["2:52"].animation_player.current_animation == "squash2","Ralph uses original squashed animation")
	check(director.actors["4:1"].animation_player.current_animation == "startcin","Road Runner uses original authored intro animation")
	director.sample(10.0)
	check(director.actors["4:2"].visible and director.actors["4:2"].animation_player.assigned_animation == "stand2","Original Game Over curtain holds")
	director.sample(14.8)
	check(not director.actors["4:3"].visible and director.actors["2:56"].animation_player.current_animation == "over1","Anvil hides and Lucas performs original OVER1")
	director.sample(16)
	check(not director.actors["4:2"].visible,"Original curtain visibility key hides it")
	# Advance every real timeline interval, delivering audio once per cue.
	director.sample(0)
	director.elapsed = 0
	for i in range(1817):
		director._process(0.01)
	check(not director.playing and director.played and not player.cinematic_controls_locked,"Authored timeline ends and restores controls")
	check(player.visible == original_mesh_visibility and player.is_physics_processing() and player.camera.current,"Gameplay mesh/physics/camera restore")
	check(player.position.is_equal_approx(Vector3(-54.95,0.02,41.57)),"Original final Ralph position is retained")
	check(director.actors["2:56"].visible and director.actors["2:56"].idle_clip == "stand1" and not level.get_node("DaffyDuck").visible,"Animated Lucas remains after cinematic without rigid duplicate")
	for frame in range(12):
		await physics_frame
	check(player.is_on_floor() and player.position.y > -0.1,"Player resumes on the real floor at the authored final position")
	check(director.get_child_count() >= original_count and director.get_child_count() < original_count+10,"Sound playback uses a bounded reusable pool")
	check(not director.start_sequence(),"Trigger only plays once")
	check(director.start_sequence(true),"Explicit replay reuses same actors")
	director.finish_sequence(true)
	check(not director.playing and not player.cinematic_controls_locked,"Development skip restores controls as well")
	level.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Tutorial intro: ",failures," failures")
	quit(1 if failures else 0)
